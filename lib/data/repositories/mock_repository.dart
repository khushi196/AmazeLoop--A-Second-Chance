import '../models/app_models.dart';

abstract class AppRepository {
  Future<GradingResult> gradeItem(ItemPayload payload, List<dynamic> images);
}

class MockDataRepository implements AppRepository {
  @override
  Future<GradingResult> gradeItem(ItemPayload payload, List<dynamic> images) async {
    // Simulates a 2-second AWS Lambda/Vision AI processing time
    await Future.delayed(const Duration(seconds: 2));

    return GradingResult(
      condition: "Like New",
      estimatedValue: "₹2500 - ₹3000",
      confidenceScore: 0.98,
      routeAction: "Resell via Amazon (open box)",
      routeReasoning: "The device exhibits zero cosmetic defects and complete functionality. Bypassing refurbishment and routing directly to high-tier secondary markets will yield the highest margin.",
      healthCardId: "CERT-8842-X-99",
    );
  }
}