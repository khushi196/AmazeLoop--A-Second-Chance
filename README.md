AmazeLoop: Technical Architecture Document
Platform Classification: Consumer-to-Business (C2B) Trade-In & Recommerce
Version: 1.0 | Environment: AWS ap-south-1 (Mumbai)

1. Project Overview
AmazeLoop is a dual-stream recommerce platform designed to give used products a structured second life. It operates across two distinct input channels: Amazon returns (logistics-optimization stream) and consumer trade-ins of unused household goods. Upon item submission, the platform performs automated condition grading using computer vision, normalizes the item's fair market value against a catalog of reference products, and routes the item to the most economically optimal disposition — Resell, Refurbish, or Recycle.

The system is built as a serverless, event-driven architecture on AWS, with a Flutter-based web/mobile frontend and a pipeline of independent Lambda microservices communicating through Amazon DynamoDB as the shared state store.

2. Core Architecture: Four-Tier Flow
┌─────────────────────────────────────────────────────────────────────┐
│  TIER 1 — FRONTEND                                                   │
│  Flutter Web Dashboard                                               │
│  ┌─────────────┐  ┌──────────────┐  ┌───────────┐  ┌────────────┐  │
│  │  Login /    │  │  Grade New   │  │  Routing  │  │  History   │  │
│  │  Cognito    │→ │  Item Form   │→ │  Decision │→ │  (by User) │  │
│  │  Auth       │  │  + Upload    │  │  + Health │  │  Identity  │  │
│  └─────────────┘  └──────────────┘  │  Card     │  │  Bound     │  │
│                                      └───────────┘  └────────────┘  │
└──────────────────────────────┬──────────────────────────────────────┘
                               │ HTTPS / API Gateway
┌──────────────────────────────▼──────────────────────────────────────┐
│  TIER 2 — INGESTION LAYER                                            │
│                                                                      │
│  POST /upload-url                                                    │
│  AmazeLoopUploadUrlFunction (Lambda)                                 │
│  ┌──────────────────────────────────────────────────────────────┐   │
│  │  1. Generates presigned S3 PUT URL (5-min TTL)               │   │
│  │  2. Flutter client uploads photo bytes directly to S3        │   │
│  │  3. Returns permanent fileUrl stored on Evaluation record    │   │
│  └─────────────────────────────────┬────────────────────────────┘   │
│                                     │                                │
│                          S3 Bucket: amazeloop-photos                 │
└─────────────────────────────────────┬───────────────────────────────┘
                                       │
┌──────────────────────────────────────▼──────────────────────────────┐
│  TIER 3 — EVALUATION ENGINE (Smart Gateway)                          │
│                                                                      │
│  POST /grade → AmazeLoopGradeFunction                                │
│                                                                      │
│  ┌─────────────────────────┐    ┌──────────────────────────────┐    │
│  │  STREAM A               │    │  STREAM B                    │    │
│  │  Order ID Path          │    │  Price Normalization Path    │    │
│  │  (Amazon Returns)       │    │  (Consumer Trade-ins)        │    │
│  │                         │    │                              │    │
│  │  Input: ORD-xxx         │    │  Input: numeric price        │    │
│  │  → GSI Query on         │    │  → DynamoDB Scan with        │    │
│  │    ProductsCatalog      │    │    category + price-tier     │    │
│  │  → Pulls catalog price, │    │    filter (50%–200% band)    │    │
│  │    brand, objectType    │    │  → Computes avgPrice         │    │
│  │  → normalizedPrice =    │    │  → Normalizes within         │    │
│  │    originalPrice        │    │    80%–120% of average       │    │
│  │                         │    │  → LLM fallback if no        │    │
│  │  sortingQueue: LOGIS-   │    │    catalog match (Nova       │    │
│  │  TICS_OPTIMIZATION      │    │    vision-aware pricing)     │    │
│  │  priority: HIGH         │    │  sortingQueue: CONSUMER_     │    │
│  │                         │    │  TRADE_IN / NORMAL           │    │
│  └─────────────────────────┘    └──────────────────────────────┘    │
│                   │                             │                    │
│                   └──────────────┬──────────────┘                   │
│                                  ▼                                   │
│              saveEvaluationInput() → DynamoDB Evaluations            │
│              (evaluationId, normalizedPrice, sortingQueue, ...)      │
└──────────────────────────────────┬──────────────────────────────────┘
                                   │
┌──────────────────────────────────▼──────────────────────────────────┐
│  TIER 4 — AI INFERENCE PIPELINE                                      │
│                                                                      │
│  POST /ai-grade → AmazeLoopAiGradeFunction                           │
│                                                                      │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  1. Fetch photo bytes from S3 (up to 4 images)               │  │
│  │  2. Pass to Amazon Bedrock (Amazon Nova Lite vision model)   │  │
│  │                                                               │  │
│  │  Strict LLM prompt enforces:                                 │  │
│  │  ┌─────────────────────────────────────────────────────┐    │  │
│  │  │  Condition   │ conditionScore │ priceMultiplier band │    │  │
│  │  │─────────────────────────────────────────────────────│    │  │
│  │  │  Like New    │    0.8–1.0     │      0.8–1.0         │    │  │
│  │  │  Good        │    0.6–0.8     │      0.6–0.8         │    │  │
│  │  │  Used        │    0.4–0.6     │      0.4–0.6         │    │  │
│  │  │  Damaged     │    0.0–0.25    │      0.1–0.2 (hard)  │    │  │
│  │  └─────────────────────────────────────────────────────┘    │  │
│  │                                                               │  │
│  │  Hard rule: cracked/shattered screen → MUST be Damaged       │  │
│  │  Damaged items: estimatedResaleValue = 0 (Recycle only)      │  │
│  │                                                               │  │
│  │  3. estimatedResaleValue = normalizedPrice × priceMultiplier │  │
│  │     (rounded to nearest ₹10)                                 │  │
│  │  4. bestPhotoIndex stored for HealthCard hero image          │  │
│  │  5. UpdateItem → Evaluations table                           │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  POST /route → AmazeLoopRouteFunction                                │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  1. Haversine distance to nearest warehouse hub               │  │
│  │     (BLR / MUM / DEL / HYD / MAA / PNQ)                     │  │
│  │  2. Rule-based disposition matrix:                            │  │
│  │     sortingQueue + condition + resaleValue → disposition      │  │
│  │  3. LLM generates one-sentence routeReason (Nova)            │  │
│  │  4. finalDisposition: Resell / Refurbish / Recycle            │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  POST /route/confirm → AmazeLoopRouteConfirmFunction                 │
│  Sets chosenDisposition, isOverride, status = "ROUTED"               │
└──────────────────────────────────────────────────────────────────────┘
3. Data Management: Identity-Bound Strategy
All evaluation records are partitioned by Cognito User Identity (userId = sub claim) rather than by warehouse zone, product category, or submission date. This design decision has three consequences:

Partition strategy:

DynamoDB: Evaluations
  Partition key:  evaluationId  (EVAL-<uuid>)
  GSI-1:          userId-createdAt-index
                  → enables O(log n) per-user history queries
                  → sorted by createdAt DESC (newest first)
  GSI-2:          userId-createdAt-index (same GSI)
                  → warehouse view uses nearestWarehouseId scan
                    (planned GSI upgrade)
Catalog partitioning:

DynamoDB: ProductsCatalog
  Partition key:  productId
  GSI:            orderId-index
                  → O(1) catalog lookup by order ID
                  → eliminates full-table scan for order-ID path
Privacy boundary: A user's evaluation history is never accessible to another user. The history endpoint derives userId from Cognito authorizer claims when available, falling back to the query parameter only when no authorizer is configured — ensuring the identity boundary is enforced at the infrastructure level once an authorizer is attached.

4. Key Achievements
End-to-end AI grading workflow. The platform successfully chains five independent Lambda functions (upload-url → grade → ai-grade → route → route-confirm) with DynamoDB as the shared state store. Each step is independently retryable and stateless. The vision grading pipeline uses Amazon Bedrock (Nova Lite) with a structured JSON output contract and hard-coded rules to prevent the model from under-penalizing visibly damaged items.

Dual-stream sorting logic. The Smart Gateway automatically classifies each submission into one of two queues based on the reason field: LOGISTICS_OPTIMIZATION_QUEUE (Amazon returns, priority HIGH) and CONSUMER_TRADE_IN_QUEUE (unused items, priority NORMAL). This drives different routing rules downstream — returned Amazon orders are prioritized for direct resale on Amazon Renewed, while consumer trade-ins are evaluated for local marketplace or recycling pathways.

LLM-assisted price normalization. When the ProductsCatalog has no comparable items in the user's price tier, the system falls back to a vision-augmented LLM call — passing both the product photo and catalog samples as context — to estimate a fair like-new reference price. This prevents unchecked user-entered prices from inflating or distorting the AI's resale value calculation.

Role-based data isolation. Cognito user attributes store a custom:role (warehouse / customer) at sign-up. The session is held in-memory post-login and sent with every grading request, enabling the backend to annotate evaluations with userRole for downstream warehouse-filtering views.

5. Technology Stack
Layer	Technology	Purpose
Authentication	AWS Amplify + Amazon Cognito	Email/password auth, role attributes, session management
Frontend	Flutter (Web + Mobile)	Cross-platform dashboard, form submission, HealthCard
API Gateway	Amazon API Gateway (HTTP API)	CORS-enabled routing to Lambda functions
Compute	AWS Lambda (Node.js 20)	Stateless microservices for each pipeline stage
Object Storage	Amazon S3	Photo storage via presigned PUT URLs
Vision AI	Amazon Bedrock — Amazon Nova Lite	Product condition grading from photos
Price Intelligence	Amazon Bedrock — Amazon Nova Lite	LLM-based price estimation when catalog is sparse
Database	Amazon DynamoDB	Evaluations store + ProductsCatalog with GSIs
PDF Generation	Flutter pdf + printing packages	HealthCard report download
Routing Logic	Custom Haversine + rule engine (Lambda)	Nearest warehouse + disposition matrix
CI/CD	Git (local commits, GitHub push)	Version control
Note on Lambda runtime: All Lambda functions in this implementation use Node.js 20 (ESM modules). The prompt specification listed Python — the implementation choice was Node.js for consistency with the AWS SDK v3 ESM patterns and the inline vision model integration.

6. API Surface
Endpoint	Method	Function	Description
/upload-url	POST	AmazeLoopUploadUrlFunction	Returns presigned S3 PUT URL
/grade	POST	AmazeLoopGradeFunction	Price/order normalization + Evaluation creation
/ai-grade	POST	AmazeLoopAiGradeFunction	Vision grading + resale value computation
/route	POST	AmazeLoopRouteFunction	Warehouse distance + disposition decision + LLM explanation
/route/confirm	POST	AmazeLoopRouteConfirmFunction	Records user's chosen disposition, sets ROUTED status
/evaluations	GET	AmazeLoopEvalListFunction	User's evaluation history (userId-partitioned)
All endpoints share a single API Gateway (bu719hnik3, ap-south-1) with CORS configured for GET, POST, OPTIONS.

7. Data Flow Summary

User submits form
    │
    ├─► POST /upload-url × N  ──► S3 (private bucket, public-read policy)
    │
    ├─► POST /grade
    │       ├─ ORD-xxx  → ProductsCatalog GSI query → catalog price
    │       └─ numeric  → category scan → tier filter → avg OR LLM fallback
    │       └─ saves Evaluation (evaluationId, normalizedPrice, sortingQueue)
    │
    ├─► POST /ai-grade
    │       ├─ S3 photo fetch → Bedrock Nova vision
    │       └─ condition + conditionScore + priceMultiplier + bestPhotoIndex
    │       └─ estimatedResaleValue = normalizedPrice × multiplier
    │       └─ updates Evaluation
    │
    ├─► POST /route
    │       ├─ Haversine → nearestWarehouseId + distanceKm
    │       ├─ sortingQueue + condition → recommendedRoute + finalDisposition
    │       └─ Nova LLM → routeReason (one sentence)
    │       └─ updates Evaluation
    │
    ├─► User selects / overrides disposition
    │
    └─► POST /route/confirm
            └─ chosenDisposition + isOverride + status = "ROUTED"
            └─ Frontend navigates to History tab
Document prepared for AmazeLoop — Build for Tomorrow Hackathon submission.
