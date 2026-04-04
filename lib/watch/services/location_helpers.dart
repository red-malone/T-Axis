// Small helpers to reduce location-related logic in UI classes.
import 'package:geolocator/geolocator.dart';

class LocationHelpers {
  /// Returns true if location services are enabled. Catches platform
  /// exceptions and maps them to `false` so callers can show UI.
  static Future<bool> isLocationServiceEnabledSafe() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    } on Exception {
      return false;
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
