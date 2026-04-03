import 'dart:math';
import 'package:geolocator/geolocator.dart';

/// Corrects wrist-mounted lean angle using GPS-derived lean as ground truth.
///
/// Strategy:
/// - At low speed (< 15 km/h): use raw IMU angle (GPS lean unreliable)
/// - At speed, in steady turn: compute physics-based lean from GPS, then
///   learn the wrist offset to apply as a correction factor
/// - During transients: use the last-known correction factor with raw IMU
/// The GPS-derived lean angle in a coordinated turn:
///   θ_true = atan(v² / (r × g))
/// where v = speed, r = turn radius, g = 9.81
class LeanCorrector {
  // --- Configuration ---
  static const double _g = 9.81;
  static const double _minSpeedForCorrection = 15.0 / 3.6; // 15 km/h in m/s
  static const double _minTurnRadiusM = 5.0; // ignore very tight turns (noise)
  static const double _maxTurnRadiusM = 500.0; // ignore near-straight (noise)
  static const double _steadyStateThreshold = 2.0; // deg/s — angular rate below this = steady

  // Exponential moving average weight for learning the correction offset.
  // Lower = smoother but slower to adapt. 0.05 works well for ~1 Hz GPS.
  static const double _emaAlpha = 0.05;

  // --- State ---
  double _correctionOffsetDeg = 0.0; // learned wrist articulation offset
  bool _hasLearnedOffset = false;

  // Circular buffer of recent GPS positions for radius estimation
  final List<_GpsPoint> _positionBuffer = [];
  static const int _bufferSize = 5; // ~5 seconds at 1 Hz GPS

  // Last gyro rate (deg/s) for steady-state detection
  double _lastGyroRateDegS = 0.0;

  /// The current learned correction offset in degrees.
  double get correctionOffset => _correctionOffsetDeg;
  bool get hasLearnedOffset => _hasLearnedOffset;

  /// Feed the current gyro Z-rate (deg/s) for steady-state detection.
  void updateGyroRate(double rateDegS) {
    _lastGyroRateDegS = rateDegS.abs();
  }

  /// Feed a GPS position. Call this at ~1 Hz from your position stream.
  void updatePosition(Position pos) {
    _positionBuffer.add(_GpsPoint(
      lat: pos.latitude,
      lng: pos.longitude,
      speedMs: pos.speed.isNaN || pos.speed < 0 ? 0.0 : pos.speed,
      timestampMs: pos.timestamp.millisecondsSinceEpoch,
    ));
    if (_positionBuffer.length > _bufferSize) {
      _positionBuffer.removeAt(0);
    }
  }

  /// Core method: correct the raw IMU lean angle.
  ///
  /// [rawImuDeg] — the display angle from your complementary filter
  /// [currentSpeedMs] — current GPS speed in m/s
  ///
  /// Returns the corrected lean angle in degrees.
  double correct(double rawImuDeg, double currentSpeedMs) {
    // At low speed, GPS-derived lean is unreliable — return raw with any
    // previously learned offset applied.
    if (currentSpeedMs < _minSpeedForCorrection) {
      return _hasLearnedOffset
          ? rawImuDeg - _correctionOffsetDeg
          : rawImuDeg;
    }

    // Attempt to compute GPS-derived lean angle
    final double? gpsLeanDeg = _computeGpsLean(currentSpeedMs);

    if (gpsLeanDeg != null && _isInSteadyTurn()) {
      // Learn the offset: difference between IMU reading and GPS truth
      final double observedOffset = rawImuDeg.abs() - gpsLeanDeg;

      if (_hasLearnedOffset) {
        // EMA update — smooth out noise
        _correctionOffsetDeg = _emaAlpha * observedOffset +
            (1 - _emaAlpha) * _correctionOffsetDeg;
      } else {
        // First observation — seed the value
        _correctionOffsetDeg = observedOffset;
        _hasLearnedOffset = true;
      }
    }

    // Apply correction: subtract the learned wrist offset
    if (_hasLearnedOffset) {
      final double sign = rawImuDeg >= 0 ? 1.0 : -1.0;
      final double correctedAbs = rawImuDeg.abs() - _correctionOffsetDeg;
      return sign * max(0.0, correctedAbs);
    }

    return rawImuDeg;
  }

  /// Compute the physics-based lean angle from GPS trajectory.
  /// Returns null if insufficient data or conditions not met.
  double? _computeGpsLean(double speedMs) {
    if (_positionBuffer.length < 3) return null;

    final double? radiusM = _estimateTurnRadius();
    if (radiusM == null) return null;
    if (radiusM < _minTurnRadiusM || radiusM > _maxTurnRadiusM) return null;

    // θ = atan(v² / (r × g))  — in degrees
    final double leanRad = atan(speedMs * speedMs / (radiusM * _g));
    return leanRad * (180.0 / pi);
  }

  /// Estimate turn radius from recent GPS positions using the circumradius
  /// of the triangle formed by three non-collinear points.
  double? _estimateTurnRadius() {
    if (_positionBuffer.length < 3) return null;

    // Use first, middle, and last points for best spread
    final p1 = _positionBuffer.first;
    final p2 = _positionBuffer[_positionBuffer.length ~/ 2];
    final p3 = _positionBuffer.last;

    // Convert to local meters (flat-earth approx, fine for ~100 m scale)
    final double latRef = p1.lat;
    final double lngRef = p1.lng;
    final double metersPerDegLat = 111320.0;
    final double metersPerDegLng =
        111320.0 * cos(latRef * pi / 180.0);

    final double x1 = 0, y1 = 0;
    final double x2 = (p2.lng - lngRef) * metersPerDegLng;
    final double y2 = (p2.lat - latRef) * metersPerDegLat;
    final double x3 = (p3.lng - lngRef) * metersPerDegLng;
    final double y3 = (p3.lat - latRef) * metersPerDegLat;

    // Circumradius of triangle: R = (a * b * c) / (4 * area)
    final double a = _dist(x1, y1, x2, y2);
    final double b = _dist(x2, y2, x3, y3);
    final double c = _dist(x3, y3, x1, y1);

    final double area = ((x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1)).abs() / 2.0;

    if (area < 0.5) return null; // Points are nearly collinear — going straight

    return (a * b * c) / (4.0 * area);
  }

  bool _isInSteadyTurn() {
    // Steady turn = gyro rate is low (not actively changing lean)
    // AND we have enough GPS history
    return _lastGyroRateDegS < _steadyStateThreshold &&
        _positionBuffer.length >= 3;
  }

  /// Reset learned offset (e.g., when switching mounting modes).
  void resetCalibration() {
    _correctionOffsetDeg = 0.0;
    _hasLearnedOffset = false;
    _positionBuffer.clear();
  }

  static double _dist(double x1, double y1, double x2, double y2) {
    return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1));
  }
}

class _GpsPoint {
  final double lat;
  final double lng;
  final double speedMs;
  final int timestampMs;

  _GpsPoint({
    required this.lat,
    required this.lng,
    required this.speedMs,
    required this.timestampMs,
  });
}