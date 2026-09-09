import '../../widgets/summary_print_button.dart';
import '../../services/class_summary_service.dart';
import '../../widgets/module_access_panel.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/module_model.dart';
import '../../services/module_service.dart';
import '../../services/notification_service.dart';
import 'content_lock_manager.dart';
import 'create_module_page.dart';
import 'learning_path_manager.dart';

class ManageModulesPage extends StatefulWidget {
  final String classId;
  final String className;

  const ManageModulesPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ManageModulesPage> createState() => _ManageModulesPageState();
}

class _ManageModulesPageState extends State<ManageModulesPage> {
  final ModuleService _moduleService = ModuleService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        title: Text('Modules - ${widget.className}'),
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          SummaryPrintButton(
            title: 'Class summary - ${widget.className}',
            load: () => ClassSummaryService.load(widget.classId),
          ),
          IconButton(
            icon: const Icon(Icons.account_tree),
            tooltip: 'Lesson & assessment links',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => LearningPathManager(classId: widget.classId),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContentLockManager(classId: widget.classId),
                ),
              );
            },
            icon: const Icon(Icons.lock_clock),
            tooltip: 'Content Lock Settings',
          ),
          IconButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateModulePage(
                    classId: widget.classId,
                    className: widget.className,
                  ),
                ),
              );
              if (result == true && mounted) {
                setState(() {});
              }
            },
            icon: const Icon(Icons.add),
            tooltip: 'Add Module',
          ),
        ],
      ),
      body: StreamBuilder<List<ModuleModel>>(
        stream: _moduleService.getModulesForClass(widget.classId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final modules = snapshot.data ?? [];

          if (modules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.menu_book_outlined,
                    size: 64,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No modules yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first module',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateModulePage(
                            classId: widget.classId,
                            className: widget.className,
                          ),
                        ),
                      );
                      if (result == true && mounted) {
                        setState(() {});
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Create Module'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B2B4A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final module = modules[index];
              return Column(
                children: [
                  _ModuleCard(
                    module: module,
                    onEdit: () => _editModule(module),
                    onDelete: () => _deleteModule(module),
                    onTogglePublish: () => _togglePublish(module),
                    onOpen: module.hasAttachment
                        ? () => _openModule(module.attachmentUrl!)
                        : null,
                  ),
                  ModuleAccessPanel(
                    classId: widget.classId,
                    moduleId: module.id,
                    title: module.title,
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateModulePage(
                classId: widget.classId,
                className: widget.className,
              ),
            ),
          );
          if (result == true && mounted) {
            setState(() {});
          }
        },
        backgroundColor: const Color(0xFF0B2B4A),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  // ✅ FIXED: Edit Module with full functionality
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Module deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
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
          await notificationService.notifyNewModule(
            widget.classId,
            module.title,
          );
        } catch (e) {
          print('Error sending notification: $e');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            module.isPublished
                ? 'Module unpublished'
                : '✅ Module published and notifications sent!',
          ),
          backgroundColor: module.isPublished ? Colors.orange : Colors.green,
        ),
      );
    } catch (e) {
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

// ✅ FIXED: Module Card with overflow fixes
class _ModuleCard extends StatelessWidget {
  final ModuleModel module;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePublish;
  final VoidCallback? onOpen;

  const _ModuleCard({
    required this.module,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePublish,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ FIXED: Row with Flexible to prevent overflow
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0B2B4A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${module.order + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B2B4A),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            module.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: module.isPublished
                                ? Colors.green.shade100
                                : Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            module.isPublished ? 'Published' : 'Draft',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: module.isPublished
                                  ? Colors.green.shade800
                                  : Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (module.description.isNotEmpty)
                      Text(
                        module.description,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (module.hasAttachment) ...[
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: onOpen,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 16,
                                color: Color(0xFF2F80ED),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  module.fileName ?? 'Open module attachment',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF2F80ED),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.open_in_new,
                                size: 14,
                                color: Color(0xFF2F80ED),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (module.competencies.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: module.competencies.map((comp) {
                final shortName = comp.split(':')[0];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    shortName,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.blue.shade800,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 10),
          // ✅ FIXED: Action buttons with proper spacing
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (module.isPublished)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 12,
                        color: Colors.green.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Notified',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              IconButton(
                onPressed: onTogglePublish,
                icon: Icon(
                  module.isPublished ? Icons.visibility : Icons.visibility_off,
                  size: 18,
                  color: module.isPublished ? Colors.green : Colors.grey,
                ),
                tooltip: module.isPublished ? 'Unpublish' : 'Publish',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Delete',
                color: Colors.red,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
