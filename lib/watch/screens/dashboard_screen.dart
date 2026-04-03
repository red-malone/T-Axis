// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:t_axis/core/models/mounting_mode.dart';
import 'package:t_axis/core/utilities/lean_corrector.dart';
import 'package:t_axis/watch/screens/watch_face/lean_face.dart';
import 'package:t_axis/watch/screens/watch_face/speed_face.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:t_axis/watch/controllers/ride_recorder.dart';
import 'package:t_axis/watch/controllers/max_speed_tracker.dart';

// NOTE: LowPassFilter has been removed entirely.
// The complementary filter below already acts as a low-pass filter on the
// accelerometer channel. A second filter on top would add lag with no benefit.

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Sensor subscriptions
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;

  // Complementary filter state
  double _currentAngle = 0.0;
  double _baselineOffset = 0.0;
  DateTime? _lastUpdate;

  // 96% gyro (fast response), 4% accel (drift correction)
  final double _alpha = 0.96;
  // Throttle UI updates from high-rate sensors to ~30Hz
  DateTime? _lastUiUpdate;

  // Written by accel stream, read by gyro stream.
  // Safe in Dart's single-threaded model.
  double _accelAngle = 0.0;

  // --- Mounting calibration ---
  MountingMode _mountingMode = MountingMode.leftWrist;

  // Only relevant for handlebar mode: user can flip the lean direction if
  // the watch is rotated 180° on the bar.
  bool _handlebarDirectionFlipped = false;

  // Speed state
  StreamSubscription<Position>? _positionSubscription;
  double _currentSpeedKmh = 0.0;
  final MaxSpeedTracker _speedTracker = MaxSpeedTracker();

  // Recording controller
  final RideRecorder _rideRecorder = RideRecorder();
  DateTime? _recordStartTime;
  Timer? _recordTimer;

  static const double _speedNoiseThresholdKmh = 1.5;
  // Allow somewhat looser speed accuracy: many devices report >1m/s.
  // Only reject updates when the platform actually reports a (non-null)
  // speedAccuracy value that exceeds this threshold.
  static const double _maxAcceptableSpeedAccuracy = 5.0;

  //Lean correction controller
  final LeanCorrector _leanCorrector = LeanCorrector();
  // Prevent repeatedly showing the 'location disabled' dialog
  bool _locationDialogShown = false;

  // -------------------------------------------------------------------------
  // Direction multiplier
  //
  // Left wrist  → atan2(x,y) gives the correct sign.
  // Right wrist → X-axis mirrors physically; flip sign to compensate.
  // Handlebar   → starts with no flip, but user may invert via UI if the
  //               watch is rotated 180° on the bar.
  // -------------------------------------------------------------------------
  double get _directionMultiplier {
    switch (_mountingMode) {
      case MountingMode.leftWrist:
        return 1.0;
      case MountingMode.rightWrist:
        return -1.0;
      case MountingMode.handlebar:
        return _handlebarDirectionFlipped ? -1.0 : 1.0;
    }
  }

  void _startRide() {
    setState(() {
      _rideRecorder.start();
      _speedTracker.reset();
      _currentSpeedKmh = 0.0;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride started — recording data')),
    );
  }

  Future<void> _stopRide() async {
    // Stop and persist via recorder
    setState(() {});
    try {
      await _rideRecorder.stop();
      // Clear HUD timer/state
      _recordTimer?.cancel();
      _recordTimer = null;
      _recordStartTime = null;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ride saved locally')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save ride: $e')));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTelemetry();
    _startGPS();
  }

  void _startTelemetry() {
    _accelSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      // Roll angle in the X-Y plane.
      // X = across the watch face, Y = along the arm toward fingers.
      _accelAngle = atan2(event.x, event.y) * (180 / pi);
    });

    _gyroSubscription = gyroscopeEventStream().listen((GyroscopeEvent event) {
      final now = DateTime.now();
      if (_lastUpdate == null) {
        _lastUpdate = now;
        return;
      }

      final dt = now.difference(_lastUpdate!).inMicroseconds / 1_000_000.0;
      _lastUpdate = now;

      // Guard: ignore first tick after sleep/resume to avoid angle spike
      if (dt <= 0 || dt > 0.5) return;

      final double gyroRate = event.y * (180 / pi);
      // Let the lean corrector observe the raw gyro rate at full fidelity.
      _leanCorrector.updateGyroRate(gyroRate);
      final double newAngle =
          _alpha * (_currentAngle + gyroRate * dt) +
          (1.0 - _alpha) * _accelAngle;

      // Always update internal angle (used by recorder), but only trigger
      // a Flutter rebuild at a throttled rate to avoid UI jank.
      _currentAngle = newAngle;

      // Let the recorder observe the display angle at full rate
      final double rawAngle =
          (_currentAngle - _baselineOffset) * _directionMultiplier;

      final double displayAngle;
      if (_mountingMode == MountingMode.handlebar) {
        // Handlebar = rigid coupling, no wrist correction needed
        displayAngle = rawAngle;
      } else {
        // Left/right wrist — apply GPS-learned correction
        displayAngle = _leanCorrector.correct(
          rawAngle,
          _currentSpeedKmh / 3.6, // convert to m/s
        );
      }
      _rideRecorder.recordAngle(displayAngle);

      // Throttle UI updates to ~30 Hz (33 ms)
      final nowUi = DateTime.now();
      if (_lastUiUpdate == null ||
          nowUi.difference(_lastUiUpdate!).inMilliseconds >= 33) {
        _lastUiUpdate = nowUi;
        if (mounted) setState(() {});
      }
    });
  }

  Future<void> _startGPS() async {
    try {
      bool serviceEnabled = false;
      try {
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      } on PlatformException catch (e) {
        if (e.code == 'LOCATION_SERVICES_DISABLED') {
          if (!_locationDialogShown) await _showLocationDisabledDialog();
          return;
        }
      }

      if (!serviceEnabled) {
        if (!_locationDialogShown) await _showLocationDisabledDialog();
        return;
      }

      // Services are enabled now — reset the dialog flag so it can appear
      // again in the future if services go off.
      _locationDialogShown = false;

      LocationPermission permission = LocationPermission.denied;
      try {
        permission = await Geolocator.checkPermission();
      } on PlatformException {
        // On some platforms, permission checks may fail if services are disabled.
        // Handle this gracefully by prompting for permissions anyway.
        permission = LocationPermission.denied;
      }

      if (permission == LocationPermission.denied) {
        try {
          permission = await Geolocator.requestPermission();
        } on PlatformException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
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
              (Position position) {
                _leanCorrector.updatePosition(position);
                final double? speedAccuracy = position.speedAccuracy;
                if (speedAccuracy != null &&
                    speedAccuracy > _maxAcceptableSpeedAccuracy) {
                  return;
                }

                double rawSpeed = position.speed;
                if (rawSpeed.isNaN || rawSpeed < 0) rawSpeed = 0.0;

                final double speedKmh = rawSpeed * 3.6;
                final double cleanSpeed = speedKmh < _speedNoiseThresholdKmh
                    ? 0.0
                    : speedKmh;

                _speedTracker.update(cleanSpeed);
                if (mounted) {
                  setState(() {
                    _currentSpeedKmh = _speedTracker.current;
                  });
                }

                _rideRecorder.recordPosition(position, cleanSpeed);
              },
              onError: (err) async {
                if (err is PlatformException &&
                    err.code == 'LOCATION_SERVICES_DISABLED') {
                  if (_rideRecorder.isRecording) await _stopRide();
                  if (!_locationDialogShown)
                    await _showLocationDisabledDialog();
                }
              },
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start GPS: $e')));
      }
    }
  }

  // Zero out the current angle — works the same regardless of mounting mode.
  void _calibrateZero() {
    setState(() => _baselineOffset = _currentAngle);
  }

  // Only available in handlebar mode: flips which side is "left" vs "right".
  void _flipHandlebarDirection() {
    setState(() => _handlebarDirectionFlipped = !_handlebarDirectionFlipped);
  }

  void _onMountingModeChanged(MountingMode mode) {
    setState(() {
      _mountingMode = mode;
      // Reset direction flip whenever the mode changes so there is no
      // stale flip from a previous handlebar session.
      _handlebarDirectionFlipped = false;
      // Also reset the angle baseline since the sensor axes now mean
      // something different.
      _baselineOffset = _currentAngle;
      //reset if mounting has changed
      _leanCorrector.resetCalibration();
    });
  }

  void _resetMaxSpeed() {
    setState(() => _speedTracker.reset());
  }

  void _toggleRecording() async {
    if (_rideRecorder.isRecording) {
      await _stopRide();
      // _stopRide clears timers/state
    } else {
      _startRide();
      _recordStartTime = DateTime.now();
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  Future<void> _showLocationDisabledDialog() async {
    if (!mounted) return;
    final maxHeight = MediaQuery.of(context).size.height * 0.6;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(8.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final bool narrow = constraints.maxWidth < 200;
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Location Services Disabled',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Location services are disabled. Enable them to record rides and receive speed updates.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        if (narrow) ...[
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Dismiss'),
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                              ),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await Geolocator.openLocationSettings();
                                // The settings call may return immediately; give the
                                // system a moment and re-check services. The
                                // lifecycle observer will also retry when the app is
                                // resumed, but this helps cover quick toggles.
                                await Future.delayed(
                                  const Duration(milliseconds: 500),
                                );
                                _startGPS();
                              },
                              child: const Text('Open Settings'),
                            ),
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Dismiss'),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () async {
                                  Navigator.of(context).pop();
                                  await Geolocator.openLocationSettings();
                                },
                                child: const Text('Open Settings'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _positionSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check GPS when the app returns to foreground — user may have
      // enabled location services in system settings.
      _startGPS();
    }
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
    // Apply baseline offset then direction multiplier.
    final double displayAngle =
        (_currentAngle - _baselineOffset) * _directionMultiplier;

    return WatchShape(
      builder: (context, shape, child) {
        return Scaffold(
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (int page) =>
                    setState(() => _currentPage = page),
                children: [
                  LeanFace(
                    displayAngle: displayAngle,
                    mountingMode: _mountingMode,
                    handlebarDirectionFlipped: _handlebarDirectionFlipped,
                    onCalibrate: _calibrateZero,
                    onMountingModeChanged: _onMountingModeChanged,
                    onFlipHandlebarDirection: _flipHandlebarDirection,
                    isRecording: _rideRecorder.isRecording,
                    recordingLabel:
                        _rideRecorder.isRecording && _recordStartTime != null
                        ? _formatDuration(
                            DateTime.now().difference(_recordStartTime!),
                          )
                        : 'REC',
                    onToggleRecording: _toggleRecording,
                  ),
                  SpeedFace(
                    currentSpeedKmh: _currentSpeedKmh,
                    maxSpeedKmh: _speedTracker.max,
                    onResetMax: _resetMaxSpeed,
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
              // HUD moved into LeanFace to avoid overlaying the face
            ],
          ),
        );
      },
    );
  }
}
