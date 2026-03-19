// lib/screens/faces/lean_face.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:t_axis/models/mounting_mode.dart';

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
      builder: (ctx) => _MountingDialog(
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

// ---------------------------------------------------------------------------
// Mounting calibration dialog
// ---------------------------------------------------------------------------

class _MountingDialog extends StatefulWidget {
  final MountingMode current;
  final bool handlebarDirectionFlipped;
  final ValueChanged<MountingMode> onModeSelected;
  final VoidCallback onFlipDirection;

  const _MountingDialog({
    required this.current,
    required this.handlebarDirectionFlipped,
    required this.onModeSelected,
    required this.onFlipDirection,
  });

  @override
  State<_MountingDialog> createState() => _MountingDialogState();
}

class _MountingDialogState extends State<_MountingDialog> {
  late bool _flipped;

  @override
  void initState() {
    super.initState();
    _flipped = widget.handlebarDirectionFlipped;
  }

  @override
  Widget build(BuildContext context) {
    // FIX 2: Constrain the dialog to 90% of the screen height so it never
    // overflows on a small round watch face (≈203px).
    // LayoutBuilder reads the actual available height at runtime, which is
    // more reliable than MediaQuery on Wear OS.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxH = constraints.maxHeight * 0.90;

        return Dialog(
          backgroundColor: Colors.grey[900],
          // Constrain width too — dialogs default to a wider Material width
          // which wastes horizontal space on a round watch face.
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Padding(
              padding: const EdgeInsets.all(12),
              // FIX 3: Make the dialog body scrollable so the Handlebar option
              // (the third button + flip toggle) is reachable without overflow.
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Mount type',
                      style: GoogleFonts.robotoMono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Mode buttons — reduced vertical padding so all three
                    // buttons fit without scrolling on a 203px screen.
                    ...MountingMode.values.map((mode) {
                      final bool selected = mode == widget.current;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => widget.onModeSelected(mode),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: selected
                                  ? Colors.blueAccent.withValues(alpha: 0.8)
                                  : Colors.white12,
                              shape: const StadiumBorder(),
                              // Smaller tap target: watch UI norms allow ~28px
                              minimumSize: const Size(0, 28),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              mode.label,
                              style: GoogleFonts.robotoMono(
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),

                    // Flip direction — only shown in handlebar mode
                    if (widget.current == MountingMode.handlebar) ...[
                      const Divider(color: Colors.white24, height: 12),
                      // Wrap the Row in a FittedBox to handle the 0.220px edge case
                      FittedBox(
                        fit: BoxFit.scaleDown, // Only scales down if it doesn't fit
                        child: SizedBox(
                          // Use constraints to ensure it doesn't exceed the dialog's width
                          width: constraints.maxWidth * 0.8,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // 1. Wrap text in Flexible to prevent it from pushing the switch off-screen
                              Flexible(
                                child: Text(
                                  'Flip direction',
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                              // 2. Replace Transform.scale with a constrained SizedBox
                              // Transform.scale changes visual size but NOT layout footprint.
                              // This was likely the cause of your 0.220px overflow.
                              SizedBox(
                                width: 33, // Fixed physical footprint
                                height: 24,
                                child: FittedBox(
                                  fit: BoxFit.contain,
                                  child: Switch(
                                    value: _flipped,
                                    activeThumbColor: Colors.blueAccent,
                                    onChanged: (_) {
                                      setState(() => _flipped = !_flipped);
                                      widget.onFlipDirection();
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Enable if LEFT / RIGHT\nare swapped.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.robotoMono(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}