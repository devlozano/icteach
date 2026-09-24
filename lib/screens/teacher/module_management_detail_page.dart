import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/module_model.dart';
import '../../services/module_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/module_access_panel.dart';
import '../../widgets/module_management_card.dart';
import 'create_module_page.dart';

class ModuleManagementDetailPage extends StatefulWidget {
  const ModuleManagementDetailPage({
    super.key,
    required this.classId,
    required this.className,
    required this.module,
    required this.modules,
  });
  final String classId, className;
  final ModuleModel module;
  final Stream<List<ModuleModel>> modules;
  @override
  State<ModuleManagementDetailPage> createState() =>
      _ModuleManagementDetailPageState();
}

class _ModuleManagementDetailPageState
    extends State<ModuleManagementDetailPage> {
  final ModuleService _moduleService = ModuleService();
  bool _busy = false;

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<List<ModuleModel>>(
    stream: widget.modules,
    initialData: [widget.module],
    builder: (context, snapshot) {
      final matches = (snapshot.data ?? []).where(
        (m) => m.id == widget.module.id,
      );
      if (snapshot.hasError || matches.isEmpty) {
        return Scaffold(
          appBar: AppBar(title: const Text('Module details')),
          body: Center(
            child: Text(
              snapshot.hasError
                  ? 'Unable to load this module. Go back and try again.'
                  : 'This module is no longer available.',
            ),
          ),
        );
      }
      final module = matches.first;
      return ModuleDetailView(
        module: module,
        busy: _busy,
        onEdit: () => _runAction(() => _editModule(module)),
        onDelete: () => _runAction(() => _deleteModule(module)),
        onTogglePublish: () => _runAction(() => _togglePublish(module)),
        onOpen: module.hasAttachment
            ? () => _openModule(module.attachmentUrl!)
            : null,
        onVideo: module.videoUrl?.isNotEmpty == true
            ? () => _openModule(module.videoUrl!)
            : null,
        activity: ModuleAccessPanel(
          classId: widget.classId,
          moduleId: module.id,
          title: module.title,
          initiallyExpanded: true,
        ),
      );
    },
  );
  Future<void> _editModule(ModuleModel module) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateModulePage(
          classId: widget.classId,
          className: widget.className,
          moduleToEdit: module, // Pass the module to edit
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Module updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteModule(ModuleModel module) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Module'),
        content: Text('Are you sure you want to delete "${module.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _moduleService.deleteModule(widget.classId, module.id);
        if (!mounted) return;
        Navigator.of(context).pop();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Module deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error deleting module: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePublish(ModuleModel module) async {
    try {
      await _moduleService.togglePublish(
        widget.classId,
        module.id,
        !module.isPublished,
      );
      if (!mounted) return;

      // ✅ Send notification if published
      if (!module.isPublished) {
        try {
          final notificationService = NotificationService();
          unawaited(
            notificationService.notifyNewModule(widget.classId, module.title),
          );
        } catch (e) {
          print('Error sending notification: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            module.isPublished ? 'Module unpublished' : '✅ Module published!',
          ),
          backgroundColor: module.isPublished ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openModule(String fileUrl) async {
    final uri = Uri.parse(fileUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Unable to open the file.')));
    }
  }
}

class ModuleDetailView extends StatelessWidget {
  const ModuleDetailView({
    super.key,
    required this.module,
    required this.activity,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublish,
    this.onOpen,
    this.onVideo,
    this.busy = false,
  });
  final ModuleModel module;
  final Widget activity;
  final VoidCallback onEdit, onDelete, onTogglePublish;
  final VoidCallback? onOpen, onVideo;
  final bool busy;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF8FAFC),
    appBar: AppBar(
      title: const Text('Module details'),
      backgroundColor: const Color(0xFF0B2B4A),
      foregroundColor: Colors.white,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (busy) const LinearProgressIndicator(),
              AbsorbPointer(
                absorbing: busy,
                child: ModuleManagementCard(
                  module: module,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onTogglePublish: onTogglePublish,
                  onOpen: onOpen,
                ),
              ),
              if (module.content.trim().isNotEmpty) ...[
                Card(
                  elevation: 0,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lesson content',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          module.content,
                          style: const TextStyle(height: 1.6),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (onVideo != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onVideo,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Open lesson video'),
                  ),
                ),
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                child: activity,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
