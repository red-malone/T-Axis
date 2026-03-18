import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SpeedFace extends StatelessWidget {
  final double currentSpeedKmh;
  final double maxSpeedKmh;
  const SpeedFace({super.key, required this.currentSpeedKmh, required this.maxSpeedKmh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("Live Speed",style: GoogleFonts.robotoMono(fontSize: 18, fontWeight: FontWeight.bold),),
          Text("${currentSpeedKmh.toStringAsFixed(1)} km/h",style: GoogleFonts.robotoMono(fontSize: 42, fontWeight: FontWeight.bold),),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20)
            ),
            child: Text(
              "Max: ${maxSpeedKmh.toStringAsFixed(1)} km/h",
              style: GoogleFonts.robotoMono(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          )
        ],
      ),
    );
  }
}