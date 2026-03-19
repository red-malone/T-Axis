// lean_face.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LeanFace extends StatelessWidget {
  final double displayAngle;
  final VoidCallback onCalibrate;

  const LeanFace({
    super.key,
    required this.displayAngle,
    required this.onCalibrate,
  });

  // Dead-zone: angles within ±0.5° are considered upright
  static const double _deadZone = 0.5;

  @override
  Widget build(BuildContext context) {
    final bool isLeaning = displayAngle.abs() > _deadZone;
    final bool isRight = displayAngle > _deadZone;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Label — FittedBox added for consistency with SpeedFace
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Lean Angle',
              style: GoogleFonts.robotoMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Angle value — was missing FittedBox; 42px will overflow on small
          // round watch faces without it
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

          // Direction label
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              isLeaning ? (isRight ? 'RIGHT' : 'LEFT') : 'CENTER',
              style: GoogleFonts.robotoMono(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isLeaning ? Colors.redAccent : Colors.greenAccent,
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Calibrate button — reduced fontSize from 18 to 14 so the text
          // actually fits inside the minimumSize: Size(100, 30) button
          ElevatedButton(
            onPressed: onCalibrate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
              shape: const StadiumBorder(),
              minimumSize: const Size(100, 30),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(
              'Calibrate',
              style: GoogleFonts.robotoMono(
                fontSize: 14, // was 18 — too tall for a 30px-min button
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}