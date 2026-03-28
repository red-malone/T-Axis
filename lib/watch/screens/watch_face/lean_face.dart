// lib/screens/faces/lean_face.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:t_axis/core/models/mounting_mode.dart';

import '../../widgets/mounting_dialog.dart';

class LeanFace extends StatelessWidget {
  final double displayAngle;
  final MountingMode mountingMode;
  final bool handlebarDirectionFlipped;
  final VoidCallback onCalibrate;
  final ValueChanged<MountingMode> onMountingModeChanged;
  final VoidCallback onFlipHandlebarDirection;

  static const double _deadZone = 0.5;

  const LeanFace({
    super.key,
    required this.displayAngle,
    required this.mountingMode,
    required this.handlebarDirectionFlipped,
    required this.onCalibrate,
    required this.onMountingModeChanged,
    required this.onFlipHandlebarDirection,
  });

  void _showMountingDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => MountingDialog(
        current: mountingMode,
        handlebarDirectionFlipped: handlebarDirectionFlipped,
        onModeSelected: (mode) {
          onMountingModeChanged(mode);
          Navigator.of(ctx).pop();
        },
        onFlipDirection: onFlipHandlebarDirection,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLeaning = displayAngle.abs() > _deadZone;
    final bool isRight = displayAngle > _deadZone;

    return Center(
      // FIX 1: Wrap in SingleChildScrollView so the column never hard-clips.
      // On the ~203px watch face the content fits without scrolling in normal
      // use — this is purely a safety net for the 2.7px edge case.
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min, // shrink-wrap: don't force max height
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Lean Angle',
                style: GoogleFonts.robotoMono(
                  fontSize: 16, // was 18 — shaved 2px to help the tight layout
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${displayAngle.abs().toStringAsFixed(1)}°',
                style: GoogleFonts.robotoMono(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isLeaning ? (isRight ? 'RIGHT' : 'LEFT') : 'CENTER',
                style: GoogleFonts.robotoMono(
                  fontSize: 16, // was 18
                  fontWeight: FontWeight.w500,
                  color: isLeaning ? Colors.redAccent : Colors.greenAccent,
                ),
              ),
            ),

            const SizedBox(height: 6), // was 12 — key contributor to overflow

            // Mounting mode badge
            GestureDetector(
              onTap: () => _showMountingDialog(context),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  mountingMode.label,
                  style: GoogleFonts.robotoMono(
                    fontSize: 11,
                    color: Colors.white60,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 6), // was 10

            ElevatedButton(
              onPressed: onCalibrate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                shape: const StadiumBorder(),
                minimumSize: const Size(90, 28), // was Size(100,30)
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text(
                'Calibrate',
                style: GoogleFonts.robotoMono(
                  fontSize: 13, // was 14
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

