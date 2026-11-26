import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/interactive_quizzes.dart';
import '../../models/module_model.dart';
import '../../models/quiz_model.dart';
import '../../services/module_service.dart';
import '../../services/notification_service.dart';
import '../../services/learning_path_service.dart';
import '../../services/quiz_service.dart';
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
        quizLinks: _ModuleQuizLinksPanel(
          classId: widget.classId,
          module: module,
          modules: snapshot.data ?? [module],
        ),
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
            content: Text(LearningPathService.contentError(e)),
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
        SnackBar(
          content: Text(LearningPathService.contentError(e)),
          backgroundColor: Colors.red,
        ),
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
    this.quizLinks,
    this.busy = false,
  });
  final ModuleModel module;
  final Widget activity;
  final VoidCallback onEdit, onDelete, onTogglePublish;
  final VoidCallback? onOpen, onVideo;
  final Widget? quizLinks;
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
              if (quizLinks != null) ...[
                const SizedBox(height: 12),
                quizLinks!,
              ],
              const SizedBox(height: 12),
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

class _ModuleQuizLinksPanel extends StatefulWidget {
  const _ModuleQuizLinksPanel({
    required this.classId,
    required this.module,
    required this.modules,
  });

  final String classId;
  final ModuleModel module;
  final List<ModuleModel> modules;

  @override
  State<_ModuleQuizLinksPanel> createState() => _ModuleQuizLinksPanelState();
}

class _ModuleQuizLinksPanelState extends State<_ModuleQuizLinksPanel> {
  final QuizService _quizService = QuizService();
  String? _savingQuizId;

  Future<void> _setLink(QuizModel quiz, bool link) async {
    if (_savingQuizId != null) return;
    setState(() => _savingQuizId = quiz.id);
    try {
      await LearningPathService.setQuizModule(
        classId: widget.classId,
        quizId: quiz.id,
        moduleId: link ? widget.module.id : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            link
                ? '"${quiz.title}" linked to this module.'
                : '"${quiz.title}" unlinked from this module.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LearningPathService.contentError(error)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingQuizId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE2E8F0)),
    ),
    clipBehavior: Clip.antiAlias,
    child: Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: ValueKey('linked-quizzes-${widget.module.id}'),
        initiallyExpanded: false,
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        iconColor: const Color(0xFF2563EB),
        collapsedIconColor: const Color(0xFF64748B),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.link_rounded, color: Color(0xFF2563EB)),
        ),
        title: const Text(
          'Linked quizzes',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          widget.module.isPublished
              ? 'Show or hide quizzes linked to this module'
              : 'Publish this module before linking quizzes',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.module.isPublished
                  ? 'Choose the quizzes students take after completing this module.'
                  : 'Publish this module before linking quizzes.',
              style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<List<QuizModel>>(
            stream: _quizService.getQuizzesForClass(widget.classId),
            builder: (context, quizzesSnapshot) {
              if (quizzesSnapshot.hasError) {
                return const _LinkNotice(
                  icon: Icons.cloud_off_outlined,
                  text: 'Unable to load quizzes. Reopen this module to retry.',
                );
              }
              if (!quizzesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final quizzes = quizzesSnapshot.data!;
              if (quizzes.isEmpty) {
                return const _LinkNotice(
                  icon: Icons.quiz_outlined,
                  text: 'Create a quiz first, then return here to link it.',
                );
              }
              return StreamBuilder<Map<String, Map<String, dynamic>>>(
                stream: LearningPathService.watchPaths(widget.classId),
                builder: (context, pathsSnapshot) {
                  if (!pathsSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final paths = pathsSnapshot.data!;
                  final moduleTitles = {
                    for (final module in widget.modules)
                      module.id: module.title,
                  };
                  return Column(
                    children: [
                      for (var index = 0; index < quizzes.length; index++) ...[
                        _QuizLinkRow(
                          quiz: quizzes[index],
                          currentModuleId: _linkedModuleId(
                            paths,
                            quizzes[index],
                          ),
                          currentModuleTitle:
                              moduleTitles[_linkedModuleId(
                                paths,
                                quizzes[index],
                              )],
                          thisModuleId: widget.module.id,
                          enabled:
                              widget.module.isPublished &&
                              _savingQuizId == null,
                          saving: _savingQuizId == quizzes[index].id,
                          onChanged: (link) => _setLink(quizzes[index], link),
                        ),
                        if (index != quizzes.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    ),
  );

  String? _linkedModuleId(
    Map<String, Map<String, dynamic>> paths,
    QuizModel quiz,
  ) {
    final direct = paths[LearningPathService.key('quiz', quiz.id)];
    if (direct != null) return direct['moduleId']?.toString();
    final activity = InteractiveQuizzes.activity(widget.classId, quiz.id);
    return activity == null
        ? null
        : paths[LearningPathService.key('simulation', activity.id)]?['moduleId']
              ?.toString();
  }
}

class _QuizLinkRow extends StatelessWidget {
  const _QuizLinkRow({
    required this.quiz,
    required this.currentModuleId,
    required this.currentModuleTitle,
    required this.thisModuleId,
    required this.enabled,
    required this.saving,
    required this.onChanged,
  });

  final QuizModel quiz;
  final String? currentModuleId;
  final String? currentModuleTitle;
  final String thisModuleId;
  final bool enabled, saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final linkedHere = currentModuleId == thisModuleId;
    final linkedElsewhere = currentModuleId != null && !linkedHere;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: linkedHere
                  ? const Color(0xFFDBEAFE)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              linkedHere ? Icons.link_rounded : Icons.quiz_outlined,
              color: linkedHere
                  ? const Color(0xFF2563EB)
                  : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quiz.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  linkedHere
                      ? 'Linked to this module'
                      : linkedElsewhere
                      ? 'Currently linked to ${currentModuleTitle ?? 'another module'}'
                      : 'No module linked',
                  style: TextStyle(
                    color: linkedHere
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (saving)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: linkedHere,
              onChanged: enabled ? onChanged : null,
            ),
        ],
      ),
    );
  }
}

class _LinkNotice extends StatelessWidget {
  const _LinkNotice({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ],
    ),
  );
}
