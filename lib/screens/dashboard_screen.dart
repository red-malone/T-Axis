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
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      double angle = atan2(event.x, sqrt(event.y * event.y + event.z * event.z)) * (180 / pi);
      setState(() {
        _smoothedLean = _leanFilter.apply(angle);
      });
    });
  }

  Future<void> _startGPS() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    } 

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0, // Receive updates as often as possible
        intervalDuration: Duration(seconds: 1), // 1 second interval is good for speedo
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationText: "T-Axis is tracking your speed",
          notificationTitle: "Speed Tracking Active",
          enableWakeLock: true,
        )
      ),
    ).listen((Position position) {
      // position.speed is in m/s, convert to km/h
      double speedKmh = position.speed * 3.6;
      if (speedKmh < 0) speedKmh = 0; // Sometimes GPS returns negative speed on error

      setState(() {
        _currentSpeedKmh = speedKmh;
        if (speedKmh > _maxSpeedKmh) {
          _maxSpeedKmh = speedKmh;
        }
      });
    });
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
