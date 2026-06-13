import json, subprocess

BASE = "https://bu719hnik3.execute-api.ap-south-1.amazonaws.com"
DAMAGED_PHOTOS = [
    "https://amazeloop-photos-191918535218.s3.ap-south-1.amazonaws.com/uploads/19fc017c-8885-42b6-b79c-3cd84beaf1c1-bad_3.jpg.jpeg",
    "https://amazeloop-photos-191918535218.s3.ap-south-1.amazonaws.com/uploads/fcefeddb-7f86-4c57-a92a-39791f637c0d-WhatsApp_Image_2026-06-13_at_6.17.35_AM.jpeg",
]

# 10 diverse items: mix of order-ID and price paths, categories, prices, reasons
ITEMS = [
    {"productName":"Apple iPhone 14",          "category":"Electronics & Computers",            "reason":"Returned Amazon order", "orderOrPrice":"ORD-101"},
    {"productName":"Nike Air Max 270",         "category":"Clothing, Shoes & Jewelry",          "reason":"Unused at home",        "orderOrPrice":"ORD-108"},
    {"productName":"Sony PlayStation 5",       "category":"Books, Music, Movies & Video Games", "reason":"Returned Amazon order", "orderOrPrice":"ORD-145"},
    {"productName":"LG 1.5 Ton Split AC",      "category":"Home & Kitchen",                     "reason":"Unused at home",        "orderOrPrice":"ORD-140"},
    {"productName":"Fisher-Price Baby Monitor","category":"Toys, Kids & Baby",                  "reason":"Returned Amazon order", "orderOrPrice":"ORD-114"},
    {"productName":"Tanishq Gold Pendant",     "category":"Clothing, Shoes & Jewelry",          "reason":"Returned Amazon order", "orderOrPrice":"ORD-135"},
    {"productName":"Generic Smartphone",       "category":"Electronics & Computers",            "reason":"Unused at home",        "orderOrPrice":"25000"},
    {"productName":"Cotton T-Shirt",           "category":"Clothing, Shoes & Jewelry",          "reason":"Returned Amazon order", "orderOrPrice":"1500"},
    {"productName":"Kids Board Game",          "category":"Toys, Kids & Baby",                  "reason":"Unused at home",        "orderOrPrice":"3000"},
    {"productName":"Premium Laptop",           "category":"Electronics & Computers",            "reason":"Returned Amazon order", "orderOrPrice":"60000"},
]

def call(path, body):
    p = subprocess.run(
        ["curl","-s","-X","POST",f"{BASE}{path}","-H","Content-Type: application/json","-d",json.dumps(body)],
        capture_output=True, text=True)
    try:
        return json.loads(p.stdout)
    except Exception:
        return {"_raw": p.stdout}

rows = []
for i, it in enumerate(ITEMS, 1):
    body = dict(it)
    body["currentPincode"] = "560001"
    body["photoUrls"] = DAMAGED_PHOTOS
    body["userId"] = f"tester-{i}"
    body["userRole"] = "warehouse"

    g = call("/grade", body)
    ev = g.get("evaluationInput", {})
    eid = ev.get("evaluationId")
    norm = ev.get("normalizedPrice")
    queue = ev.get("sortingQueue")
    prio = ev.get("priority")

    ai = call("/ai-grade", {"evaluationId": eid}) if eid else {"error":"no evaluationId"}
    cond = ai.get("condition")
    cscore = ai.get("conditionScore")
    pmult = ai.get("priceMultiplier")
    resale = ai.get("estimatedResaleValue")

    rows.append({
        "#": i, "item": it["productName"], "input": it["orderOrPrice"],
        "reason": "Returned" if "Returned" in it["reason"] else "Unused",
        "normPrice": norm, "condition": cond, "cScore": cscore,
        "pMult": pmult, "resale": resale, "queue": queue, "prio": prio,
    })
    print(f"[{i}/10] {it['productName']:26} input={str(it['orderOrPrice']):8} norm={norm} cond={cond} mult={pmult} resale={resale}")

print("\n=== JSON SUMMARY ===")
print(json.dumps(rows, indent=2))
