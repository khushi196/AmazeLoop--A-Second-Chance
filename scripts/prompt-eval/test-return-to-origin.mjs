// Quick offline test for the ReturnToOrigin economic gate.
// Replicates the deployed decideRouteDynamic + buildEconomics inputs and
// runs them against the spec's worked examples.

const COST = {
  qcCost: 50, cleaningCost: 40, listingCost: 30, refurbHandlingCost: 60,
  sortingCost: 20, pickupBase: 80, pickupPerKm: 1.2, deliveryBase: 60,
  deliveryPerKm: 1.0, recycleTransportBase: 30, recycleTransportPerKm: 0.5,
  platformRiskRate: 0.05, refurbRiskRate: 0.08, recycleRecoveryRate: 0.05,
  originRecoveryRate: 0.90, originTransportBase: 100, originTransportPerKm: 1.5,
  originRestockingRate: 0.05, delayRiskRate: 0.05,
};
const REFURB = {
  "Like New":{m:null,n:"none",r:false}, "Good":{m:0.85,n:"cleaning",r:true},
  "Used":{m:0.75,n:"minor_repair",r:true}, "Damaged":{m:0.6,n:"major_repair",r:null},
};
const BLOCKER = /crack|shatter|broken|torn|hole|missing|detached|exposed wiring|major dent|unsafe/i;

function buildEconomics(r) {
  const condition = r.condition;
  const conditionScore = r.conditionScore;
  const confidence = r.confidence ?? 1;
  const normalizedPrice = r.normalizedPrice;
  const distanceKm = r.distanceKm;
  const visibleIssues = r.visibleIssues || [];
  const priceMultiplier = r.priceMultiplier;
  const profile = REFURB[condition];
  const postRefurbMultiplier = profile.m == null ? priceMultiplier : Math.max(profile.m, priceMultiplier);
  const hasBlocker = visibleIssues.some((i) => BLOCKER.test(i));
  const repairable = condition === "Damaged" ? !hasBlocker : profile.r === true;
  const refurbishmentNeeded = profile.n;
  const repairRate = refurbishmentNeeded === "major_repair" ? 0.18 : refurbishmentNeeded === "minor_repair" ? 0.08 : refurbishmentNeeded === "cleaning" ? 0.02 : 0;
  const repairCost = Math.round(normalizedPrice * repairRate);
  const asIs = normalizedPrice * priceMultiplier;
  const postRefurb = normalizedPrice * postRefurbMultiplier;

  return {
    condition, conditionScore, confidence, normalizedPrice, priceMultiplier, postRefurbMultiplier,
    repairable, refurbishmentNeeded, visibleIssues,
    pickupCost: Math.round(COST.pickupBase + COST.pickupPerKm * distanceKm),
    qcCost: COST.qcCost, cleaningCost: COST.cleaningCost, listingCost: COST.listingCost,
    deliveryCost: Math.round(COST.deliveryBase + COST.deliveryPerKm * distanceKm),
    platformRiskBuffer: Math.round(asIs * COST.platformRiskRate),
    repairCost, refurbHandlingCost: COST.refurbHandlingCost,
    refurbRiskBuffer: Math.round(postRefurb * COST.refurbRiskRate),
    sortingCost: COST.sortingCost,
    recyclingTransportCost: Math.round(COST.recycleTransportBase + COST.recycleTransportPerKm * distanceKm),
    recycleRecoveryValue: Math.round(normalizedPrice * COST.recycleRecoveryRate),
    isWarehouseFlow: r.userRole === "warehouse",
    sourceType: r.reason === "Returned Amazon order" ? "customer_return" : "consumer_trade_in",
    originWarehouseAvailable: !!r.nearestWarehouseId,
    sellerAcceptsReturn: r.sellerAcceptsReturn !== false,
    originRecoveryValue: (() => {
      const asIs = normalizedPrice * priceMultiplier;
      const isHQ = condition === "Like New" || condition === "Good";
      return Math.round(asIs * COST.originRecoveryRate * (isHQ ? 1 : 0.7));
    })(),
    originTransportCost: Math.round(COST.originTransportBase + COST.originTransportPerKm * distanceKm),
    localHandlingCost: COST.qcCost + COST.sortingCost,
    originRestockingFee: Math.round((() => { const a = normalizedPrice * priceMultiplier; const isHQ = condition==="Like New"||condition==="Good"; return a*COST.originRecoveryRate*(isHQ?1:0.7); })() * COST.originRestockingRate),
    delayRiskBuffer: Math.round((() => { const a = normalizedPrice * priceMultiplier; const isHQ = condition==="Like New"||condition==="Good"; return a*COST.originRecoveryRate*(isHQ?1:0.7); })() * COST.delayRiskRate),
  };
}

function decide(x) {
  const asIs = x.normalizedPrice * x.priceMultiplier;
  const postRefurb = x.normalizedPrice * x.postRefurbMultiplier;
  const directCost = x.pickupCost + x.qcCost + x.cleaningCost + x.listingCost + x.deliveryCost + x.platformRiskBuffer;
  const refurbCost = x.pickupCost + x.qcCost + x.repairCost + x.refurbHandlingCost + x.listingCost + x.deliveryCost + x.refurbRiskBuffer;
  const recycleCost = x.pickupCost + x.sortingCost + x.recyclingTransportCost;
  const directNet = asIs - directCost;
  const refurbNet = postRefurb - refurbCost;
  const recycleNet = x.recycleRecoveryValue - recycleCost;
  const blockers = (x.visibleIssues || []).some((i) => BLOCKER.test(i));
  const originNet = x.originRecoveryValue - x.originTransportCost - x.localHandlingCost - x.originRestockingFee - x.delayRiskBuffer;
  const eligible =
    x.isWarehouseFlow && x.sourceType === "customer_return" && x.originWarehouseAvailable &&
    x.sellerAcceptsReturn && (x.condition === "Like New" || x.condition === "Good") &&
    x.conditionScore >= 0.7 && x.confidence >= 0.65 && x.refurbishmentNeeded !== "major_repair" &&
    !blockers && originNet >= 300 && originNet >= directNet * 1.10 &&
    originNet >= refurbNet * 1.10 && originNet >= recycleNet;
  return { decision: eligible ? "ReturnToOrigin" : "(other)", originNet, directNet, refurbNet, recycleNet };
}

const cases = [
  // Good condition, close origin: local cleaning is cheap, origin not worth it
  { name: "Good, close origin (local wins)", r: { condition: "Good", conditionScore: 0.85, confidence: 0.9, normalizedPrice: 9000, priceMultiplier: 0.7, distanceKm: 50, visibleIssues: [], userRole: "warehouse", reason: "Returned Amazon order", nearestWarehouseId: "BLR" } },
  // Like-New: local resale at 90% is lucrative, returning not worth extra friction
  { name: "Like-New, close origin (local wins)", r: { condition: "Like New", conditionScore: 0.95, confidence: 0.95, normalizedPrice: 9000, priceMultiplier: 0.95, distanceKm: 50, visibleIssues: [], userRole: "warehouse", reason: "Returned Amazon order", nearestWarehouseId: "BLR" } },
  // Like-New, moderate origin: origin recovery at 90% × asIs beats a distant local market
  { name: "Like-New, moderate distance, origin wins", r: { condition: "Like New", conditionScore: 0.95, confidence: 0.95, normalizedPrice: 9000, priceMultiplier: 0.95, distanceKm: 450, visibleIssues: [], userRole: "warehouse", reason: "Returned Amazon order", nearestWarehouseId: "MUM" } },
  // CRITICAL: Underpriced normalizedPrice (LLM guessed low). asIsResaleValue reflects actual good value.
  // Before fix: originRecovery = lowNormalizedPrice × 0.90 → loses. After fix: asIsResaleValue × 0.90 → wins.
  { name: "Like-New, underpriced normalizedPrice, origin should win", r: { condition: "Like New", conditionScore: 0.95, confidence: 0.9, normalizedPrice: 3000, priceMultiplier: 0.9, distanceKm: 400, visibleIssues: [], userRole: "warehouse", reason: "Returned Amazon order", nearestWarehouseId: "BLR", sellerAcceptsReturn: true } },
  // Customer trade-in: never eligible
  { name: "Customer trade-in (not eligible)", r: { condition: "Good", conditionScore: 0.85, confidence: 0.9, normalizedPrice: 9000, priceMultiplier: 0.7, distanceKm: 50, visibleIssues: [], userRole: "customer", reason: "Unused at home", nearestWarehouseId: "BLR" } },
  // Damaged: blocked
  { name: "Damaged (blocked)", r: { condition: "Damaged", conditionScore: 0.2, confidence: 0.9, normalizedPrice: 9000, priceMultiplier: 0.2, distanceKm: 50, visibleIssues: ["cracked screen"], userRole: "warehouse", reason: "Returned Amazon order", nearestWarehouseId: "BLR" } },
];

for (const c of cases) {
  const econ = buildEconomics(c.r);
  const out = decide(econ);
  console.log(`\n${c.name}`);
  console.log(`  originNet=${out.originNet} directNet=${out.directNet} refurbNet=${out.refurbNet} recycleNet=${out.recycleNet}`);
  console.log(`  → ${out.decision}`);
}
