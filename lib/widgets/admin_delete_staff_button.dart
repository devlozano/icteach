import 'package:flutter/material.dart';
import '../services/admin_staff_deletion.dart';

class AdminDeleteStaffButton extends StatelessWidget {
  const AdminDeleteStaffButton({
    super.key,
    required this.uid,
    required this.role,
    required this.name,
    this.onDelete,
  });
  final String uid, role, name;
  final Future<void> Function()? onDelete;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Delete account',
    icon: const Icon(Icons.delete_forever_outlined, color: Colors.red),
    onPressed: () => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DeleteStaffDialog(
        name: name,
        role: role,
        onDelete: onDelete ?? () => AdminStaffDeletion.delete(uid, role),
      ),
    ),
  );
}

class _DeleteStaffDialog extends StatefulWidget {
  const _DeleteStaffDialog({
    required this.name,
    required this.role,
    required this.onDelete,
  });
  final String name, role;
  final Future<void> Function() onDelete;
  @override
  State<_DeleteStaffDialog> createState() => _DeleteStaffDialogState();
}

class _DeleteStaffDialogState extends State<_DeleteStaffDialog> {
  bool busy = false;
  String? error;
  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onDelete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        setState(() {
          busy = false;
          error = e is StateError
              ? e.message.toString()
              : 'Deletion failed. Check your connection and retry.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Delete account'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Permanently delete ' +
                  widget.name +
                  ' (' +
                  widget.role +
                  ')? Their sign-in and profile will be removed. Shared classes and academic records will remain.',
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Deleting...' : 'Delete permanently'),
        ),
      ],
    ),
  );
}
