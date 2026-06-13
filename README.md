AmazeLoop: Technical Architecture Document
Platform Classification: Consumer-to-Business (C2B) Trade-In & Recommerce
Version: 1.0 | Environment: AWS ap-south-1 (Mumbai)

1. Project Overview
AmazeLoop is a dual-stream recommerce platform designed to give used products a structured second life. It operates across two distinct input channels: Amazon returns (logistics-optimization stream) and consumer trade-ins of unused household goods. Upon item submission, the platform performs automated condition grading using computer vision, normalizes the item's fair market value against a catalog of reference products, and routes the item to the most economically optimal disposition — Resell, Refurbish, or Recycle.

The system is built as a serverless, event-driven architecture on AWS, with a Flutter-based web/mobile frontend and a pipeline of independent Lambda microservices communicating through Amazon DynamoDB as the shared state store.

2. Core Architecture: Four-Tier Flow
graph TD
    User[Flutter Web Dashboard] -->|HTTPS| API[API Gateway]
    API --> Grade[Grade Function]
    API --> AI[AI Grade Function]
    API --> Route[Route Function]
    
    Grade --> Dynamo[(DynamoDB)]
    AI --> S3[(S3 Photos)]
    AI --> Bedrock[Amazon Bedrock]
    Route --> Dynamo
    
    style AI fill:#f96,stroke:#333
    style Grade fill:#69f,stroke:#333
   
4. Data Management: Identity-Bound Strategy
All evaluation records are partitioned by Cognito User Identity (userId = sub claim) rather than by warehouse zone, product category, or submission date. This design decision has three consequences:

Partition strategy:

DynamoDB: Evaluations
  Partition key:  evaluationId  (EVAL-<uuid>)
  GSI-1:          userId-createdAt-index
                  → enables O(log n) per-user history queries
                  → sorted by createdAt DESC (newest first)
  GSI-2:          userId-createdAt-index (same GSI)
                  → warehouse view uses nearestWarehouseId scan
                    (planned GSI upgrade)
Catalog partitioning:

DynamoDB: ProductsCatalog
  Partition key:  productId
  GSI:            orderId-index
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

### AmazeLoop Grade Item Pipeline

| Stage | Action | Backend Component | Key Logic |
| :--- | :--- | :--- | :--- |
| **1. Ingestion** | Upload Photos | `AmazeLoopUploadUrl` | Presigned S3 PUT URLs |
| **2. Gateway** | Validate & Save | `AmazeLoopGrade` | Catalog lookup or Price normalization |
| **3. Inference** | AI Grading | `AmazeLoopAiGrade` | Rekognition Labels → Rule-based Scoring |
| **4. Routing** | Final Disposition | `AmazeLoopRoute` | Distance calculation & Queue sorting |

---

### Execution Details
<details>
<summary>Click to view technical specs</summary>

| Step | Data Output | Disposition Trigger |
| :--- | :--- | :--- |
| **Grade** | `evaluationId`, `normalizedPrice` | Assigns `sortingQueue` (LOGISTICS vs CONSUMER) |
| **AI Grade** | `condition`, `resaleValue` | Applies multiplier (1.0 to 0.3) based on score |
| **Route** | `finalDisposition` | Routes to Resell, Refurbish, or Recycle |

</details>

7. Data Flow Summary

User submits form
    │
    ├─► POST /upload-url × N  ──► S3 (private bucket, public-read policy)
    │
    ├─► POST /grade
    │       ├─ ORD-xxx  → ProductsCatalog GSI query → catalog price
    │       └─ numeric  → category scan → tier filter → avg OR LLM fallback
    │       └─ saves Evaluation (evaluationId, normalizedPrice, sortingQueue)
    │
    ├─► POST /ai-grade
    │       ├─ S3 photo fetch → Bedrock Nova vision
    │       └─ condition + conditionScore + priceMultiplier + bestPhotoIndex
    │       └─ estimatedResaleValue = normalizedPrice × multiplier
    │       └─ updates Evaluation
    │
    ├─► POST /route
    │       ├─ Haversine → nearestWarehouseId + distanceKm
    │       ├─ sortingQueue + condition → recommendedRoute + finalDisposition
    │       └─ Nova LLM → routeReason (one sentence)
    │       └─ updates Evaluation
    │
    ├─► User selects / overrides disposition
    │
    └─► POST /route/confirm
            └─ chosenDisposition + isOverride + status = "ROUTED"
            └─ Frontend navigates to History tab
Document prepared for AmazeLoop — Build for Tomorrow Hackathon submission.
