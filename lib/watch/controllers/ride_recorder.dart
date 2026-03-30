import 'package:geolocator/geolocator.dart';
import 'package:t_axis/core/utilities/db_helper.dart';

class RideRecorder {
  bool _isRecording = false;
  final List<Map<String, double>> _routeData = [];
  double _topSpeed = 0.0;
  double _maxLean = 0.0;

  bool get isRecording => _isRecording;
  double get topSpeed => _topSpeed;
  double get maxLean => _maxLean;
  List<Map<String, double>> get routeData => List.unmodifiable(_routeData);

  void start() {
    _isRecording = true;
    _routeData.clear();
    _topSpeed = 0.0;
    _maxLean = 0.0;
  }

  Future<void> stop() async {
    _isRecording = false;
    await DatabaseHelper.instance.insertRide(
      topSpeed: _topSpeed,
      maxLean: _maxLean,
      routeData: List<Map<String, double>>.from(_routeData),
    );
  }

  void recordAngle(double displayAngle) {
    if (!_isRecording) return;
    final double absAngle = displayAngle.abs();
    if (absAngle > _maxLean) _maxLean = absAngle;
  }

  void recordPosition(Position position, double cleanSpeed) {
    if (!_isRecording) return;
    _routeData.add({
      'lat': position.latitude,
      'lng': position.longitude,
      'speed': cleanSpeed,
    });
    if (cleanSpeed > _topSpeed) _topSpeed = cleanSpeed;
  }
}
