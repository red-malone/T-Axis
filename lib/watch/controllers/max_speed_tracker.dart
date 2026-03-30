class MaxSpeedTracker {
  double _current = 0.0;
  double _max = 0.0;

  double get current => _current;
  double get max => _max;

  void update(double speedKmh) {
    _current = speedKmh;
    if (speedKmh > _max) _max = speedKmh;
  }

  void reset() {
    _max = 0.0;
  }
}
