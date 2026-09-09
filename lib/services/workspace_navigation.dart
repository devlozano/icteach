import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'workspace_preferences.dart';
import 'content_access_service.dart';
import 'learning_path_service.dart';
import '../class_roster.dart';
import '../class_detail_page.dart';
import '../screens/notification_page.dart';
import '../screens/teacher/manage_modules_page.dart';
import '../screens/teacher/manage_quizzes_page.dart';
import '../screens/teacher/manage_assignments_page.dart';
import '../screens/teacher/manage_questionnaires_page.dart';
import '../screens/teacher/progress_tracker_page.dart';
import '../screens/teacher/content_lock_manager.dart';
import '../screens/teacher/learning_path_manager.dart';
import '../screens/teacher/activity_timeline_page.dart';
import '../screens/teacher/assessment_review_page.dart';
import '../screens/student/forums_page.dart';
import '../screens/student/module_view_page.dart';
import '../screens/student/student_quizzes_page.dart';
import '../screens/student/student_questionnaires_page.dart';
import '../screens/student/simulation_page.dart';
import '../screens/student/instructional_videos_page.dart';
import '../screens/student/student_assignments_page.dart';

/// Only stable destinations are serialized, never passwords, quiz answers or forms.
class WorkspaceNavigation extends NavigatorObserver {
  static final instance = WorkspaceNavigation();
  final canGoBack = ValueNotifier(false);
  final topPage = ValueNotifier<Route<dynamic>?>(null);
  final _stack = <Route<dynamic>>[];
  final _pages = <Route<dynamic>, Map<String, dynamic>>{};
  String? _role;
  bool _ready = false;

  Map<String, dynamic>? describe(Widget page) {
    if (page is _RestoredDestination) return page.data;
    String? kind, classId, className;
    if (page is NotificationPage) return {'kind': 'notifications'};
    if (page is InstructionalVideosPage)
      return {
        'kind': 'videos',
        'classId': page.classId,
        'className': page.className ?? '',
      };
    if (page is StudentAssignmentsPage)
      return {
        'kind': 'student_assignments',
        'classId': page.classId,
        'className': page.className,
      };
    if (page is ManageModulesPage) {
      kind = 'modules';
      classId = page.classId;
      className = page.className;
    }
    if (page is ManageQuizzesPage) {
      kind = 'quizzes';
      classId = page.classId;
      className = page.className;
    }
    if (page is ManageAssignmentsPage) {
      kind = 'assignments';
      classId = page.classId;
      className = page.className;
    }
    if (page is ManageQuestionnairesPage) {
      kind = 'questionnaires';
      classId = page.classId;
      className = page.className;
    }
    if (page is ClassRosterPage) {
      kind = 'roster';
      classId = page.classId;
      className = page.className;
    }
    if (page is ClassDetailPage) {
      kind = 'class';
      classId = page.classId;
      className = page.className;
    }
    if (page is ProgressTrackerPage) {
      kind = 'insights';
      classId = page.classId;
      className = page.className;
    }
    if (page is ForumsPage) {
      kind = 'forums';
      classId = page.classId;
      className = page.className;
    }
    if (page is ModuleViewPage) {
      kind = 'learn';
      classId = page.classId;
      className = page.className;
    }
    if (page is StudentQuizzesPage) {
      kind = 'student_quizzes';
      classId = page.classId;
      className = page.className;
    }
    if (page is StudentQuestionnairesPage) {
      kind = 'student_feedback';
      classId = page.classId;
      className = page.className;
    }
    if (page is ContentLockManager) {
      kind = 'locks';
      classId = page.classId;
    }
    if (page is LearningPathManager) {
      kind = 'paths';
      classId = page.classId;
    }
    if (page is ActivityTimelinePage) {
      kind = 'activity';
      classId = page.classId;
    }
    if (page is AssessmentReviewPage) {
      kind = 'review';
      classId = page.classId;
      className = page.className;
    }
    if (page is SimulationPage)
      return {
        'kind': 'simulation',
        'classId': page.classId,
        'className': page.className ?? '',
        'id': page.simulationId,
        'title': page.title,
      };
    return kind == null
        ? null
        : {'kind': kind, 'classId': classId, 'className': className ?? ''};
  }

  Widget? destination(Map<String, dynamic> data, String role) {
    final kind = data['kind'];
    if (kind == 'notifications') return const NotificationPage();
    final id = data['classId'],
        name = data['className'] is String
            ? data['className'] as String
            : 'Class';
    if (id is! String || id.isEmpty) return null;
    final staff = const {'teacher', 'trainer', 'admin'}.contains(role);
    if (!staff &&
        const {
          'modules',
          'quizzes',
          'assignments',
          'questionnaires',
          'roster',
          'insights',
          'locks',
          'paths',
          'activity',
          'review',
        }.contains(kind))
      return null;
    return switch (kind) {
      'modules' => ManageModulesPage(classId: id, className: name),
      'videos' => InstructionalVideosPage(classId: id, className: name),
      'student_assignments' => StudentAssignmentsPage(
        classId: id,
        className: name,
      ),
      'quizzes' => ManageQuizzesPage(classId: id, className: name),
      'assignments' => ManageAssignmentsPage(classId: id, className: name),
      'questionnaires' => ManageQuestionnairesPage(
        classId: id,
        className: name,
      ),
      'roster' => ClassRosterPage(classId: id, className: name),
      'class' => ClassDetailPage(classId: id, className: name),
      'insights' => ProgressTrackerPage(classId: id, className: name),
      'forums' => ForumsPage(classId: id, className: name),
      'learn' => ModuleViewPage(classId: id, className: name),
      'student_quizzes' => StudentQuizzesPage(classId: id, className: name),
      'student_feedback' => StudentQuestionnairesPage(
        classId: id,
        className: name,
      ),
      'locks' => ContentLockManager(classId: id),
      'paths' => LearningPathManager(classId: id),
      'activity' => ActivityTimelinePage(classId: id),
      'review' => AssessmentReviewPage(classId: id, className: name),
      'simulation' when data['id'] is String && data['title'] is String =>
        SimulationPage(
          classId: id,
          simulationId: data['id'],
          title: data['title'],
          className: name,
        ),
      _ => null,
    };
  }

  void _capture(Route<dynamic> route) {
    if (route is MaterialPageRoute && navigator != null) {
      try {
        final data = describe(route.builder(navigator!.context));
        if (data != null) _pages[route] = data;
      } catch (e) {
        debugPrint('Destination not restorable: $e');
      }
    }
  }

  void _changed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      canGoBack.value = navigator?.canPop() ?? false;
      final pages = _stack.whereType<PageRoute<dynamic>>();
      topPage.value = pages.isEmpty ? null : pages.last;
    });
    if (_ready &&
        _role != null &&
        FirebaseAuth.instance.currentUser?.uid == WorkspacePreferences.owner) {
      WorkspacePreferences.savePages(
        _role!,
        _stack.where(_pages.containsKey).map((r) => _pages[r]!).toList(),
      );
    }
  }

  @override
  void didPush(Route route, Route? previousRoute) {
    _stack.add(route);
    _capture(route);
    _changed();
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    _stack.remove(route);
    _pages.remove(route);
    _changed();
  }

  @override
  void didRemove(Route route, Route? previousRoute) {
    _stack.remove(route);
    _pages.remove(route);
    _changed();
  }

  @override
  void didReplace({Route? newRoute, Route? oldRoute}) {
    final index = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    _stack.remove(oldRoute);
    _pages.remove(oldRoute);
    if (newRoute != null) {
      _stack.insert(index < 0 ? _stack.length : index, newRoute);
      _capture(newRoute);
    }
    _changed();
  }

  Future<void> restore(BuildContext context, String uid, String role) async {
    _ready = false;
    _role = role;
    WorkspacePreferences.owner = uid;
    final saved = WorkspacePreferences.pages(role);
    for (final data in saved) {
      final page = destination(data, role);
      if (page == null) continue;
      if (!context.mounted || FirebaseAuth.instance.currentUser?.uid != uid)
        return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              _RestoredDestination(data: data, role: role, child: page),
        ),
      );
    }
    _ready = true;
    _changed();
  }
}

class _RestoredDestination extends StatefulWidget {
  final Map<String, dynamic> data;
  final String role;
  final Widget child;
  const _RestoredDestination({
    required this.data,
    required this.role,
    required this.child,
  });
  @override
  State<_RestoredDestination> createState() => _RestoredDestinationState();
}

class _RestoredDestinationState extends State<_RestoredDestination> {
  late Future<bool> _access = _check();
  Future<bool> _check() async {
    final id = widget.data['classId'];
    if (id is! String) return true;
    if (const {'teacher', 'trainer', 'admin'}.contains(widget.role))
      return ContentAccessService.isClassStaff(id);
    await LearningPathService.requireActive(id);
    return true;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _access,
    builder: (context, snapshot) {
      if (snapshot.hasError || snapshot.data == false)
        return Scaffold(
          appBar: AppBar(title: const Text('Restore workspace')),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Your page is saved, but access could not be verified. Check your connection and class access, then retry.',
                  ),
                  TextButton(
                    onPressed: () {
                      final next = _check();
                      next.ignore();
                      setState(() {
                        _access = next;
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        );
      if (!snapshot.hasData)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      return widget.child;
    },
  );
}
