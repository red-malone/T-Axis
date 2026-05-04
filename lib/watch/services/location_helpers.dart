// Small helpers to reduce location-related logic in UI classes.
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

class LocationHelpers {
  /// Returns true if location services are enabled. Catches platform
  /// exceptions and maps them to `false` so callers can show UI.
  static Future<bool> isLocationServiceEnabledSafe() async {
    try {
      print('Checking if location services are enabled...');
      final bool isEnabled = await Geolocator.isLocationServiceEnabled();
      print('Location services are enabled: $isEnabled');
      return isEnabled;
    } on PlatformException catch (e) {
      if (e.code == 'LOCATION_SERVICES_DISABLED') {
        // Geolocator on Wear OS throws this instead of returning false
        // when location services are genuinely off. Treat it as disabled.
        print('isLocationServiceEnabled: services disabled (${e.code})');
        return false;
      }
      // Other platform errors (no GPS hardware, API unsupported on this
      // Wear OS build) — proceed optimistically; the stream will fail
      // naturally if GPS is truly unavailable.
      print('isLocationServiceEnabled threw ($e) — assuming enabled.');
      return true;
    } on Exception catch (e) {
      print('isLocationServiceEnabled threw ($e) — assuming enabled.');
      return true;
    }
  }

  /// Safely checks current permission; if the platform call fails, return
  /// `LocationPermission.denied` so callers can request permission.
  static Future<LocationPermission> checkPermissionSafe() async {
    try {
      return await Geolocator.checkPermission();
    } on Exception {
      return LocationPermission.denied;
    }
  }

  /// Safely requests permission; if the platform call fails, return
  /// `LocationPermission.denied`.
  static Future<LocationPermission> requestPermissionSafe() async {
    try {
      return await Geolocator.requestPermission();
    } on Exception {
      return LocationPermission.denied;
    }
  }
}
