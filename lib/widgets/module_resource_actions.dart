import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/module_model.dart';
import '../services/module_access_service.dart';

class ModuleResourceActions extends StatefulWidget {
  final String classId;
  final ModuleModel module;
  const ModuleResourceActions({
    super.key,
    required this.classId,
    required this.module,
  });
  @override
  State<ModuleResourceActions> createState() => _ModuleResourceActionsState();
}

class _ModuleResourceActionsState extends State<ModuleResourceActions> {
  bool busy = false;
  Future<void> _run(bool download) async {
    setState(() => busy = true);
    try {
      if (download) {
        final message = await ModuleAccessService.download(
          widget.classId,
          widget.module,
        );
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
      } else {
        final opened = await launchUrl(
          Uri.parse(widget.module.attachmentUrl!),
          mode: LaunchMode.externalApplication,
        );
        if (!opened) throw StateError('Unable to open resource.');
        await ModuleAccessService.resourceOpened(widget.classId, widget.module);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Resource action failed: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.module.fileName ?? 'Module resource',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              OutlinedButton.icon(
                onPressed: busy ? null : () => _run(false),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open resource'),
              ),
              FilledButton.icon(
                onPressed: busy ? null : () => _run(true),
                icon: const Icon(Icons.download_outlined),
                label: Text(busy ? 'Please wait…' : 'Download module'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
