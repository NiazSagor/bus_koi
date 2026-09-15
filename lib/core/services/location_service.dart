import 'package:geolocator/geolocator.dart';

enum LocationPermissionResult { granted, deniedOnce, deniedForever, serviceDisabled }

/// Thin wrapper around geolocator so the rest of the app never talks to a
/// plugin directly. Keeps permission/service-availability handling in one
/// place.
class LocationService {
  Future<LocationPermissionResult> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return LocationPermissionResult.serviceDisabled;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult.deniedForever;
    }
    if (permission == LocationPermission.denied) {
      return LocationPermissionResult.deniedOnce;
    }
    return LocationPermissionResult.granted;
  }

  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Stream<Position> positionStream({required double distanceFilterMeters}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilterMeters.round(),
      ),
    );
  }
}
