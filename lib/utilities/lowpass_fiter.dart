class LowPassFilter {
  final double alpha;
  double _filteredValue;

  LowPassFilter(this.alpha, {double initialValue = 0.0}) 
      : _filteredValue = initialValue;

  double apply(double rawNewValue) {
    _filteredValue = (alpha * rawNewValue) + ((1.0 - alpha) * _filteredValue);
    return _filteredValue;
  }
}