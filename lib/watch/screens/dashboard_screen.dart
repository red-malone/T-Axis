// lib/screens/dashboard_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:t_axis/core/models/mounting_mode.dart';
import 'package:t_axis/core/utilities/lean_corrector.dart';
import 'package:t_axis/watch/screens/watch_face/lean_face.dart';
import 'package:t_axis/watch/screens/watch_face/speed_face.dart';
import 'package:wear_plus/wear_plus.dart';
import 'package:t_axis/watch/controllers/ride_recorder.dart';
import 'package:t_axis/watch/controllers/max_speed_tracker.dart';
import 'package:t_axis/watch/controllers/dashboard_controller.dart';
import 'package:t_axis/watch/widgets/location_disabled_dialog.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // UI-visible state
  double _displayAngle = 0.0;
  double _currentSpeedKmh = 0.0;

  // Mounting calibration
  MountingMode _mountingMode = MountingMode.leftWrist;
  bool _handlebarDirectionFlipped = false;

  // Controllers / helpers
  final MaxSpeedTracker _speedTracker = MaxSpeedTracker();
  final RideRecorder _rideRecorder = RideRecorder();
  final LeanCorrector _leanCorrector = LeanCorrector();
  late final DashboardController _controller;

  // Recording HUD
  DateTime? _recordStartTime;
  Timer? _recordTimer;

  // Dialog guard
  bool _locationDialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _controller = DashboardController(
      leanCorrector: _leanCorrector,
      rideRecorder: _rideRecorder,
      speedTracker: _speedTracker,
      onDisplayAngle: (angle) {
        if (!mounted) return;
        setState(() => _displayAngle = angle);
      },
      onSpeedChanged: (speed) {
        if (!mounted) return;
        setState(() => _currentSpeedKmh = speed);
      },
    );

    // Configure controller based on initial mounting
    _controller.setApplyLeanCorrection(_mountingMode != MountingMode.handlebar);
    _controller.setDirectionMultiplier(_directionMultiplier);

    _controller.startTelemetry();
    _controller.startGPS(
      onShowLocationDialog: () async {
        if (!_locationDialogShown) {
          _locationDialogShown = true;
          await showLocationDisabledDialog(
            context,
            onOpenSettings: () async {
              _locationDialogShown = false;
              await _controller.startGPS(onShowLocationDialog: () async {});
            },
          );
        }
      },
    );
  }

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
    _controller.startRide();
    _recordStartTime = DateTime.now();
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride started — recording data')),
    );
  }

  Future<void> _stopRide() async {
    try {
      await _controller.stopRide();
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

  void _calibrateZero() => _controller.calibrateZero();

  void _flipHandlebarDirection() {
    setState(() => _handlebarDirectionFlipped = !_handlebarDirectionFlipped);
    _controller.setDirectionMultiplier(_directionMultiplier);
  }

  void _onMountingModeChanged(MountingMode mode) {
    setState(() {
      _mountingMode = mode;
      _handlebarDirectionFlipped = false;
      _leanCorrector.resetCalibration();
      _controller.setApplyLeanCorrection(mode != MountingMode.handlebar);
      _controller.setDirectionMultiplier(_directionMultiplier);
    });
  }

  void _resetMaxSpeed() => setState(() => _speedTracker.reset());

  void _toggleRecording() async {
    if (_controller.isRecording) {
      await _stopRide();
    } else {
      _startRide();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _pageController.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.startGPS(
        onShowLocationDialog: () async {
          if (!_locationDialogShown) {
            _locationDialogShown = true;
            await showLocationDisabledDialog(
              context,
              onOpenSettings: () async {
                _locationDialogShown = false;
                await _controller.startGPS(onShowLocationDialog: () async {});
              },
            );
          }
        },
      );
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
                    displayAngle: _displayAngle,
                    mountingMode: _mountingMode,
                    handlebarDirectionFlipped: _handlebarDirectionFlipped,
                    onCalibrate: _calibrateZero,
                    onMountingModeChanged: _onMountingModeChanged,
                    onFlipHandlebarDirection: _flipHandlebarDirection,
                    isRecording: _controller.isRecording,
                    recordingLabel:
                        _controller.isRecording && _recordStartTime != null
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
            ],
          ),
        );
      },
    );
  }
}
