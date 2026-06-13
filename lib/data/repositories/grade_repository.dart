import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/evaluation_input.dart';
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
}

/// Result of the AI vision grading step.
class AiGradeResult {
  final String evaluationId;
  final String condition;
  final String conditionReason;
  final num estimatedResaleValue;

  AiGradeResult({
    required this.evaluationId,
    required this.condition,
    required this.conditionReason,
    required this.estimatedResaleValue,
  });

  factory AiGradeResult.fromJson(Map<String, dynamic> json) {
    return AiGradeResult(
      evaluationId: json['evaluationId']?.toString() ?? '',
      condition: json['condition']?.toString() ?? 'Unknown',
      conditionReason: json['conditionReason']?.toString() ?? '',
      estimatedResaleValue: (json['estimatedResaleValue'] as num?) ?? 0,
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
