// Controller to encapsulate telemetry (sensors), GPS and recording logic
import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:t_axis/core/utilities/lean_corrector.dart';
import 'package:t_axis/watch/controllers/ride_recorder.dart';
import 'package:t_axis/watch/controllers/max_speed_tracker.dart';
import 'package:t_axis/watch/services/location_helpers.dart';

class DashboardController {
  final LeanCorrector leanCorrector;
  final RideRecorder rideRecorder;
  final MaxSpeedTracker speedTracker;

  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<Position>? _positionSubscription;

  double _currentAngle = 0.0;
  double _accelAngle = 0.0;
  double _baselineOffset = 0.0;
  DateTime? _lastUpdate;
  DateTime? _lastUiUpdate;
  double _currentSpeedKmh = 0.0;

  // Settings
  double directionMultiplier = 1.0;
  bool applyLeanCorrection = true;

  // Complementary filter alpha
  final double _alpha = 0.96;

  // Callbacks
  void Function(double displayAngle)? onDisplayAngle;
  void Function(double speedKmh)? onSpeedChanged;

  DashboardController({
    required this.leanCorrector,
    required this.rideRecorder,
    required this.speedTracker,
    this.onDisplayAngle,
    this.onSpeedChanged,
  });

  bool get isRecording => rideRecorder.isRecording;

  double get currentSpeed => _currentSpeedKmh;

  // Start sensor telemetry: accelerometer + gyroscope
  void startTelemetry() {
    _accelSubscription = accelerometerEventStream().listen((event) {
      _accelAngle = atan2(event.x, event.y) * (180 / pi);
    });

    _gyroSubscription = gyroscopeEventStream().listen((event) {
      final now = DateTime.now();
      if (_lastUpdate == null) {
        _lastUpdate = now;
        return;
      }

      final dt = now.difference(_lastUpdate!).inMicroseconds / 1_000_000.0;
      _lastUpdate = now;
      if (dt <= 0 || dt > 0.5) return;

      final double gyroRate = event.y * (180 / pi);
      leanCorrector.updateGyroRate(gyroRate);
      final double newAngle =
          _alpha * (_currentAngle + gyroRate * dt) +
          (1.0 - _alpha) * _accelAngle;
      _currentAngle = newAngle;

      final double rawAngle =
          (_currentAngle - _baselineOffset) * directionMultiplier;

      final double displayAngle = applyLeanCorrection
          ? leanCorrector.correct(rawAngle, _currentSpeedKmh / 3.6)
          : rawAngle;

      rideRecorder.recordAngle(displayAngle);

      final nowUi = DateTime.now();
      if (_lastUiUpdate == null ||
          nowUi.difference(_lastUiUpdate!).inMilliseconds >= 33) {
        _lastUiUpdate = nowUi;
        if (onDisplayAngle != null) onDisplayAngle!(displayAngle);
      }
    });
  }

  // GPS handling — delegates UI dialog prompts via the provided callback
  Future<void> startGPS({
    required Future<void> Function() onShowLocationDialog,
  }) async {
    try {
      final bool serviceEnabled =
          await LocationHelpers.isLocationServiceEnabledSafe();
      if (!serviceEnabled) {
        await onShowLocationDialog();
        return;
      }

      _positionSubscription =
          Geolocator.getPositionStream(
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
          ).listen(
            (position) {
              leanCorrector.updatePosition(position);
              final double? speedAccuracy = position.speedAccuracy;
              if (speedAccuracy != null && speedAccuracy > 5.0) return;

              double rawSpeed = position.speed;
              if (rawSpeed.isNaN || rawSpeed < 0) rawSpeed = 0.0;
              final double speedKmh = rawSpeed * 3.6;
              final double cleanSpeed = speedKmh < 1.5 ? 0.0 : speedKmh;

              speedTracker.update(cleanSpeed);
              _currentSpeedKmh = speedTracker.current;
              if (onSpeedChanged != null) onSpeedChanged!(_currentSpeedKmh);
              rideRecorder.recordPosition(position, cleanSpeed);
            },
            onError: (err) async {
              if (err is PlatformException &&
                  err.code == 'LOCATION_SERVICES_DISABLED') {
                if (rideRecorder.isRecording) await stopRide();
                await onShowLocationDialog();
              }
            },
          );
    } catch (_) {
      // swallow and let caller handle errors via UI if needed
    }
  }

  void startRide() {
    rideRecorder.start();
    speedTracker.reset();
    _currentSpeedKmh = 0.0;
  }

  Future<void> stopRide() async {
    await rideRecorder.stop();
  }

  void calibrateZero() {
    _baselineOffset = _currentAngle;
  }

  void setDirectionMultiplier(double m) => directionMultiplier = m;

  void setApplyLeanCorrection(bool v) => applyLeanCorrection = v;

  void dispose() {
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _positionSubscription?.cancel();
  }
}
