import 'package:flutter/material.dart';

Future<bool> showSimulationExitDialog(
  BuildContext context, {
  required bool attemptInProgress,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: Color(0xFFB45309),
          size: 38,
        ),
        title: const Text('Leave Simulation?'),
        content: Text(
          attemptInProgress
              ? 'Your current attempt is still in progress. If you leave now, unsaved actions in this attempt will be lost.'
              : 'Return to the simulations list?',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continue'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB42318),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.exit_to_app_rounded),
            label: const Text('Leave Simulation'),
          ),
        ],
      ),
    ) ??
    false;
