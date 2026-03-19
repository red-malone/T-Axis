// speed_face.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SpeedFace extends StatelessWidget {
  final double currentSpeedKmh;
  final double maxSpeedKmh;

  /// Optional: long-press the Max pill to reset the session top speed.
  final VoidCallback? onResetMax;

  const SpeedFace({
    super.key,
    required this.currentSpeedKmh,
    required this.maxSpeedKmh,
    this.onResetMax,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Label
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Live Speed',
              style: GoogleFonts.robotoMono(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 4),

          // Current speed — FittedBox handles small screens; don't also set
          // overflow/maxLines here since FittedBox and ellipsis fight each other.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${currentSpeedKmh.toStringAsFixed(1)} km/h',
              style: GoogleFonts.robotoMono(
                fontSize: 42,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Max speed pill — long-press to reset
          GestureDetector(
            onLongPress: onResetMax,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Max: ${maxSpeedKmh.toStringAsFixed(1)} km/h',
                  style: GoogleFonts.robotoMono(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // Hint text so the user knows long-press exists (only if callback is wired)
          if (onResetMax != null) ...[
            const SizedBox(height: 6),
            Text(
              'Hold to reset max',
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                color: Colors.white38,
              ),
            ),
          ],
        ],
      ),
    );
  }
}