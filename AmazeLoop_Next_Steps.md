# AmazeLoop: Backend Integration & Buyer Marketplace — Implementation Plan

**Platform Classification:** Consumer-to-Business (C2B) Trade-In & Recommerce  
**Version:** 1.1 | **Environment:** AWS ap-south-1 (Mumbai)  
**Scope:** Buyer-side marketplace integration, auth token propagation, and purchase flow

---

## 1. Current State Summary

The seller pipeline is fully operational end-to-end:

```
User Login (Cognito) → Grade New Item → AI Vision Grading → Routing Decision → Confirm → History
```

**What exists and works:**
- 5 Lambda functions chained via DynamoDB shared state (`/upload-url`, `/grade`, `/ai-grade`, `/route`, `/route/confirm`)
- Evaluation history per user via `GET /evaluations?userId=xxx`
- Presigned S3 uploads for condition photos
- Amazon Bedrock (Nova Lite) vision grading with structured condition scoring
- Haversine routing to nearest warehouse hub
- Flutter seller dashboard with full UI and API integration
- Cognito authentication (email/password, custom `role` attribute)

**What exists but uses mock data:**
- Buyer marketplace (`MarketplaceTab.dart`) — hardcoded product cards
- Listing detail screen (`ListingDetailScreen.dart`) — hardcoded health card
- Purchase history (`PurchasesTab.dart`) — hardcoded items

**What's missing entirely:**
- Backend endpoints for buyer-facing features
- Auth token propagation on API requests
- Session hydration after login
- Real-time marketplace data flow

---

## 2. Architecture Extension: Buyer Stream

```
┌──────────────────────────────────────────────────────────────────────────┐
│  EXISTING SELLER FLOW (Complete)                                          │
│                                                                           │
│  POST /upload-url → POST /grade → POST /ai-grade → POST /route           │
│       → POST /route/confirm → GET /evaluations                           │
│                                                                           │
│  Status lifecycle: PENDING → GRADED → ROUTED → SOLD                      │
└──────────────────────────────────────┬───────────────────────────────────┘
                                       │
                                       │ Items with status="ROUTED" AND
                                       │ chosenDisposition="Resell"
                                       ▼
┌──────────────────────────────────────────────────────────────────────────┐
│  NEW BUYER FLOW (To Implement)                                            │
│                                                                           │
│  ┌─────────────────────┐                                                 │
│  │  GET /listings      │ ← Fetches all resale-eligible items              │
│  │  AmazeLoopListings  │   (status=ROUTED, chosenDisposition=Resell)      │
│  │  Function           │   Returns: product, condition, resaleValue,      │
│  │                     │   photos, healthCard data                        │
│  └─────────┬───────────┘                                                 │
│            │                                                              │
│            ▼                                                              │
│  ┌─────────────────────┐                                                 │
│  │  POST /purchase     │ ← Buyer clicks "Reserve / Buy Now"              │
│  │  AmazeLoopPurchase  │   Marks item status="SOLD", sets buyerId         │
│  │  Function           │   Prevents double-purchase via conditional       │
│  │                     │   write (ConditionExpression: status=ROUTED)     │
│  └─────────┬───────────┘                                                 │
│            │                                                              │
│            ▼                                                              │
│  ┌─────────────────────┐                                                 │
│  │  GET /purchases     │ ← Buyer's order history                          │
│  │  AmazeLoopPurchases │   Queries: buyerId-createdAt-index               │
│  │  Function           │   Returns items user has purchased               │
│  └─────────────────────┘                                                 │
│                                                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## 3. New DynamoDB Indexes Required

### Evaluations Table — New GSIs

| GSI Name | Partition Key | Sort Key | Purpose |
|----------|--------------|----------|---------|
| `status-createdAt-index` | `status` (String) | `createdAt` (String) | Efficient marketplace listing query — fetch all ROUTED items sorted by newest |
| `buyerId-createdAt-index` | `buyerId` (String) | `createdAt` (String) | Buyer purchase history — fetch all items purchased by a specific user |

**Why not Scan?**  
A Scan with FilterExpression would work for hackathon volume (<1000 items) but becomes O(n) at scale. The GSI makes marketplace queries O(log n) and eliminates read-capacity waste.

**Hackathon shortcut:** Skip the GSIs and use Scan + FilterExpression. Add GSIs later when table grows beyond 10K items.

---

## 4. New Lambda Implementations

### 4.1 `AmazeLoopListingsFunction` — GET /listings

**Purpose:** Serves the buyer marketplace with all available-for-purchase items.

```javascript
// Runtime: Node.js 20 (ESM)
// Trigger: API Gateway GET /listings
// Query params: ?limit=20&category=Electronics (optional filter)

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand, ScanCommand } from '@aws-sdk/lib-dynamodb';

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.TABLE_NAME || 'Evaluations';

export const handler = async (event) => {
  const params = event.queryStringParameters || {};
  const limit = parseInt(params.limit) || 20;
  const category = params.category;

  // Option A: Using the status-createdAt GSI (recommended)
  const queryParams = {
    TableName: TABLE,
    IndexName: 'status-createdAt-index',
    KeyConditionExpression: '#status = :routed',
    FilterExpression: 'chosenDisposition = :resell',
    ExpressionAttributeNames: { '#status': 'status' },
    ExpressionAttributeValues: {
      ':routed': 'ROUTED',
      ':resell': 'Resell',
    },
    ScanIndexForward: false, // newest first
    Limit: limit,
  };

  // Optional category filter
  if (category) {
    queryParams.FilterExpression += ' AND category = :cat';
    queryParams.ExpressionAttributeValues[':cat'] = category;
  }

  try {
    const result = await client.send(new QueryCommand(queryParams));
    
    // Shape response for marketplace display
    const listings = (result.Items || []).map(item => ({
      evaluationId: item.evaluationId,
      productName: item.productName,
      category: item.category,
      condition: item.condition,
      conditionReason: item.conditionReason,
      estimatedResaleValue: item.estimatedResaleValue,
      photoUrls: item.photoUrls || [],
      bestPhotoIndex: item.bestPhotoIndex,
      finalDisposition: item.finalDisposition,
      recommendedRoute: item.recommendedRoute,
      routeReason: item.routeReason,
      createdAt: item.createdAt,
      sellerId: item.userId, // seller identity (for display only)
    }));

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ listings, count: listings.length }),
    };
  } catch (err) {
    console.error('Listings query failed:', err);
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: 'Failed to load marketplace listings.' }),
    };
  }
};
```

---

### 4.2 `AmazeLoopPurchaseFunction` — POST /purchase

**Purpose:** Atomically reserves/purchases an item, preventing double-buy race conditions.

```javascript
// Runtime: Node.js 20 (ESM)
// Trigger: API Gateway POST /purchase
// Body: { evaluationId, buyerId }

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand } from '@aws-sdk/lib-dynamodb';

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.TABLE_NAME || 'Evaluations';

export const handler = async (event) => {
  const body = JSON.parse(event.body || '{}');
  const { evaluationId, buyerId } = body;

  if (!evaluationId || !buyerId) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: 'evaluationId and buyerId are required.' }),
    };
  }

  try {
    // Conditional update: only succeeds if item is still ROUTED (not already sold)
    await client.send(new UpdateCommand({
      TableName: TABLE,
      Key: { evaluationId },
      UpdateExpression: 'SET #status = :sold, buyerId = :buyer, purchasedAt = :now',
      ConditionExpression: '#status = :routed',
      ExpressionAttributeNames: { '#status': 'status' },
      ExpressionAttributeValues: {
        ':sold': 'SOLD',
        ':routed': 'ROUTED',
        ':buyer': buyerId,
        ':now': new Date().toISOString(),
      },
    }));

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ success: true, message: 'Item purchased successfully.' }),
    };
  } catch (err) {
    if (err.name === 'ConditionalCheckFailedException') {
      return {
        statusCode: 409,
        headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
        body: JSON.stringify({ error: 'Item is no longer available (already sold or not yet routed).' }),
      };
    }
    console.error('Purchase failed:', err);
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: 'Purchase failed. Please try again.' }),
    };
  }
};
```

**Key design decision:** The `ConditionExpression: status = :routed` guarantees atomic reservation — if two buyers click "Buy" simultaneously, only one succeeds. The other gets a 409 Conflict. This is the DynamoDB equivalent of a distributed lock.

---

### 4.3 `AmazeLoopPurchaseHistoryFunction` — GET /purchases

**Purpose:** Returns a buyer's purchase history.

```javascript
// Runtime: Node.js 20 (ESM)
// Trigger: API Gateway GET /purchases?buyerId=xxx&limit=20

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, QueryCommand } from '@aws-sdk/lib-dynamodb';

const client = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const TABLE = process.env.TABLE_NAME || 'Evaluations';

export const handler = async (event) => {
  const params = event.queryStringParameters || {};
  const buyerId = params.buyerId;
  const limit = parseInt(params.limit) || 20;

  if (!buyerId) {
    return {
      statusCode: 400,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: 'buyerId query parameter is required.' }),
    };
  }

  try {
    // Uses the buyerId-createdAt-index GSI
    const result = await client.send(new QueryCommand({
      TableName: TABLE,
      IndexName: 'buyerId-createdAt-index',
      KeyConditionExpression: 'buyerId = :buyer',
      ExpressionAttributeValues: { ':buyer': buyerId },
      ScanIndexForward: false, // newest purchases first
      Limit: limit,
    }));

    const purchases = (result.Items || []).map(item => ({
      evaluationId: item.evaluationId,
      productName: item.productName,
      category: item.category,
      condition: item.condition,
      estimatedResaleValue: item.estimatedResaleValue,
      photoUrls: item.photoUrls || [],
      purchasedAt: item.purchasedAt,
      conditionReason: item.conditionReason,
    }));

    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ purchases, count: purchases.length }),
    };
  } catch (err) {
    console.error('Purchase history query failed:', err);
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
      body: JSON.stringify({ error: 'Failed to load purchase history.' }),
    };
  }
};
```

---

## 5. Auth Token Propagation Strategy

### Problem

Currently, `GradeRepository` makes unauthenticated HTTP calls. The backend accepts `userId` as a body/query parameter — meaning any client can impersonate any user.

### Solution: JWT Authorization Header

```
┌──────────────┐          ┌─────────────────┐          ┌───────────────┐
│  Flutter App │  ──────► │  API Gateway    │  ──────► │  Lambda       │
│              │  Auth:   │  + Cognito      │  Claims  │  Receives     │
│  Fetches JWT │  Bearer  │  Authorizer     │  injected│  verified     │
│  from Cognito│  <token> │  (validates JWT)│  into    │  userId from  │
│              │          │                 │  event   │  authorizer   │
└──────────────┘          └─────────────────┘          └───────────────┘
```

### Frontend Implementation (Dart)

```dart
// In lib/data/session.dart — add token storage:

class Session {
  static String? userId;
  static String? role;
  static String? accessToken;  // ADD THIS
  static String? idToken;      // ADD THIS

  static void clear() {
    userId = null;
    role = null;
    accessToken = null;
    idToken = null;
  }
}
```

```dart
// In login_view.dart — after successful Cognito sign-in:

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';

final session = await Amplify.Auth.fetchAuthSession();
final cognitoSession = session as CognitoAuthSession;
final tokens = cognitoSession.userPoolTokensResult.value;

Session.userId = tokens.idToken.claims['sub'] as String;
Session.role = tokens.idToken.claims['custom:role'] as String? ?? 'customer';
Session.accessToken = tokens.accessToken.toJson();
Session.idToken = tokens.idToken.toJson();
```

```dart
// In GradeRepository — add auth header to every request:

Map<String, String> get _headers => {
  'Content-Type': 'application/json',
  if (Session.accessToken != null)
    'Authorization': 'Bearer ${Session.accessToken}',
};

// Then replace all hardcoded headers:
// Before: headers: {'Content-Type': 'application/json'},
// After:  headers: _headers,
```

### Backend Implementation (API Gateway)

1. Create a **Cognito Authorizer** on API Gateway:
   - Type: JWT
   - Issuer URL: `https://cognito-idp.ap-south-1.amazonaws.com/ap-south-1_ybxclrVkJ`
   - Audience: `40bdcbv5gfpjkjub33kdhva35h`

2. Attach the authorizer to all routes except `/listings` (public for browsing)

3. In Lambda, extract userId from the authorizer claims:
```javascript
// event.requestContext.authorizer.jwt.claims.sub
const userId = event.requestContext?.authorizer?.jwt?.claims?.sub;
```

---

## 6. Frontend Wiring: Buyer Repository

New file: `lib/data/repositories/buyer_repository.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../session.dart';

class BuyerRepository {
  static const String _baseUrl =
      'https://bu719hnik3.execute-api.ap-south-1.amazonaws.com';

  static const String _listingsUrl = '$_baseUrl/listings';
  static const String _purchaseUrl = '$_baseUrl/purchase';
  static const String _purchasesUrl = '$_baseUrl/purchases';

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (Session.accessToken != null)
      'Authorization': 'Bearer ${Session.accessToken}',
  };

  /// Fetches marketplace listings (publicly browsable, no auth required)
  Future<List<Map<String, dynamic>>> getListings({
    int limit = 20,
    String? category,
  }) async {
    final params = <String, String>{'limit': '$limit'};
    if (category != null) params['category'] = category;

    final uri = Uri.parse(_listingsUrl).replace(queryParameters: params);
    final response = await http.get(uri, headers: {'Content-Type': 'application/json'});

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(decoded['listings'] ?? []);
    } else {
      throw Exception('Failed to load listings (${response.statusCode}).');
    }
  }

  /// Purchases/reserves an item (requires auth)
  Future<void> purchaseItem(String evaluationId) async {
    final response = await http.post(
      Uri.parse(_purchaseUrl),
      headers: _headers,
      body: jsonEncode({
        'evaluationId': evaluationId,
        'buyerId': Session.userId,
      }),
    );

    if (response.statusCode == 409) {
      throw Exception('This item is no longer available.');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(decoded['error']?.toString() ?? 'Purchase failed.');
    }
  }

  /// Fetches buyer's purchase history (requires auth)
  Future<List<Map<String, dynamic>>> getPurchases({int limit = 20}) async {
    final params = <String, String>{
      'buyerId': Session.userId ?? '',
      'limit': '$limit',
    };

    final uri = Uri.parse(_purchasesUrl).replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(decoded['purchases'] ?? []);
    } else {
      throw Exception('Failed to load purchases (${response.statusCode}).');
    }
  }
}
```

---

## 7. API Gateway Route Registration

Add these routes to the existing API Gateway (`bu719hnik3`):

| Route | Method | Integration | Authorizer |
|-------|--------|-------------|------------|
| `/listings` | GET | `AmazeLoopListingsFunction` | None (public) |
| `/purchase` | POST | `AmazeLoopPurchaseFunction` | Cognito JWT |
| `/purchases` | GET | `AmazeLoopPurchaseHistoryFunction` | Cognito JWT |

**CORS configuration** (same as existing routes):
- Allow Origins: `*`
- Allow Methods: `GET, POST, OPTIONS`
- Allow Headers: `Content-Type, Authorization`

---

## 8. Evaluation Status Lifecycle (Complete)

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│ PENDING │ ──► │ GRADED  │ ──► │ ROUTED  │ ──► │  SOLD   │
└─────────┘     └─────────┘     └─────────┘     └─────────┘
     │               │               │               │
     │               │               │               │
  /grade          /ai-grade       /route/        /purchase
  creates         updates          confirm         buyer
  record          condition        sets            claims
                  + resale         disposition     the item
```

- `PENDING` — Evaluation created by `/grade`, awaiting AI analysis
- `GRADED` — AI condition + resale value computed by `/ai-grade`  
- `ROUTED` — Disposition confirmed by seller via `/route/confirm`, visible on marketplace
- `SOLD` — Buyer purchased via `/purchase`, no longer shown on marketplace

---

## 9. Deployment Checklist

### AWS Console Steps

| # | Action | Service | Notes |
|---|--------|---------|-------|
| 1 | Create `AmazeLoopListingsFunction` | Lambda | Node.js 20, ESM, env: TABLE_NAME=Evaluations |
| 2 | Create `AmazeLoopPurchaseFunction` | Lambda | Node.js 20, ESM, env: TABLE_NAME=Evaluations |
| 3 | Create `AmazeLoopPurchaseHistoryFunction` | Lambda | Node.js 20, ESM, env: TABLE_NAME=Evaluations |
| 4 | Add GSI `status-createdAt-index` | DynamoDB | PK: status, SK: createdAt |
| 5 | Add GSI `buyerId-createdAt-index` | DynamoDB | PK: buyerId, SK: createdAt |
| 6 | Add GET /listings route | API Gateway | Integration → ListingsFunction, no auth |
| 7 | Add POST /purchase route | API Gateway | Integration → PurchaseFunction |
| 8 | Add GET /purchases route | API Gateway | Integration → PurchaseHistoryFunction |
| 9 | Create Cognito JWT Authorizer | API Gateway | Issuer: Cognito pool URL, Audience: app client ID |
| 10 | Attach authorizer to /purchase, /purchases | API Gateway | Also retrofit onto /grade, /ai-grade, /route |
| 11 | Grant Lambda DynamoDB permissions | IAM | dynamodb:Query, dynamodb:UpdateItem on Evaluations |
| 12 | Deploy API | API Gateway | Deploy to default stage |

### Flutter Code Changes

| # | File | Change |
|---|------|--------|
| 1 | `lib/data/session.dart` | Add `accessToken` and `idToken` fields |
| 2 | `lib/views/login_view.dart` | Hydrate Session after successful sign-in |
| 3 | `lib/data/repositories/grade_repository.dart` | Add `_headers` getter with Bearer token |
| 4 | Create `lib/data/repositories/buyer_repository.dart` | New file (code in Section 6) |
| 5 | `lib/MarketplaceTab.dart` | Replace mock data with `BuyerRepository.getListings()` |
| 6 | `lib/ListingDetailScreen.dart` | Accept listing map, show real health card data |
| 7 | `lib/PurchasesTab.dart` | Replace mock data with `BuyerRepository.getPurchases()` |

---

## 10. Security Considerations

| Concern | Mitigation |
|---------|------------|
| Users impersonating other users | Cognito JWT authorizer extracts `sub` claim server-side; ignore client-sent userId when authorizer is active |
| Double-purchase race condition | DynamoDB `ConditionExpression` on status ensures atomic reservation |
| Listing stale items | `/listings` only returns `status=ROUTED`; once purchased, status flips to SOLD and item disappears from next query |
| Price manipulation | `estimatedResaleValue` is computed server-side by AI; frontend cannot override it |
| Photo URL enumeration | S3 bucket uses UUID-based object keys; no sequential listing possible without authenticated API call |

---

## 11. Hackathon Shortcut Path (If Time-Constrained)

If deploying 3 new Lambdas and 2 GSIs is too time-consuming for demo day:

**Shortcut:** Reuse the existing `GET /evaluations` endpoint on the buyer side:

```dart
// In MarketplaceTab — fetch all evaluations, filter client-side:
final allEvals = await GradeRepository().listEvaluations();
final listings = allEvals.where((e) => 
  e['status'] == 'ROUTED' && 
  e['chosenDisposition'] == 'Resell'
).toList();
```

**Trade-offs:**
- ❌ No auth boundary between seller data and buyer view
- ❌ Client-side filtering means over-fetching
- ❌ No atomic purchase (just a visual demo)
- ✅ Zero backend changes required
- ✅ Works in 10 minutes

---

*Document prepared for AmazeLoop — Build for Tomorrow Hackathon. Extends the v1.0 Technical Architecture Document with buyer marketplace implementation details.*
