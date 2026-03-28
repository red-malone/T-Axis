// ---------------------------------------------------------------------------
// Mounting calibration dialog
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/mounting_mode.dart';

class MountingDialog extends StatefulWidget {
  final MountingMode current;
  final bool handlebarDirectionFlipped;
  final ValueChanged<MountingMode> onModeSelected;
  final VoidCallback onFlipDirection;

  const MountingDialog({
    super.key,
    required this.current,
    required this.handlebarDirectionFlipped,
    required this.onModeSelected,
    required this.onFlipDirection,
  });

  @override
  State<MountingDialog> createState() => _MountingDialogState();
}

class _MountingDialogState extends State<MountingDialog> {
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