import json, subprocess

BASE = "https://bu719hnik3.execute-api.ap-south-1.amazonaws.com"
PHOTO = "https://amazeloop-photos-191918535218.s3.ap-south-1.amazonaws.com/uploads/19fc017c-8885-42b6-b79c-3cd84beaf1c1-bad_3.jpg.jpeg"

def call(path, body):
    p = subprocess.run(["curl","-s","-X","POST",f"{BASE}{path}","-H","Content-Type: application/json","-d",json.dumps(body)],
                       capture_output=True, text=True)
    return json.loads(p.stdout)

def make_eval(order_or_price, reason, pincode, category="Electronics & Computers"):
    g = call("/grade", {"orderOrPrice":order_or_price,"category":category,"reason":reason,
                        "productName":"Test Item","currentPincode":pincode,"photoUrls":[PHOTO]})
    return g["evaluationInput"]["evaluationId"]

def patch_condition(eid, condition, conditionScore, resale, normalized):
    # Directly set condition fields via a tiny aws cli update to simulate AI output
    expr = "SET #c=:c, conditionScore=:cs, estimatedResaleValue=:r, normalizedPrice=:n"
    vals = json.dumps({":c":{"S":condition},":cs":{"N":str(conditionScore)},
                       ":r":{"N":str(resale)},":n":{"N":str(normalized)}})
    names = json.dumps({"#c":"condition"})
    subprocess.run(["/usr/local/bin/aws","dynamodb","update-item","--table-name","Evaluations",
                    "--key",json.dumps({"evaluationId":{"S":eid}}),
                    "--update-expression",expr,"--expression-attribute-values",vals,
                    "--expression-attribute-names",names,"--region","ap-south-1"],
                   capture_output=True, text=True)

def route(eid):
    r = call("/route", {"evaluationId":eid})["routeInput"]
    return r

scenarios = [
    # (queue reason, condition, cScore, resale, normalized, pincode, label)
    ("Returned Amazon order", "Like New", 0.95, 60000, 69900, "560001", "Returned + Like New + high value"),
    ("Returned Amazon order", "Good",     0.85, 20000, 69900, "560001", "Returned + Good + low value (<50%)"),
    ("Returned Amazon order", "Damaged",  0.15, 7000,  69900, "560001", "Returned + Damaged"),
    ("Unused at home",        "Like New", 0.95, 60000, 69900, "400050", "Unused + Like New"),
    ("Unused at home",        "Used",     0.55, 30000, 69900, "411038", "Unused + Used + near"),
    ("Unused at home",        "Used",     0.55, 5000,  69900, "560001", "Unused + Used + very low value"),
    ("Unused at home",        "Damaged",  0.15, 7000,  69900, "700019", "Unused + Damaged + far"),
]

for reason, cond, cs, resale, norm, pin, label in scenarios:
    order = "ORD-101"
    eid = make_eval(order, reason, pin)
    patch_condition(eid, cond, cs, resale, norm)
    r = route(eid)
    print(f"- {label}")
    print(f"    route       : {r['recommendedRoute']}")
    print(f"    disposition : {r['finalDisposition']}  (warehouse {r['nearestWarehouseId']}, {r['distanceKm']}km)\n")
