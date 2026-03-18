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

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Lean Angle',
            style: GoogleFonts.robotoMono(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '${displayAngle.abs().toStringAsFixed(1)}°',
            style: GoogleFonts.robotoMono(
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            displayAngle > 0.5
                ? "RIGHT"
                : (displayAngle < -0.5 ? "LEFT" : "CENTER"),
            style: GoogleFonts.robotoMono(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: displayAngle.abs() > 0.5
                  ? Colors.redAccent
                  : Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onCalibrate,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
              shape: const StadiumBorder(),
              minimumSize: const Size(100, 30)
            ),
            child: Text(
              "Calibrate",
              style: GoogleFonts.robotoMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
