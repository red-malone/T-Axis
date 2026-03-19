// lib/models/mounting_mode.dart
// Isolated enum so both DashboardScreen and LeanFace can import without
// a circular dependency.

enum MountingMode {
  leftWrist,   // Default. Standard sign.
  rightWrist,  // X-axis mirrors — sign flipped automatically.
  handlebar,   // Fixed mount: zero-offset + manual direction calibration.
}

extension MountingModeLabel on MountingMode {
  String get label {
    switch (this) {
      case MountingMode.leftWrist:  return 'Left wrist';
      case MountingMode.rightWrist: return 'Right wrist';
      case MountingMode.handlebar:  return 'Handlebar';
    }
  }
}