// Dialog shown when location services are disabled or permissions unavailable
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Shows a dialog informing the user that location services are disabled.
///
/// The [onOpenSettings] callback is invoked after the user chooses to open
/// system location settings. Caller can use it to re-check services.
Future<void> showLocationDisabledDialog(
  BuildContext context, {
  required Future<void> Function() onOpenSettings,
}) async {
  if (!Navigator.of(context).mounted) return;
  final maxHeight = MediaQuery.of(context).size.height * 0.6;
  await showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.all(8.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final bool narrow = constraints.maxWidth < 200;
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Location Services Disabled',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Location services are disabled. Enable them to record rides and receive speed updates.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 12),
                      if (narrow) ...[
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Dismiss'),
                          ),
                        ),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () async {
                              Navigator.of(context).pop();
                              await Geolocator.openLocationSettings();
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );
                              await onOpenSettings();
                            },
                            child: const Text('Open Settings'),
                          ),
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Dismiss'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.of(context).pop();
                                await Geolocator.openLocationSettings();
                                await Future.delayed(
                                  const Duration(milliseconds: 500),
                                );
                                await onOpenSettings();
                              },
                              child: const Text('Open Settings'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
