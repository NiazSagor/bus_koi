import 'package:bus_koi/core/constants/app_constants.dart';

/// The latest reported position from one passenger currently riding the
/// bus. Only the latest report per supplier is kept — no movement history.
class LocationReport {
  const LocationReport({
    required this.supplierId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.reportedAt,
  });

  final String supplierId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime reportedAt;

  bool get isStale =>
      DateTime.now().difference(reportedAt) > AppConstants.supplierReportTtl;

  factory LocationReport.fromMap(String supplierId, Map<dynamic, dynamic> map) {
    return LocationReport(
      supplierId: supplierId,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      reportedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['reportedAt'] as num?)?.toInt() ?? 0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'reportedAt': reportedAt.millisecondsSinceEpoch,
    };
  }
}
