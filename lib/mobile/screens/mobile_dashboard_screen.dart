
import 'package:flutter/material.dart';
import 'package:t_axis/core/models/mounting_mode.dart';
import 'package:t_axis/core/utilities/lean_corrector.dart';
import 'package:t_axis/watch/screens/watch_face/lean_face.dart';
import 'package:t_axis/watch/screens/watch_face/speed_face.dart';
import 'package:t_axis/watch/controllers/ride_recorder.dart';
import 'package:t_axis/watch/controllers/max_speed_tracker.dart';
import 'package:t_axis/watch/controllers/dashboard_controller.dart';

class MobileDashboardScreen extends StatefulWidget {
  const MobileDashboardScreen({super.key});

  @override
  State<MobileDashboardScreen> createState() => _MobileDashboardScreenState();
}

class _MobileDashboardScreenState extends State<MobileDashboardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  double _displayAngle = 0.0;
  double _currentSpeedKmh = 0.0;

  // Mounting calibration
  MountingMode _mountingMode = MountingMode.leftWrist;
  bool _handlebarDirectionFlipped = false;

  // Controllers
  final MaxSpeedTracker _speedTracker = MaxSpeedTracker();
  final RideRecorder _rideRecorder = RideRecorder();
  final LeanCorrector _leanCorrector = LeanCorrector();
  late final DashboardController _controller;

  @override
  void initState() {
    super.initState();

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

    _controller.setApplyLeanCorrection(_mountingMode != MountingMode.handlebar);
    _controller.setDirectionMultiplier(_directionMultiplier);
    _controller.startTelemetry();
    _controller.startGPS(onShowLocationDialog: () async {});
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

  void _onMountingModeChanged(MountingMode mode) {
    setState(() {
      _mountingMode = mode;
      _handlebarDirectionFlipped = false;
      _leanCorrector.resetCalibration();
      _controller.setApplyLeanCorrection(mode != MountingMode.handlebar);
      _controller.setDirectionMultiplier(_directionMultiplier);
    });
  }

  void _flipHandlebarDirection() {
    setState(() => _handlebarDirectionFlipped = !_handlebarDirectionFlipped);
    _controller.setDirectionMultiplier(_directionMultiplier);
  }

  void _calibrateZero() => _controller.calibrateZero();

  void _resetMaxSpeed() => setState(() => _speedTracker.reset());

  void _toggleRecording() async {
    if (_controller.isRecording) {
      await _controller.stopRide();
    } else {
      _controller.startRide();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
    return Scaffold(
      appBar: AppBar(title: const Text('T-Axis Companion')),
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) => setState(() => _currentPage = page),
            children: [
              LeanFace(
                displayAngle: _displayAngle,
                mountingMode: _mountingMode,
                handlebarDirectionFlipped: _handlebarDirectionFlipped,
                onCalibrate: _calibrateZero,
                onMountingModeChanged: _onMountingModeChanged,
                onFlipHandlebarDirection: _flipHandlebarDirection,
                isRecording: _controller.isRecording,
                recordingLabel: _controller.isRecording ? 'REC' : 'REC',
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
  }
}
