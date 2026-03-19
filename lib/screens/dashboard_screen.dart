import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:t_axis/screens/faces/lean_face.dart';
import 'package:t_axis/screens/faces/speed_face.dart';
import 'package:wear_plus/wear_plus.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // Telemetry state
  double _currentAngle = 0.0;
  double _baselineOffset = 0.0;
  DateTime? _lastUpdate;

  // Alpha: 0.96 → 96% gyro (fast response), 4% accelerometer (drift correction)
  final double _alpha = 0.96;

  // Speed state
  StreamSubscription<Position>? _positionSubscription;
  double _currentSpeedKmh = 0.0;
  double _maxSpeedKmh = 0.0;

  // Speed threshold below which we clamp to zero (removes GPS noise at standstill)
  static const double _speedNoiseThresholdKmh = 1.5;

  // Minimum GPS speed accuracy (m/s) to accept a speed reading
  static const double _maxAcceptableSpeedAccuracy = 1.0;

  // Smoothed accelerometer angle — written by accel stream, read by gyro stream.
  // Dart is single-threaded so no lock needed, but we keep it as a plain field
  // to make the intent clear.
  double _accelAngle = 0.0;

  @override
  void initState() {
    super.initState();
    _startTelemetry();
    _startGPS();
  }

  void _startTelemetry() {
    // --- Accelerometer: long-term gravity reference (drift correction) ---
    _accelSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      // BUG FIX: was atan2(x, z) which used the screen-depth axis.
      // For a watch on the wrist, lean (roll) is rotation in the X-Y plane:
      //   X = horizontal across the watch face (points right when face-up)
      //   Y = vertical along the arm (points toward fingers)
      // atan2(x, y) gives the roll angle away from vertical — exactly what we want.
      _accelAngle = atan2(event.x, event.y) * (180 / pi);
    });

    // --- Gyroscope: real-time rotation rate ---
    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      final now = DateTime.now();
      if (_lastUpdate == null) {
        _lastUpdate = now;
        return;
      }

      final dt = now.difference(_lastUpdate!).inMicroseconds / 1_000_000.0;
      _lastUpdate = now;

      // Guard against absurdly large dt (e.g. first real tick after a resume)
      if (dt <= 0 || dt > 0.5) return;

      // Y-axis rotation = lean left/right in portrait orientation on wrist
      final double gyroRate = event.y * (180 / pi);

      // COMPLEMENTARY FILTER:
      //   angle = α × (angle + gyro × dt)  ← fast, drifts over time
      //         + (1 - α) × accelAngle     ← slow, but drift-free
      final double newAngle =
          _alpha * (_currentAngle + gyroRate * dt) + (1.0 - _alpha) * _accelAngle;

      setState(() {
        _currentAngle = newAngle;
      });
    });
  }

  Future<void> _startGPS() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          intervalDuration: const Duration(seconds: 1),
          foregroundNotificationConfig: const ForegroundNotificationConfig(
            notificationText: 'T-Axis is tracking your speed',
            notificationTitle: 'Speed Tracking Active',
            enableWakeLock: true,
          ),
        ),
      ).listen((Position position) {
        // Reject fixes with poor speed accuracy (common when stationary or indoors)
        if (position.speedAccuracy > _maxAcceptableSpeedAccuracy) return;

        final double speedKmh = position.speed * 3.6;

        // Clamp values below noise threshold to zero so the display reads 0
        // when the bike is stopped, not 0.3–1.0 km/h of GPS jitter.
        final double cleanSpeed = speedKmh < _speedNoiseThresholdKmh ? 0 : speedKmh;

        setState(() {
          _currentSpeedKmh = cleanSpeed;
          if (cleanSpeed > _maxSpeedKmh) _maxSpeedKmh = cleanSpeed;
        });
      });
    }
  }

  void _calibrateZero() {
    setState(() {
      _baselineOffset = _currentAngle;
    });
  }

  /// Call this to reset the session's top speed (e.g. a long-press on SpeedFace)
  void _resetMaxSpeed() {
    setState(() {
      _maxSpeedKmh = 0.0;
    });
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _positionSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildDot(int index) {
    return Container(
      height: 6,
      width: 6,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.white : Colors.white38,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double displayAngle = _currentAngle - _baselineOffset;

    return WatchShape(
      builder: (context, shape, child) {
        return Scaffold(
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (int page) => setState(() => _currentPage = page),
                children: [
                  LeanFace(
                    displayAngle: displayAngle,
                    onCalibrate: _calibrateZero,
                  ),
                  SpeedFace(
                    currentSpeedKmh: _currentSpeedKmh,
                    maxSpeedKmh: _maxSpeedKmh,
                    onResetMax: _resetMaxSpeed, // wire this up in SpeedFace
                  ),
                ],
              ),
              Positioned(
                bottom: 15,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(2, _buildDot),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}