// low_pass_filter.dart
/* This is an unused functionality of the app. Can be used to replace the existing lowpass
 filter which is the current angle in the dashboard screen
 If needed can be used when further scaling the application for further complex mathematical issues
*/

/// A simple exponential moving average (EMA) low-pass filter.
///
/// [alpha] controls the smoothing strength:
///   - 0.0 → output never changes (complete smoothing, infinite lag)
///   - 1.0 → output equals every raw input (no smoothing, no lag)
///   - Typical values: 0.1–0.3 for slow sensors, 0.5–0.8 for fast sensors
///
/// Must be in range (0.0, 1.0] exclusive of 0.
class LowPassFilter {
  final double alpha;
  double _filteredValue;

  LowPassFilter(this.alpha, {double initialValue = 0.0})
      : assert(alpha > 0.0 && alpha <= 1.0,
  'alpha must be in range (0.0, 1.0]'),
        _filteredValue = initialValue;

  /// Apply the filter to a new raw value and return the smoothed result.
  double apply(double rawNewValue) {
    _filteredValue = (alpha * rawNewValue) + ((1.0 - alpha) * _filteredValue);
    return _filteredValue;
  }

  /// Current smoothed value without applying a new input.
  double get value => _filteredValue;

  /// Reset the filter to a new baseline (e.g. after calibration).
  /// Without this you would need to construct an entirely new instance.
  void reset({double initialValue = 0.0}) {
    _filteredValue = initialValue;
  }
}