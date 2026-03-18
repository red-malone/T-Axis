import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:t_axis/screens/faces/lean_face.dart';
import 'package:t_axis/screens/faces/speed_face.dart';
import 'package:t_axis/utilities/lowpass_fiter.dart';
import 'package:wear_plus/wear_plus.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  //Lean Angle State
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  final LowPassFilter _leanFilter = LowPassFilter(0.05);
  double _smoothedLean = 0.0;
  double _baselineOffset = 0.0;

  //Speed State
  StreamSubscription<Position>? _positionSubscription;
  double _currentSpeedKmh = 0.0;
  double _maxSpeedKmh = 0.0;

  @override
  void initState() {
    super.initState();
    _startTelemetry();
    _startGPS();
  }

  void _startTelemetry() {
    // Use Accelerometer for "proper" absolute angle instead of Gyroscope (which only measures speed).
    // We use the X-axis for left/right lean and atan2 to calculate the stable tilt angle.
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      // Calculate absolute tilt angle in degrees. 
      // event.x is the side-to-side axis on the watch face.
      double angle = atan2(event.x, sqrt(event.y * event.y + event.z * event.z)) * (180 / pi);
      
      setState(() {
        _smoothedLean = _leanFilter.apply(angle);
      });
    });
  }

  Future<void> _startGPS() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 1,
            ),
          ).listen((Position position) {
            double speedKmh = position.speed * 3.6;
            setState(() {
              _currentSpeedKmh = speedKmh;
              if (speedKmh > _maxSpeedKmh) {
                _maxSpeedKmh = speedKmh;
              }
            });
          });
    }
  }

  void _calibrateZero() {
    setState(() {
      _baselineOffset = _smoothedLean;
    });
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _positionSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }
  Widget _buildDot(int index) {
    return Container(
      height: 6,
      width: 6,
      decoration: BoxDecoration(
        color: _currentPage == index ? Colors.white : Colors.white38,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double displayAngle = _smoothedLean - _baselineOffset;
    return WatchShape(
      builder: (context, shape, child) {
        return Scaffold(
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  LeanFace(
                    displayAngle: displayAngle,
                    onCalibrate: _calibrateZero,
                  ),
                  SpeedFace(
                    currentSpeedKmh: _currentSpeedKmh,
                    maxSpeedKmh: _maxSpeedKmh,
                  ),
                  
                ],
              ),

              //Page Indicator
              Positioned(bottom: 10, left: 0, right: 0, child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildDot(0),
                  const SizedBox(width: 8),
                  _buildDot(1),
                ],
              )),
            ],
          ),
        );
      },
    );
  }
}
