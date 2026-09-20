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
    this.speedMps,
  });

  final String supplierId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime reportedAt;

  /// Raw device-reported ground speed, in meters/second. Null when the fix
  /// didn't include a speed reading. This is telemetry only — never used to
  /// predict an ETA or route (see prompt.md §40, explicitly out of scope).
  final double? speedMps;

  bool get isStale =>
      DateTime.now().difference(reportedAt) > AppConstants.supplierReportTtl;

  /// Below this, GPS speed is mostly noise (a stopped bus can jitter a
  /// fraction of a m/s), so the UI should treat it as "not moving" rather
  /// than showing a misleading near-zero speed.
  static const double _movingThresholdMps = 0.6;

  bool get hasReliableSpeed => (speedMps ?? 0) >= _movingThresholdMps;

  factory LocationReport.fromMap(String supplierId, Map<dynamic, dynamic> map) {
    return LocationReport(
      supplierId: supplierId,
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      reportedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['reportedAt'] as num?)?.toInt() ?? 0,
      ),
      speedMps: (map['speedMps'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'reportedAt': reportedAt.millisecondsSinceEpoch,
      if (speedMps != null) 'speedMps': speedMps,
    };
  }
}
