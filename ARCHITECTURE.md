# AmazeLoop — Architecture

> A dual-stream recommerce prototype: items are photographed, **AI-graded** for condition, priced,
> routed to the most economical disposition, and sold on a trust-first marketplace.
>
> **Frontend:** Flutter (Web) · **Backend:** AWS serverless (Lambda + API Gateway + DynamoDB + S3 +
> Bedrock + Cognito), region `ap-south-1`.
>
> This file is the high-level map. See `README.md` for the deep dive (data model, per-Lambda detail,
> deployment, design tradeoffs).

---

## 1. System overview

```
Flutter Web (Chrome)
   │  HTTPS REST/JSON            Amplify Auth (Cognito)
   ▼                                   ▼
API Gateway HTTP API  ──────►  Cognito User Pool (email/password, custom:role)
   │  AWS_PROXY
   ▼
AWS Lambda (Node.js, ESM) — 13 functions
   ├── DynamoDB  (Evaluations, ProductsCatalog, AmazeLoopNotifications)
   ├── Amazon S3 (product photos via presigned PUT)
   └── Amazon Bedrock — Nova Pro (vision grading + routing explanation)

EventBridge rate(15 min) ──► reservation-sweep Lambda
```

The pipeline is event-driven and stateless: each stage is an independent Lambda, with DynamoDB as the
shared state store keyed by `evaluationId`.

---

## 2. Frontend structure (`lib/`)

```
lib/
  main.dart                     # App entry, theme, Amplify init; opens RoleSelectionScreen
  constants.dart                # Brand colours (navy, orange, text)
  amplifyconfiguration.dart     # Cognito pool config

  # ── Entry / role selection ──────────────────────────────────────────────
  RoleSelectionScreen.dart      # Main menu: Shop Marketplace vs Sell / Trade-in
  SellerTypeScreen.dart         # Warehouse vs Consumer trade-in (locks role on signup)
  SellIntroScreen.dart          # "How selling works" intro

  # ── Buyer shell + tabs ──────────────────────────────────────────────────
  BuyerDashboard.dart           # Buyer shell: 4 tabs + "Back to main menu"
  MarketplaceTab.dart           # Listing grid, search, filters, "Load more" pagination
  ListingDetailScreen.dart      # Gallery + Health Card + Reserve/Buy / purchased panel
  ReservedTab.dart              # Active 24h holds: Buy now, "Remove & relist"
  PurchasesTab.dart             # SOLD items + View Health Card
  NotificationsTab.dart         # In-app notifications feed

  # ── Seller pipeline (inside dashboard shell) ─────────────────────────────
  views/
    login_view.dart             # Cognito sign-up / sign-in, verify, reset password
    dashboard_layout.dart       # Seller shell (Grade New Item / History) + "Main menu"
    submit_item_view.dart       # Step 1: details + photo upload
    grading_result_view.dart    # Step 2: AI condition result
    routing_decision_view.dart  # Step 3: route options + confirm/override
    health_card_view.dart       # Step 4: Health Card (PDF, mis-graded feedback, sustainability)
    history_view.dart           # Seller's past evaluations table

  # ── Data layer ───────────────────────────────────────────────────────────
  data/
    session.dart                # In-memory userId / role / idToken (+ isSignedIn)
    route_helpers.dart          # Role-based route visibility, disposition labels, donate rule
    sustainability.dart         # Reuse/transport CO2 estimates + deterministic impact text
    report_generator.dart       # PDF Health Card builder
    repositories/
      grade_repository.dart     # Single HTTP client for ALL backend endpoints (real AWS)
    models/
      evaluation_input.dart     # Active model threaded through the seller pipeline
      listing.dart              # Buyer listing card
      listing_detail.dart       # Listing + images + Health Card
      purchase.dart             # Buyer's reserved/sold item
      app_notification.dart     # Notification item
```

**Single repository:** `grade_repository.dart` owns every base URL, header, JSON parse, and the
`Authorization: Bearer <idToken>` attachment, so screens stay thin.

**Legacy/unused (prototype cruft):** `lib/EvaluationModel.dart` (`Evaluation`) and
`lib/data/models/app_models.dart` (`ItemPayload`, `GradingResult`) are leftovers from the early
mock phase and are not referenced by the current code (the active model is `EvaluationInput`). The
old `mock_repository.dart` has been removed — the app talks to the real AWS backend.

---

## 3. Backend Lambdas (`backend/`)

All Node.js ESM, one folder per function, least-privilege IAM per Lambda, CORS at the API level.

| Folder | Function | Route | Auth |
| :--- | :--- | :--- | :--- |
| `upload-url` | UploadUrlFunction | `POST /upload-url` | public (demo) |
| `grade` | GradeFunction | `POST /grade` | public (demo) |
| `ai-grade` | AiGradeFunction | `POST /ai-grade` | public (demo) |
| `route` | RouteFunction | `POST /route` | public (demo) |
| `route-confirm` | RouteConfirmFunction | `POST /route/confirm` | public (demo) |
| `evaluations-list` | EvalListFunction | `GET /evaluations` | public (demo) |
| `listings` | ListingsFunction | `GET /listings` | public |
| `listing-detail` | ListingDetailFunction | `GET /listings/{id}` | public |
| `purchase` | PurchaseFunction | `POST /purchase` (RESERVE/BUY/CANCEL) | **JWT** |
| `purchases` | MyPurchasesFunction | `GET /purchases` | **JWT** |
| `notifications` | NotificationsFunction | `GET /notifications` | **JWT** |
| `feedback` | FeedbackFunction | `POST /feedback` | public (demo) |
| `reservation-sweep` | ReservationSweepFunction | EventBridge `rate(15 min)` | n/a |

See README §9 for the deliberate public-vs-JWT security model and the production hardening plan.

---

## 4. Data stores & external services

- **DynamoDB**
  - `Evaluations` — central record (PK `evaluationId`); `userId-createdAt` GSI for seller history.
    Holds grading, routing, photos, and the purchase/reservation lifecycle fields.
  - `ProductsCatalog` — reference products for fair-price normalization (`productId` PK, `orderId` GSI).
  - `AmazeLoopNotifications` — in-app notifications (PK `userId`, SK `createdAt`).
- **Amazon S3** — `amazeloop-photos-<account>`; the browser uploads photos directly via presigned PUT
  URLs, so image bytes never pass through Lambda.
- **Amazon Bedrock — Nova Pro** (`apac.amazon.nova-pro-v1:0`) — vision condition grading (temp 0.15)
  and a one-sentence routing explanation (temp 0.2). Used with a strict JSON contract; the model
  never makes the final routing decision.
- **Cognito User Pool** — email/password (SRP), `custom:role` = `customer` | `warehouse`.
- **API Gateway HTTP API** — AWS_PROXY integrations + Cognito JWT authorizer on protected routes.

---

## 5. Buyer flow

```
RoleSelection → Shop Marketplace → BuyerDashboard
  Marketplace      GET /listings (paginated "Load more")
  Listing detail   GET /listings/{id} → images + Health Card + return-risk insights
  Reserve          POST /purchase {RESERVE} → 24h hold, leaves marketplace, Reserved tab
  Remove & relist  POST /purchase {CANCEL} → releases hold back to marketplace
  Buy              POST /purchase {BUY}    → SOLD, My Purchases (shows purchase date)
  Reserved tab     GET /purchases?status=RESERVED  (countdown)
  Purchases tab    GET /purchases?status=SOLD
  Notifications    GET /notifications  (reserve/buy/expiry/relist)
```

Reserve/Buy/Cancel use DynamoDB conditional writes so two buyers can't claim the same item; a loser
gets HTTP 409 ("reserved by another buyer"). Guest browsing needs no login; Reserve/Buy gate to login.

---

## 6. Seller flow

```
RoleSelection → Sell/Trade-in → SellerType → Login → (SellIntro) → Seller dashboard
  Submit item     POST /upload-url ×N (photos) → POST /grade  (price normalization)
  AI grade        POST /ai-grade   (Bedrock vision: condition, score, reason, best photo)
  Route           POST /route      (economics router + nearest warehouse + AI explanation)
  Confirm         POST /route/confirm  (lock chosenDisposition, status = ROUTED)
  Health Card     condition, est. value, disposition, next steps, sustainability impact,
                  download PDF, "Mark as mis-graded" → POST /feedback
  History         GET /evaluations  (per-user, newest first)
```

**Dispositions:** `Resell`, `Refurbish`, `Recycle`, `ReturnToOrigin` (warehouse-only, when the item
is a customer return with an origin hub available), and `Donate` (auto-recommended for usable
Used/Good items with resale value ≤ ₹1000). Confirming a `Resell` route makes the item appear on the
marketplace automatically; `Recycle`/`Donate`/`ReturnToOrigin` are never listed.

---

## 7. Cross-cutting

- **Auth/session:** identity comes from the Cognito JWT `sub` on protected routes (never the request
  body); `Session` caches it in memory for the session.
- **Reservation lifecycle:** a 24h hold is freed two ways — lazy checks in `/listings` and
  `/purchases` keep reads correct immediately, and the scheduled sweep proactively releases expired
  holds and notifies the buyer + seller.
- **Sustainability:** `sustainability.dart` computes reuse/transport CO2 and a deterministic,
  approximate impact summary shown on both Health Cards (reverse-shipping/transport lines are
  suppressed for "Unused at home" items).

---

## 8. Prototype limitations (intentional, hackathon scope)

- **Some seller-flow routes are public for demo speed** (`/upload-url`, `/grade`, `/ai-grade`,
  `/route`, `/route/confirm`, `/evaluations`); in production they'd sit behind the same JWT authorizer
  as the purchase routes (README §9).
- **Notifications are in-app only** (DynamoDB), not push/email/SMS.
- **Listings/purchases use DynamoDB Scans** — fine at hackathon scale; GSIs are the documented upgrade.
- **Reservation release isn't instant** — correct on read immediately, but the proactive sweep runs
  every ~15 minutes.
- **Sustainability and Health Card figures are approximations** (category-keyed CO2, distance-based
  transport estimates); warranty is reported honestly as "No warranty" rather than fabricated.
- **AI vision grading needs a real uploaded photo** — it can't grade placeholder URLs.
- **Legacy model files** (`EvaluationModel.dart`, `app_models.dart`) remain in the tree but are unused.

---

*Built for the AmazeLoop — Build for Tomorrow hackathon. See README.md for full detail.*
