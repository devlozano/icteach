import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeleteTrainerAccountDialog extends StatefulWidget {
  const DeleteTrainerAccountDialog({super.key, required this.onDelete});
  final Future<void> Function(String) onDelete;
  @override
  State<DeleteTrainerAccountDialog> createState() =>
      _DeleteTrainerAccountDialogState();
}

class _DeleteTrainerAccountDialogState
    extends State<DeleteTrainerAccountDialog> {
  final password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    if (password.text.isEmpty) {
      setState(() => error = 'Enter your current password.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onDelete(password.text);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error =
            e is FirebaseAuthException &&
                [
                  'wrong-password',
                  'invalid-credential',
                  'invalid-login-credentials',
                ].contains(e.code)
            ? 'Incorrect password. Please try again.'
            : e is StateError
            ? e.message.toString()
            : 'Could not delete your account. Check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Delete Account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Permanently delete your trainer sign-in account and profile? You will lose access. Shared class and assessment records will remain.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              obscureText: true,
              enabled: !busy,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Current password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => submit(),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
          child: Text(busy ? 'Deleting...' : 'Delete permanently'),
        ),
      ],
    ),
  );
}
