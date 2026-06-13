import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/evaluation_input.dart';
import '../models/listing.dart';
import '../models/listing_detail.dart';
import '../models/purchase.dart';
import '../models/app_notification.dart';
import '../session.dart';

/// Talks to the real AmazeLoop backend (API Gateway).
class GradeRepository {
  static const String _baseUrl =
      'https://bu719hnik3.execute-api.ap-south-1.amazonaws.com';

  static const String _gradeUrl = '$_baseUrl/grade';
  static const String _aiGradeUrl = '$_baseUrl/ai-grade';
  static const String _uploadUrl = '$_baseUrl/upload-url';
  static const String _routeUrl = '$_baseUrl/route';
  static const String _routeConfirmUrl = '$_baseUrl/route/confirm';
  static const String _evaluationsUrl = '$_baseUrl/evaluations';
  static const String _listingsUrl = '$_baseUrl/listings';
  static const String _purchaseUrl = '$_baseUrl/purchase';
  static const String _purchasesUrl = '$_baseUrl/purchases';
  static const String _notificationsUrl = '$_baseUrl/notifications';

  /// Uploads a single image to S3 via a presigned URL and returns the public
  /// object URL (to be stored as a photoUrl on the evaluation).
  Future<String> uploadPhoto({
    required Uint8List bytes,
    required String fileName,
    String contentType = 'image/jpeg',
  }) async {
    // 1. Ask the backend for a presigned PUT URL
    final presignResp = await http.post(
      Uri.parse(_uploadUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'fileName': fileName, 'contentType': contentType}),
    );
    if (presignResp.statusCode < 200 || presignResp.statusCode >= 300) {
      throw Exception('Failed to get upload URL (${presignResp.statusCode}).');
    }
    final presign = jsonDecode(presignResp.body) as Map<String, dynamic>;
    final uploadUrl = presign['uploadUrl'] as String;
    final fileUrl = presign['fileUrl'] as String;

    // 2. PUT the bytes directly to S3
    final putResp = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (putResp.statusCode < 200 || putResp.statusCode >= 300) {
      throw Exception('Photo upload failed (${putResp.statusCode}).');
    }

    return fileUrl;
  }

  /// Submits an item for grading (price/order normalization) and returns the
  /// parsed EvaluationInput.
  Future<EvaluationInput> gradeItem({
    required String productName,
    required String category,
    required String reason,
    required String orderOrPrice,
    required String currentPincode,
    List<String> photoUrls = const [],
  }) async {
    final body = {
      'productName': productName,
      'category': category,
      'reason': reason,
      'orderOrPrice': orderOrPrice,
      'currentPincode': currentPincode,
      'photoUrls': photoUrls,
      'userId': Session.userId,
      'userRole': Session.role,
    };

    late http.Response response;
    try {
      response = await http.post(
        Uri.parse(_gradeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Unexpected response from server (${response.statusCode}).');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final input = decoded['evaluationInput'];
      if (input is Map<String, dynamic>) {
        return EvaluationInput.fromJson(input);
      }
      throw Exception('Malformed response: missing evaluationInput.');
    } else {
      final message = decoded['error']?.toString() ?? 'Grading failed (${response.statusCode}).';
      throw Exception(message);
    }
  }

  /// Runs the AI vision grading (Rekognition) for an evaluation and returns the
  /// derived condition + estimated resale value.
  Future<AiGradeResult> aiGrade(String evaluationId) async {
    late http.Response response;
    try {
      response = await http.post(
        Uri.parse(_aiGradeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'evaluationId': evaluationId}),
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Unexpected response from AI grading (${response.statusCode}).');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return AiGradeResult.fromJson(decoded);
    } else {
      final message = decoded['error']?.toString() ?? 'AI grading failed (${response.statusCode}).';
      throw Exception(message);
    }
  }

  /// Computes the routing decision (nearest warehouse, recommended route,
  /// final disposition, and a human-friendly reason).
  Future<RouteResult> route(String evaluationId) async {
    late http.Response response;
    try {
      response = await http.post(
        Uri.parse(_routeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'evaluationId': evaluationId}),
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Unexpected response from routing (${response.statusCode}).');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return RouteResult.fromJson(decoded);
    } else {
      final message = decoded['error']?.toString() ?? 'Routing failed (${response.statusCode}).';
      throw Exception(message);
    }
  }

  /// Confirms the user's chosen disposition (possibly an override).
  Future<bool> confirmRoute(String evaluationId, String chosenDisposition) async {
    late http.Response response;
    try {
      response = await http.post(
        Uri.parse(_routeConfirmUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'evaluationId': evaluationId, 'chosenDisposition': chosenDisposition}),
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Unexpected response from confirm (${response.statusCode}).');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded['isOverride'] == true;
    } else {
      final message = decoded['error']?.toString() ?? 'Confirm failed (${response.statusCode}).';
      throw Exception(message);
    }
  }

  /// Fetches the evaluation history for a userId (or warehouseId for seller view).
  Future<List<Map<String, dynamic>>> listEvaluations({String? userId, String? warehouseId, int limit = 20}) async {
    final params = <String, String>{'limit': '$limit'};
    if (userId != null) params['userId'] = userId;
    if (warehouseId != null) params['warehouseId'] = warehouseId;

    final uri = Uri.parse(_evaluationsUrl).replace(queryParameters: params);
    late http.Response response;
    try {
      response = await http.get(uri, headers: {'Content-Type': 'application/json'});
    } catch (e) {
      throw Exception('Network error: $e');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(decoded['evaluations'] ?? []);
    } else {
      throw Exception('Failed to load history (${response.statusCode}).');
    }
  }

  /// Fetches the public marketplace feed of items routed for resale.
  Future<List<Listing>> fetchListings({int limit = 50}) async {
    final uri = Uri.parse(_listingsUrl).replace(
      queryParameters: {'limit': '$limit'},
    );
    late http.Response response;
    try {
      response = await http.get(uri, headers: {'Content-Type': 'application/json'});
    } catch (e) {
      throw Exception('Network error: $e');
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = decoded['listings'] as List? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(Listing.fromJson)
          .toList();
    } else {
      throw Exception('Failed to load listings (${response.statusCode}).');
    }
  }

  /// Fetches the full detail (listing + images + health card) for a listing.
  Future<ListingDetail> fetchListingDetail(String listingId) async {
    final uri = Uri.parse('$_listingsUrl/${Uri.encodeComponent(listingId)}');
    late http.Response response;
    try {
      response = await http.get(uri, headers: {'Content-Type': 'application/json'});
    } catch (e) {
      throw Exception('Network error: $e');
    }

    if (response.statusCode == 404) {
      throw Exception('Listing not found.');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return ListingDetail.fromJson(decoded);
    }
    throw Exception('Failed to load listing detail (${response.statusCode}).');
  }

  /// Reserves or buys a listing for the authenticated buyer.
  /// [action] is "RESERVE" (24h hold) or "BUY" (complete purchase).
  /// Sends the Cognito ID token so API Gateway's authorizer identifies the
  /// buyer. Returns the parsed response body.
  Future<Map<String, dynamic>> purchaseListing(
    String evaluationId, {
    required String action,
  }) async {
    final token = Session.idToken;
    late http.Response response;
    try {
      response = await http.post(
        Uri.parse(_purchaseUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'evaluationId': evaluationId, 'action': action}),
      );
    } catch (e) {
      throw Exception('Network error: $e');
    }

    Map<String, dynamic> decoded = const {};
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      // Fall through — status code drives the result.
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }
    final message = decoded['error']?.toString() ??
        'Failed to ${action.toLowerCase()} listing (${response.statusCode}).';
    throw Exception(message);
  }

  /// Convenience: reserve (24h hold).
  Future<Map<String, dynamic>> reserveListing(String evaluationId) =>
      purchaseListing(evaluationId, action: 'RESERVE');

  /// Convenience: buy outright.
  Future<Map<String, dynamic>> buyListing(String evaluationId) =>
      purchaseListing(evaluationId, action: 'BUY');

  /// Fetches the authenticated buyer's items, optionally filtered by
  /// [status] ("SOLD" for My Purchases, "RESERVED" for the Reserved tab).
  Future<List<Purchase>> fetchPurchases({String? status, int limit = 50}) async {
    final token = Session.idToken;
    final uri = Uri.parse(_purchasesUrl).replace(
      queryParameters: {
        'limit': '$limit',
        if (status != null) 'status': status,
      },
    );
    late http.Response response;
    try {
      response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    } catch (e) {
      throw Exception('Network error: $e');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Sign in to view your items.');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = decoded['purchases'] as List? ?? const [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(Purchase.fromJson)
          .toList();
    }
    throw Exception('Failed to load items (${response.statusCode}).');
  }

  /// Fetches the authenticated user's in-app notifications.
  Future<NotificationsResult> fetchNotifications({int limit = 50}) async {
    final token = Session.idToken;
    final uri = Uri.parse(_notificationsUrl).replace(
      queryParameters: {'limit': '$limit'},
    );
    late http.Response response;
    try {
      response = await http.get(uri, headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      });
    } catch (e) {
      throw Exception('Network error: $e');
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('Sign in to view notifications.');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final items = decoded['notifications'] as List? ?? const [];
      return NotificationsResult(
        notifications: items
            .whereType<Map<String, dynamic>>()
            .map(AppNotification.fromJson)
            .toList(),
        unreadCount: (decoded['unreadCount'] as num?)?.toInt() ?? 0,
      );
    }
    throw Exception('Failed to load notifications (${response.statusCode}).');
  }
}

/// Result of the AI vision grading step.
class AiGradeResult {
  final String evaluationId;
  final String condition;
  final String conditionReason;
  final num estimatedResaleValue;
  final int? bestPhotoIndex;

  AiGradeResult({
    required this.evaluationId,
    required this.condition,
    required this.conditionReason,
    required this.estimatedResaleValue,
    this.bestPhotoIndex,
  });

  factory AiGradeResult.fromJson(Map<String, dynamic> json) {
    return AiGradeResult(
      evaluationId: json['evaluationId']?.toString() ?? '',
      condition: json['condition']?.toString() ?? 'Unknown',
      conditionReason: json['conditionReason']?.toString() ?? '',
      estimatedResaleValue: (json['estimatedResaleValue'] as num?) ?? 0,
      bestPhotoIndex: json['bestPhotoIndex'] as int?,
    );
  }
}

/// Result of the routing decision step.
class RouteResult {
  final String evaluationId;
  final String recommendedRoute;
  final String finalDisposition;
  final String routeReason;
  final num? distanceKm;
  final String? nearestWarehouseId;
  final String? sortingQueue;
  final String? priority;

  RouteResult({
    required this.evaluationId,
    required this.recommendedRoute,
    required this.finalDisposition,
    required this.routeReason,
    this.distanceKm,
    this.nearestWarehouseId,
    this.sortingQueue,
    this.priority,
  });

  factory RouteResult.fromJson(Map<String, dynamic> json) {
    return RouteResult(
      evaluationId: json['evaluationId']?.toString() ?? '',
      recommendedRoute: json['recommendedRoute']?.toString() ?? '',
      finalDisposition: json['finalDisposition']?.toString() ?? 'Refurbish',
      routeReason: json['routeReason']?.toString() ?? '',
      distanceKm: json['distanceKm'] as num?,
      nearestWarehouseId: json['nearestWarehouseId']?.toString(),
      sortingQueue: json['sortingQueue']?.toString(),
      priority: json['priority']?.toString(),
    );
  }
}
