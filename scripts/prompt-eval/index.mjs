/**
 * Offline prompt-evaluation harness for AmazeLoop's Nova Pro prompts.
 *
 * NOTE: Bedrock foundation models are NOT trained/fine-tuned here. This script
 * only EXERCISES the prompts across many hand-authored scenarios to validate
 * that outputs are sane and consistent. No ProductsCatalog/seed data is used.
 *
 *  - PRICE   : real deployed prompt, text-only, no catalog samples.
 *  - GRADE   : TEXT PROXY of the grading prompt (real grading needs photos).
 *  - ROUTE   : deterministic decision (replicated) + real explanation prompt.
 */

import { BedrockRuntimeClient, ConverseCommand } from "@aws-sdk/client-bedrock-runtime";
import { SCENARIOS } from "./scenarios.mjs";
import { writeFileSync } from "fs";

const REGION = process.env.AWS_REGION || "ap-south-1";
const MODEL_ID = process.env.BEDROCK_MODEL_ID || "apac.amazon.nova-pro-v1:0";
const CONCURRENCY = Number(process.env.CONCURRENCY || 2);

const bedrock = new BedrockRuntimeClient({ region: REGION });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function converse(prompt, { maxTokens = 300, temperature = 0, topP = 0.1 } = {}) {
  const MAX_RETRIES = 6;
  let attempt = 0;
  for (;;) {
    try {
      const resp = await bedrock.send(new ConverseCommand({
        modelId: MODEL_ID,
        messages: [{ role: "user", content: [{ text: prompt }] }],
        inferenceConfig: { maxTokens, temperature, topP },
      }));
      return (resp?.output?.message?.content?.[0]?.text || "").trim();
    } catch (e) {
      const throttled = e.name === "ThrottlingException" ||
        /too many requests|throttl/i.test(e.message || "");
      if (!throttled || attempt >= MAX_RETRIES) throw e;
      // Exponential backoff with jitter: 1s, 2s, 4s, 8s, 16s, 32s.
      const wait = 1000 * 2 ** attempt + Math.floor(Math.random() * 500);
      attempt++;
      await sleep(wait);
    }
  }
}

function extractJson(raw) {
  const m = raw.match(/\{[\s\S]*\}/);
  try { return JSON.parse(m ? m[0] : raw); } catch { return null; }
}

// Simple concurrency-limited map.
async function pool(items, limit, fn) {
  const out = new Array(items.length);
  let i = 0;
  const workers = Array.from({ length: limit }, async () => {
    while (i < items.length) {
      const idx = i++;
      out[idx] = await fn(items[idx], idx);
    }
  });
  await Promise.all(workers);
  return out;
}

// ---------------------------------------------------------------------------
// Prompt builders (mirror the deployed prompts)
// ---------------------------------------------------------------------------

function pricePrompt(s) {
  return `You are a STRICT product pricing expert for an Indian recommerce resale platform. ` +
    `Your task is to estimate the fair LIKE-NEW reference price in INR for the exact product model or closest identifiable model. ` +
    `Do NOT grade condition. Do NOT decide routing.\n\n` +
    `No photo is available, so rely only on text and catalog references.\n` +
    `Product name entered by user: "${s.name}".\n` +
    `Category: "${s.category}".\n` +
    `User entered price: Rs.${s.userPrice}.\n\n` +
    `No catalog reference products available.\n\n` +
    `STRICT MODEL-MATCHING RULES:\n` +
    `1. Price the exact or closest identifiable model, not the broad product type.\n` +
    `2. A broad category match is weak evidence.\n` +
    `3. Prefer exact brand+model, then brand+tier, then visible tier, then category.\n` +
    `4. If the exact model is unclear, do NOT invent a premium model; estimate conservatively. ` +
    `However, if the user text clearly contains a well-known brand + model/series (e.g. "Dell XPS 13", "iPhone 13", "Sony WH-1000XM4", "Nike Air Force 1", "Adidas Ultraboost"), ` +
    `treat it as at least a "strong" match even without a photo, unless category/catalog evidence contradicts it. ` +
    `Do not downgrade a clear brand+model text match to "category_only" just because no photo is available.\n` +
    `5. User-entered price is weak evidence; keep only if it matches the identified model.\n` +
    `7. Premium pricing only when brand/model evidence supports it.\n\n` +
    `modelMatchLevel definitions:\n` +
    `- "exact": brand + exact model/series + variant/specs clearly known.\n` +
    `- "strong": brand + model/series clearly known, variant/specs/year/storage/size uncertain.\n` +
    `- "partial": brand or product line known, exact model uncertain.\n` +
    `- "category_only": only broad product type known (shoe, laptop, phone, bag).\n` +
    `- "unclear": identity too ambiguous to price reliably.\n\n` +
    `HARD PRICING GUARD: If modelMatchLevel is "exact" or "strong", price by the realistic market tier for that model; do NOT force a budget/category-average just because input is text-only.\n\n` +
    `Indian pricing guidance: budget Rs.300-3000; mid-range Rs.3000-10000; premium Rs.10000-25000 with strong evidence; electronics by exact model/specs.\n\n` +
    `Return ONLY valid JSON. No markdown.\n` +
    `{"estimatedPrice": <int INR>,"identifiedProduct": "<brand+model or unclear>","modelMatchLevel": "<exact|strong|partial|category_only|unclear>","confidence": <0-1>,"reasoning": "<one sentence>"}`;
}

function gradeProxyPrompt(s) {
  return `You are a STRICT visible physical-condition grader for a recommerce resale platform. ` +
    `(OFFLINE TEXT PROXY: instead of photos you are given a written description of the visible condition.)\n\n` +
    `Item: "${s.name}" (category: ${s.category}).\n` +
    `Visible condition described as: "${s.condition}".\n\n` +
    `Be conservative: when in doubt, grade DOWN. Grade only from the described visible evidence.\n` +
    `Definitions: "Like New" almost no wear; "Good" light wear only; "Used" clearly used, intact; ` +
    `"Damaged" any serious defect (cracks, breaks, tears, holes, missing/detached parts, structural damage).\n` +
    `HARD RULES: cracks/breaks/tears/holes/detached parts => "Damaged"; multiple moderate defects => not "Good"; ` +
    `brand value must not improve condition.\n` +
    `Bands: Like New 0.80-1.00, Good 0.60-0.80, Used 0.40-0.60, Damaged 0.10-0.30.\n\n` +
    `Return ONLY valid JSON. No markdown.\n` +
    `{"condition": "<Like New|Good|Used|Damaged>","conditionScore": <0-1>,"priceMultiplier": <fraction>,"confidence": <0-1>,"visibleIssues": ["..."],"reasoning": "<one sentence>"}`;
}

function routePrompt(r) {
  const money = (v) => (v == null ? "unknown" : `Rs.${Math.round(Number(v))}`);
  return `You are explaining a recommerce routing decision to a warehouse operator.\n` +
    `The backend has already made the final routing decision using deterministic rules. ` +
    `You must NOT change, question, or override the chosen disposition. Only explain it clearly.\n\n` +
    `Product: ${r.productName} (category: ${r.category}).\n` +
    `Condition: ${r.condition} (score ${r.conditionScore}).\n` +
    `Fair like-new price: ${money(r.normalizedPrice)}.\n` +
    `Estimated resale value: ${money(r.estimatedResaleValue)}.\n` +
    `Distance to nearest warehouse: ${r.distanceKm} km.\n` +
    `Chosen disposition: ${r.finalDisposition}.\n\n` +
    `Write ONE short sentence explaining why ${r.finalDisposition} is appropriate, considering condition, resale value, and distance.\n` +
    `Rules: do not mention a different route; no markdown; no preamble; respond with only one sentence.`;
}

// ---------------------------------------------------------------------------
// Deterministic routing (replicated from the route Lambda)
// ---------------------------------------------------------------------------
const WAREHOUSES = [
  { id: "BLR", lat: 12.9716, lng: 77.5946 }, { id: "MUM", lat: 19.0760, lng: 72.8777 },
  { id: "DEL", lat: 28.6139, lng: 77.2090 }, { id: "HYD", lat: 17.3850, lng: 78.4867 },
  { id: "MAA", lat: 13.0827, lng: 80.2707 }, { id: "PNQ", lat: 18.5204, lng: 73.8567 },
];
const PIN3 = { "560":[12.97,77.59],"400":[19.07,72.87],"110":[28.61,77.20],"500":[17.38,78.48],
  "600":[13.08,80.27],"411":[18.52,73.85],"700":[22.57,88.36],"380":[23.02,72.57],"302":[26.91,75.78],"226":[26.84,80.94] };
function haversine(a,b,c,d){const R=6371,r=x=>x*Math.PI/180,dLat=r(c-a),dLng=r(d-b);
  const h=Math.sin(dLat/2)**2+Math.cos(r(a))*Math.cos(r(c))*Math.sin(dLng/2)**2;return R*2*Math.atan2(Math.sqrt(h),Math.sqrt(1-h));}
function nearestKm(pin){const c=PIN3[String(pin).slice(0,3)]||[22.35,78.66];let best=Infinity;
  for(const w of WAREHOUSES){const k=haversine(c[0],c[1],w.lat,w.lng);if(k<best)best=k;}return Math.round(best);}

function scoreRoute({ netValue, conditionScore, confidence, routeFit, costBurden }) {
  const n = Math.max(0, Math.min(netValue / 5000, 1));
  const cp = Math.max(0, Math.min(costBurden, 1));
  return n * 0.45 + conditionScore * 0.25 + confidence * 0.15 + routeFit * 0.15 - cp * 0.20;
}

const REFURB = { "Like New":{m:1.0,n:"none",r:false}, "Good":{m:0.85,n:"cleaning",r:true},
  "Used":{m:0.75,n:"minor_repair",r:true}, "Damaged":{m:0.6,n:"major_repair",r:null} };
const BLOCKER = /crack|shatter|broken|torn|hole|missing|detached|exposed wiring|major dent|unsafe/i;

function decideRoute(r) {
  const { condition, conditionScore, confidence = 1, normalizedPrice, priceMultiplier,
    distanceKm, visibleIssues = [] } = r;
  const prof = REFURB[condition] || REFURB["Used"];
  const postRefurbMultiplier = Math.max(prof.m, priceMultiplier);
  const hasBlocker = visibleIssues.some((i) => BLOCKER.test(String(i)));
  const repairable = condition === "Damaged" ? !hasBlocker : prof.r === true;
  const needed = prof.n;
  const repairRate = needed === "major_repair" ? 0.18 : needed === "minor_repair" ? 0.08 : needed === "cleaning" ? 0.02 : 0;
  const repairCost = Math.round(normalizedPrice * repairRate);
  const pickupCost = Math.round(80 + 1.2 * distanceKm);
  const deliveryCost = Math.round(60 + 1.0 * distanceKm);
  const asIs = normalizedPrice * priceMultiplier;
  const postRefurb = normalizedPrice * postRefurbMultiplier;

  return decideRouteDynamic({
    condition, conditionScore, confidence, normalizedPrice, priceMultiplier, postRefurbMultiplier,
    repairable, refurbishmentNeeded: needed, visibleIssues,
    pickupCost, qcCost: 50, cleaningCost: 40, listingCost: 30, deliveryCost,
    platformRiskBuffer: Math.round(asIs * 0.05), repairCost, refurbHandlingCost: 60,
    refurbRiskBuffer: Math.round(postRefurb * 0.08), sortingCost: 20,
    recyclingTransportCost: Math.round(30 + 0.5 * distanceKm),
    recycleRecoveryValue: Math.round(normalizedPrice * 0.05),
  });
}

function decideRouteDynamic(x) {
  const asIs = x.normalizedPrice * x.priceMultiplier;
  const postRefurb = x.normalizedPrice * x.postRefurbMultiplier;
  const directCost = x.pickupCost + x.qcCost + x.cleaningCost + x.listingCost + x.deliveryCost + x.platformRiskBuffer;
  const refurbCost = x.pickupCost + x.qcCost + x.repairCost + x.refurbHandlingCost + x.listingCost + x.deliveryCost + x.refurbRiskBuffer;
  const recycleCost = x.pickupCost + x.sortingCost + x.recyclingTransportCost;
  const directNet = asIs - directCost, refurbNet = postRefurb - refurbCost, recycleNet = x.recycleRecoveryValue - recycleCost;
  const uplift = postRefurb - asIs;
  const minP = 300;
  const severe = x.condition === "Damaged" && x.repairable !== true;
  const blockers = (x.visibleIssues || []).some((i) => BLOCKER.test(String(i)));
  const dEl = !severe && !blockers && x.conditionScore >= 0.45 && directNet >= minP;
  const rEl = x.repairable === true && x.refurbishmentNeeded !== "none" && x.repairCost <= postRefurb * 0.25 && uplift >= refurbCost * 1.2 && refurbNet >= minP;
  const dS = dEl ? scoreRoute({ netValue: directNet, conditionScore: x.conditionScore, confidence: x.confidence, routeFit: (x.condition==="Like New"||x.condition==="Good")?1:0.75, costBurden: directCost/Math.max(asIs,1) }) : -Infinity;
  const rS = rEl ? scoreRoute({ netValue: refurbNet, conditionScore: Math.min(x.conditionScore+0.2,1), confidence: x.confidence, routeFit: x.refurbishmentNeeded==="minor_repair"?0.9:0.65, costBurden: refurbCost/Math.max(postRefurb,1) }) : -Infinity;
  const cS = scoreRoute({ netValue: recycleNet, conditionScore: x.condition==="Damaged"?0.8:0.35, confidence: x.confidence, routeFit: severe?1:0.4, costBurden: recycleCost/Math.max(x.recycleRecoveryValue,1) });
  if (rEl && rS > dS && refurbNet >= directNet * 1.15) return "Refurbish";
  if (dS >= rS && dS >= cS) return "Resell";
  return "Recycle";
}

// ---------------------------------------------------------------------------
// Per-scenario evaluation
// ---------------------------------------------------------------------------
const BANDS = { "Like New":[0.8,1.0], "Good":[0.6,0.8], "Used":[0.4,0.6], "Damaged":[0.1,0.3] };
function clampMult(cond, m) {
  if (cond === "Damaged") return 0; // damaged => recycle => no resale value
  const [lo,hi] = BANDS[cond] || [0.4,0.6];
  let v = Number(m); if (Number.isNaN(v)) v = (lo+hi)/2;
  return Math.max(lo, Math.min(hi, v));
}

async function evalScenario(s) {
  const row = { name: s.name, category: s.category, userPrice: s.userPrice };

  // 1. PRICE
  const priceRaw = await converse(pricePrompt(s), { maxTokens: 250 });
  const p = extractJson(priceRaw) || {};
  const normalizedPrice = Number(p.estimatedPrice) > 0 ? Number(p.estimatedPrice) : s.userPrice;
  row.price = { estimatedPrice: p.estimatedPrice ?? null, match: p.modelMatchLevel ?? null,
    confidence: p.confidence ?? null, identified: p.identifiedProduct ?? null };

  // 2. GRADE (text proxy)
  const gradeRaw = await converse(gradeProxyPrompt(s), { maxTokens: 300 });
  const g = extractJson(gradeRaw) || {};
  const condition = ["Like New","Good","Used","Damaged"].includes(g.condition) ? g.condition : "Used";
  const conditionScore = Number(g.conditionScore);
  const mult = clampMult(condition, g.priceMultiplier);
  const estimatedResaleValue = Math.round((normalizedPrice * mult) / 10) * 10;
  row.grade = { condition, conditionScore: Number.isNaN(conditionScore) ? null : conditionScore,
    confidence: g.confidence ?? null, visibleIssues: g.visibleIssues || [], estimatedResaleValue };

  // 3. ROUTE (economics-based decision + explanation prompt)
  const sortingQueue = s.reason === "Returned Amazon order" ? "LOGISTICS_OPTIMIZATION_QUEUE" : "CONSUMER_TRADE_IN_QUEUE";
  const distanceKm = nearestKm(s.pincode);
  const gradeConfidence = typeof g.confidence === "number" ? g.confidence : 1;
  const finalDisposition = decideRoute({
    condition, conditionScore, confidence: gradeConfidence, normalizedPrice,
    priceMultiplier: mult, distanceKm, visibleIssues: row.grade.visibleIssues,
  });
  const reason = await converse(routePrompt({ productName: s.name, category: s.category, condition,
    conditionScore, normalizedPrice, estimatedResaleValue, distanceKm, finalDisposition }), { maxTokens: 120, temperature: 0.2, topP: 0.9 });
  row.route = { distanceKm, finalDisposition, reason };

  return row;
}

// ---------------------------------------------------------------------------
// Run + report
// ---------------------------------------------------------------------------
function inr(n) { return n == null ? "—" : "Rs." + Number(n).toLocaleString("en-IN"); }

(async () => {
  console.log(`Model: ${MODEL_ID} | Scenarios: ${SCENARIOS.length} | Concurrency: ${CONCURRENCY}\n`);
  const t0 = Date.now();
  const rows = await pool(SCENARIOS, CONCURRENCY, async (s, i) => {
    try {
      const r = await evalScenario(s);
      process.stdout.write(`. (${i + 1}/${SCENARIOS.length})\r`);
      return r;
    } catch (e) {
      console.error(`\nScenario "${s.name}" failed: ${e.message}`);
      return { name: s.name, error: e.message };
    }
  });
  const secs = ((Date.now() - t0) / 1000).toFixed(0);

  // Detailed table
  console.log(`\n\n=== RESULTS (${secs}s) ===\n`);
  for (const r of rows) {
    if (r.error) { console.log(`✗ ${r.name}: ${r.error}\n`); continue; }
    console.log(`• ${r.name}  [${r.category}]  user:${inr(r.userPrice)}`);
    console.log(`    PRICE  ${inr(r.price.estimatedPrice)}  match=${r.price.match} conf=${r.price.confidence}  (${r.price.identified})`);
    console.log(`    GRADE  ${r.grade.condition} (score ${r.grade.conditionScore}, conf ${r.grade.confidence})  resale=${inr(r.grade.estimatedResaleValue)}`);
    console.log(`           issues: ${(r.grade.visibleIssues || []).join("; ") || "none"}`);
    console.log(`    ROUTE  ${r.route.finalDisposition}  (${r.route.distanceKm} km)`);
    console.log(`           ${r.route.reason}`);
    console.log("");
  }

  // Aggregate sanity checks
  const ok = rows.filter((r) => !r.error);
  const dispCount = {};
  const condCount = {};
  let priceParsed = 0, damagedToRecycle = 0, damagedTotal = 0;
  for (const r of ok) {
    dispCount[r.route.finalDisposition] = (dispCount[r.route.finalDisposition] || 0) + 1;
    condCount[r.grade.condition] = (condCount[r.grade.condition] || 0) + 1;
    if (r.price.estimatedPrice != null) priceParsed++;
    if (r.grade.condition === "Damaged") { damagedTotal++; if (r.route.finalDisposition === "Recycle") damagedToRecycle++; }
  }
  console.log("=== SUMMARY ===");
  console.log(`Scenarios OK: ${ok.length}/${rows.length}`);
  console.log(`Price JSON parsed: ${priceParsed}/${ok.length}`);
  console.log(`Condition distribution: ${JSON.stringify(condCount)}`);
  console.log(`Disposition distribution: ${JSON.stringify(dispCount)}`);
  console.log(`Damaged -> Recycle invariant: ${damagedToRecycle}/${damagedTotal} (should be all)`);

  writeFileSync(new URL("./results.json", import.meta.url), JSON.stringify(rows, null, 2));
  console.log(`\nFull results written to scripts/prompt-eval/results.json`);
})();
