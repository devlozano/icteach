import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

Future<void> showPasswordResetDialog(
  BuildContext context, {
  String email = '',
}) => showDialog<void>(
  context: context,
  builder: (_) => PasswordResetDialog(initialEmail: email),
);

class PasswordResetDialog extends StatefulWidget {
  final String initialEmail;
  final Future<void> Function(String)? sendReset;
  const PasswordResetDialog({
    super.key,
    this.initialEmail = '',
    this.sendReset,
  });

  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  final _form = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final email = _email.text.trim();
      if (widget.sendReset != null) {
        await widget.sendReset!(email);
      } else {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      }
      if (mounted) setState(() => _sent = true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'user-not-found') {
        setState(() => _sent = true);
      } else {
        setState(
          () => _error = switch (e.code) {
            'invalid-email' => 'Enter a valid email address.',
            'too-many-requests' => 'Too many requests. Please try again later.',
            'network-request-failed' => 'Check your connection and try again.',
            _ => 'Unable to send the reset email. Please try again.',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to send the reset email. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(_sent ? 'Check your email' : 'Reset password'),
    content: SizedBox(
      width: 380,
      child: SingleChildScrollView(
        child: _sent
            ? Text(
                'If an account exists for ${_email.text.trim()}, you will receive a password reset link. Check your inbox and spam folder, open the link to choose a new password, then return here to sign in.',
              )
            : Form(
                key: _form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Enter the email used for your teacher, trainer, or student account. We will email a link to set a new password.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _email,
                      enabled: !_sending,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          ).hasMatch(value?.trim() ?? '')
                          ? null
                          : 'Enter a valid email address.',
                      onFieldSubmitted: (_) => _send(),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(_sent ? 'Done' : 'Cancel'),
      ),
      if (!_sent)
        FilledButton(
          onPressed: _sending ? null : _send,
          child: _sending
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send reset link'),
        ),
    ],
  );
}

class ResetPasswordTile extends StatelessWidget {
  final String email;
  const ResetPasswordTile({super.key, required this.email});

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.lock_reset),
      title: const Text('Reset password'),
      subtitle: const Text('Receive a secure reset link by email'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showPasswordResetDialog(context, email: email),
    ),
  );
}
