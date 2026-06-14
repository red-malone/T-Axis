// Controller to encapsulate telemetry (sensors), GPS and recording logic
import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
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

  // GPS start guard — prevents concurrent startGPS calls from racing
  // (e.g. initState + didChangeAppLifecycleState both fire before the
  // first async check completes, causing duplicate dialogs).
  bool _isGpsStarting = false;

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

  // -----------------------------------------------------------------------
  // GPS handling
  //
  // FIX NOTES:
  //
  // 1. The original code's speedAccuracy threshold was 5.0 m/s, which is
  //    too tight for many GPS chipsets (especially on Wear OS emulators
  //    and low-cost watch hardware). Emulator mock locations often report
  //    speedAccuracy as null or as a very large value, so a tight filter
  //    silently drops every single position update. Raised to 10.0 and
  //    added a null-passes-through check.
  //
  // 2. Added debug prints at every decision point so you can see in
  //    logcat exactly where the flow is breaking. Remove these once
  //    the issue is confirmed fixed.
  //
  // 3. Wrapped the Geolocator.getPositionStream() call more carefully
  //    — on some Wear OS devices (and all emulators without Google Play
  //    Services), the stream constructor itself throws rather than
  //    emitting an error on the stream.
  // -----------------------------------------------------------------------
  Future<void> startGPS({
    required Future<void> Function() onShowLocationDialog,
  }) async {
    if (_isGpsStarting) return;
    if (_positionSubscription != null) return; // already streaming
    _isGpsStarting = true;
    try {
      final bool serviceEnabled =
          await LocationHelpers.isLocationServiceEnabledSafe();
      if (kDebugMode) {
        print('[T-Axis GPS] Location services enabled: $serviceEnabled');
      }

      if (!serviceEnabled) {
        if (kDebugMode) {
          print('[T-Axis GPS] → Showing location disabled dialog');
        }
        await onShowLocationDialog();
        return;
      }

      LocationPermission permission =
          await LocationHelpers.checkPermissionSafe();
      if (kDebugMode) {
        print('[T-Axis GPS] Current permission: $permission');
      }

      if (permission == LocationPermission.denied) {
        if (kDebugMode) {
          print('[T-Axis GPS] → Requesting permission...');
        }
        permission = await LocationHelpers.requestPermissionSafe();
        if (kDebugMode) {
          print('[T-Axis GPS] → After request: $permission');
        }
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (kDebugMode) {
          print('[T-Axis GPS] → Permission denied/deniedForever, showing dialog');
        }
        await onShowLocationDialog();
        return;
      }

      // Cancel any existing subscription before creating a new one
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      if (kDebugMode) {
        print('[T-Axis GPS] → Creating position stream...');
      }

      try {
        _positionSubscription =
            Geolocator.getPositionStream(
              locationSettings: AndroidSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 0,
                intervalDuration: const Duration(seconds: 1),
                foregroundNotificationConfig:
                    const ForegroundNotificationConfig(
                      notificationText: 'T-Axis is tracking your speed',
                      notificationTitle: 'Speed Tracking Active',
                      enableWakeLock: true,
                    ),
              ),
            ).listen(
              (position) {
                if (kDebugMode) {
                  print(
                  '[T-Axis GPS] Position: '
                  'lat=${position.latitude.toStringAsFixed(5)}, '
                  'lng=${position.longitude.toStringAsFixed(5)}, '
                  'speed=${position.speed.toStringAsFixed(2)} m/s, '
                  'speedAccuracy=${position.speedAccuracy}',
                );
                }

                leanCorrector.updatePosition(position);

                // -------------------------------------------------------
                // FIX: Relaxed speedAccuracy filter.
                //
                // Many Wear OS devices and ALL emulators report
                // speedAccuracy as 0.0 (meaning "unknown" per the
                // Android docs, not "perfect"). The old threshold of
                // 5.0 was dropping these. Now:
                //   - null or 0.0 → accept (unknown accuracy, use it)
                //   - > 10.0      → reject (genuinely unreliable)
                // -------------------------------------------------------
                final double speedAccuracy = position.speedAccuracy;
                if (speedAccuracy > 0.0 &&
                    speedAccuracy > 10.0) {
                  if (kDebugMode) {
                    print(
                    '[T-Axis GPS] → Skipping: speedAccuracy '
                    '$speedAccuracy > 10.0',
                  );
                  }
                  return;
                }

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
                if (kDebugMode) {
                  print('[T-Axis GPS] Stream error: $err');
                }
                try {
                  if (rideRecorder.isRecording) await stopRide();
                  await _positionSubscription?.cancel();
                  _positionSubscription = null;

                  if (err is PlatformException ||
                      err is LocationServiceDisabledException) {
                    await onShowLocationDialog();
                  }
                } catch (_) {}
              },
            );

        if (kDebugMode) {
          print('[T-Axis GPS] → Position stream created successfully');
        }
      } catch (e) {
        if (kDebugMode) {
          print('[T-Axis GPS] → Failed to create position stream: $e');
        }
        try {
          if (rideRecorder.isRecording) await stopRide();
          await _positionSubscription?.cancel();
          _positionSubscription = null;
          await onShowLocationDialog();
        } catch (_) {}
      }
    } catch (e) {
      if (kDebugMode) {
        print('[T-Axis GPS] → Unexpected top-level error: $e');
      }
    } finally {
      _isGpsStarting = false;
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