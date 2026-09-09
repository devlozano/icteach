import '../../services/module_access_service.dart';
import '../../widgets/module_resource_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/module_model.dart';
import '../../services/module_service.dart';
import 'instructional_videos_page.dart';
import 'pre_assessment_page.dart';
import 'course_feedback_page.dart';
import '../../services/learning_path_service.dart';
import '../../services/workspace_preferences.dart';
import '../../widgets/content_access_gate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class ModuleViewPage extends StatefulWidget {
  final String classId;
  final String className;

  const ModuleViewPage({
    super.key,
    required this.classId,
    required this.className,
  });

  @override
  State<ModuleViewPage> createState() => _ModuleViewPageState();
}

class _ModuleViewPageState extends State<ModuleViewPage> {
  final ModuleService _moduleService = ModuleService();
  String _selectedFilter = 'All';
  int? _selectedModuleIndex;
  bool _selectionRestored = false;
  void _backToModules() {
    setState(() => _selectedModuleIndex = null);
    WorkspacePreferences.saveSelection('module_${widget.classId}', '');
  }

  final Map<String, bool> _progress = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _progressSubscription;
  bool _savingProgress = false;
  String? _progressError;

  @override
  void initState() {
    super.initState();
    _listenProgress();
  }

  @override
  void didUpdateWidget(covariant ModuleViewPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _progressSubscription?.cancel();
      _progress.clear();
      _selectedModuleIndex = null;
      _selectionRestored = false;
      _progressError = null;
      _listenProgress();
    }
  }

  void _listenProgress() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _progressSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('module_progress')
          .where('classId', isEqualTo: widget.classId)
          .snapshots()
          .listen(
            (snapshot) {
              if (!mounted) return;
              setState(() {
                _progressError = null;
                _progress.clear();
                for (final doc in snapshot.docs) {
                  _progress[doc.data()['moduleId'].toString()] =
                      doc.data()['completed'] == true;
                }
              });
            },
            onError: (Object error) {
              if (mounted) {
                setState(
                  () =>
                      _progressError = 'Unable to load saved module progress.',
                );
              }
            },
          );
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<bool> _saveProgress(ModuleModel module, bool completed) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _savingProgress) return false;
    setState(() => _savingProgress = true);
    try {
      final db = FirebaseFirestore.instance;
      await LearningPathService.requireActive(widget.classId);
      final ref = db
          .collection('users')
          .doc(uid)
          .collection('module_progress')
          .doc('${widget.classId}_${module.id}');
      final savedCompleted = await db.runTransaction<bool>((transaction) async {
        final previous = await transaction.get(ref);
        final done = completed || previous.data()?['completed'] == true;
        transaction.set(ref, {
          'classId': widget.classId,
          'moduleId': module.id,
          'studentId': uid,
          'completed': done,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        transaction.set(
          ModuleAccessService.record(widget.classId, module.id, uid),
          {
            'studentId': uid,
            'moduleId': module.id,
            'accessed': true,
            'lastAccessedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        transaction.set(db.collection('activity_events').doc(), {
          'classId': widget.classId,
          'studentId': uid,
          'studentName':
              FirebaseAuth.instance.currentUser?.displayName ??
              FirebaseAuth.instance.currentUser?.email ??
              'Student',
          'contentId': module.id,
          'title': module.title,
          'event': completed ? 'lesson_completed' : 'lesson_opened',
          'mode': 'learning',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return done;
      });
      if (mounted) {
        setState(() => _progress[module.id] = savedCompleted);
        if (completed)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Lesson complete. Finished all lessons? Share your system evaluation.',
              ),
              action: SnackBarAction(
                label: 'Evaluate',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseFeedbackPage(classId: widget.classId),
                  ),
                ),
              ),
            ),
          );
      }
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save module progress. Please reconnect and retry.',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _savingProgress = false);
    }
  }

  final List<String> _filters = [
    'All',
    'In Progress',
    'Completed',
    'Not Started',
  ];

  String extractYouTubeId(String url) {
    String videoId = '';
    if (url.contains('watch?v=')) {
      videoId = url.split('watch?v=').last.split('&').first;
    } else if (url.contains('youtu.be/')) {
      videoId = url.split('youtu.be/').last.split('?').first;
    } else if (url.contains('youtube.com/embed/')) {
      videoId = url.split('embed/').last.split('?').first;
    }
    videoId = videoId.split('&').first.split('?').first;
    return videoId;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _selectedModuleIndex == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToModules();
      },
      child: PreAssessmentPage(
        classId: widget.classId,
        className: widget.className,
        builder: (_) => ContentAccessGate(
          classId: widget.classId,
          contentType: 'module',
          builder: _buildPage,
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _selectedModuleIndex == null
          ? AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Learning Modules',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  Text(
                    widget.className,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.transparent,
              foregroundColor: const Color(0xFF0F172A),
              elevation: 0,
              toolbarHeight: 52,
            )
          : null,
      body: StreamBuilder<List<ModuleModel>>(
        stream: _moduleService.getPublishedModulesForClass(widget.classId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red.shade400,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Oops! Something went wrong',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${snapshot.error}',
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => setState(() {}),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
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
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 64,
                      color: Colors.indigo.shade300,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'No modules available',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Check back later for new learning materials.',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          if (!_selectionRestored) {
            _selectionRestored = true;
            final saved = WorkspacePreferences.selection(
              'module_${widget.classId}',
            );
            final index = modules.indexWhere((m) => m.id == saved);
            if (index >= 0) {
              _selectedModuleIndex = index;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  _saveProgress(modules[index], false);
                  setState(() {});
                }
              });
            }
          }
          if (_selectedModuleIndex != null) {
            if (_selectedModuleIndex! >= modules.length) {
              _selectedModuleIndex = null;
            }
          }
          if (_selectedModuleIndex != null) {
            final module = modules[_selectedModuleIndex!];
            return ContentAccessGate(
              key: ValueKey(module.id),
              classId: widget.classId,
              contentType: 'module',
              contentId: module.id,
              builder: (_) => _buildModuleDetailView(module, modules.length),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filter Chips
              if (_progressError != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_progressError!),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        child: FilterChip(
                          label: Text(
                            filter,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF475569),
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              _selectedFilter = filter;
                            });
                          },
                          backgroundColor: Colors.white,
                          selectedColor: const Color(0xFF4F46E5),
                          elevation: isSelected ? 4 : 0,
                          pressElevation: 0,
                          shadowColor: const Color(0xFF4F46E5).withOpacity(0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Module List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 20,
                    right: 20,
                    bottom: 30,
                  ),
                  itemCount: modules.length,
                  itemBuilder: (context, index) {
                    final module = modules[index];
                    final status = _progress[module.id] == true
                        ? 'Completed'
                        : _progress.containsKey(module.id)
                        ? 'In Progress'
                        : 'Not Started';
                    if (_selectedFilter != 'All' && _selectedFilter != status) {
                      return const SizedBox.shrink();
                    }
                    return _ModuleCard(
                      module: module,
                      index: index,
                      status: status,
                      onTap: () {
                        _saveProgress(module, false);
                        setState(() {
                          _selectedModuleIndex = index;
                          WorkspacePreferences.saveSelection(
                            'module_${widget.classId}',
                            module.id,
                          );
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModuleDetailView(ModuleModel module, int totalModules) {
    final hasVideo = module.videoUrl != null && module.videoUrl!.isNotEmpty;
    final progress = _progress[module.id] == true ? 1.0 : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: const Color(0xFF4F46E5),
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: _backToModules,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.2),
                padding: const EdgeInsets.all(12),
              ),
            ),
            actions: [
              if (hasVideo)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InstructionalVideosPage(
                            classId: widget.classId,
                            className: widget.className,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 28),
                    tooltip: 'Watch Videos',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Decorative background gradient
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF4F46E5),
                          Color(0xFF6366F1),
                          Color(0xFF818CF8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  // Decorative circles
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ),
                  // Content
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'MODULE ${_selectedModuleIndex! + 1} OF $totalModules',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          module.title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Your Progress',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF4F46E5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            color: const Color(0xFF4F46E5),
                            backgroundColor: Colors.indigo.shade50,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Overview Section
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      module.description.isNotEmpty
                          ? module.description
                          : 'No description provided for this module.',
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF475569),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Attachment Section
                  if (module.attachmentUrl != null &&
                      module.attachmentUrl!.isNotEmpty) ...[
                    const Text(
                      'Resources',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ModuleResourceActions(
                      classId: widget.classId,
                      module: module,
                    ),
                  ],

                  // Mark as Done Button
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savingProgress
                          ? null
                          : () async {
                              if (!await _saveProgress(module, true) ||
                                  !mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 12),
                                      Text('Module marked as completed!'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                              _backToModules();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 4,
                        shadowColor: const Color(0xFF4F46E5).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Mark as Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final ModuleModel module;
  final int index;
  final VoidCallback onTap;
  final String status;

  const _ModuleCard({
    required this.module,
    required this.index,
    required this.onTap,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final progress = status == 'Completed' ? 1.0 : 0.0;

    final statusColor = status == 'Completed'
        ? Colors.green.shade600
        : status == 'In Progress'
        ? const Color(0xFFF59E0B) // Amber 500
        : Colors.grey.shade500;

    final statusBgColor = status == 'Completed'
        ? Colors.green.shade50
        : status == 'In Progress'
        ? Colors.amber.shade50
        : Colors.grey.shade100;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  module.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  module.description.isNotEmpty
                      ? module.description
                      : 'Learn the core concepts and fundamental knowledge in this module.',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF475569),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Progress',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 6,
                              color: statusColor,
                              backgroundColor: Colors.grey.shade100,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class YouTubePlayerPage extends StatefulWidget {
  final String videoId;
  final String originalUrl;

  const YouTubePlayerPage({
    super.key,
    required this.videoId,
    required this.originalUrl,
  });

  @override
  State<YouTubePlayerPage> createState() => _YouTubePlayerPageState();
}

class _YouTubePlayerPageState extends State<YouTubePlayerPage> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: true,
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        mute: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  void _openInBrowser(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // ignore
    }
  }

  void _openInYouTubeApp() async {
    try {
      final youtubeUri = Uri.parse('vnd.youtube://watch?v=');
      if (await canLaunchUrl(youtubeUri)) {
        await launchUrl(youtubeUri, mode: LaunchMode.externalApplication);
      } else {
        _openInBrowser(widget.originalUrl);
      }
    } catch (e) {
      _openInBrowser(widget.originalUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Video Player',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _openInYouTubeApp,
            icon: const Icon(Icons.youtube_searched_for, color: Colors.red),
            tooltip: 'Open in YouTube App',
          ),
          IconButton(
            onPressed: () => _openInBrowser(widget.originalUrl),
            icon: const Icon(Icons.open_in_browser),
            tooltip: 'Open in Browser',
          ),
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.originalUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('✅ URL copied'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded),
            tooltip: 'Copy URL',
          ),
        ],
      ),
      body: Center(child: YoutubePlayer(controller: _controller)),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: const Color(0xFF111827), // Gray 900
        child: SafeArea(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Playing inside the app',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
