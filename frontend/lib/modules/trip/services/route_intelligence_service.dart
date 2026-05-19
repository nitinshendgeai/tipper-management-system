import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

class RouteCalculationResult {
  final String origin;
  final String destination;
  final double distanceKm;
  final int durationMin;
  final double estimatedDieselLitres;
  final String source; // "google_maps" | "formula_estimate"
  final String? rawDistanceText;
  final String? rawDurationText;

  const RouteCalculationResult({
    required this.origin,
    required this.destination,
    required this.distanceKm,
    required this.durationMin,
    required this.estimatedDieselLitres,
    required this.source,
    this.rawDistanceText,
    this.rawDurationText,
  });

  bool get isGoogleMaps => source == 'google_maps';

  factory RouteCalculationResult.fromJson(Map<String, dynamic> json) {
    return RouteCalculationResult(
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0.0,
      durationMin: json['duration_min'] as int? ?? 0,
      estimatedDieselLitres:
          (json['estimated_diesel_litres'] as num?)?.toDouble() ?? 0.0,
      source: json['source'] as String? ?? 'formula_estimate',
      rawDistanceText: json['raw_distance_text'] as String?,
      rawDurationText: json['raw_duration_text'] as String?,
    );
  }
}

/// Phase 6 (FE-006): migrated from raw Dio() to DioClient.instance.
class RouteIntelligenceService {
  Future<RouteCalculationResult> calculateRoute({
    required String origin,
    required String destination,
  }) async {
    // Route intelligence requires auth — backend enforces tenant isolation.
    final options = await DioClient.authOptions();
    final response = await DioClient.instance.post(
      '${ApiConstants.baseUrl}/route-intelligence/calculate',
      data: {'origin': origin, 'destination': destination, 'mode': 'driving'},
      options: options,
    );
    return RouteCalculationResult.fromJson(
      response.data as Map<String, dynamic>,
    );
  }
}
