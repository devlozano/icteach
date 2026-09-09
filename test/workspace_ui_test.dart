import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icteach/widgets/staff_sidebar.dart';
import 'package:icteach/services/workspace_preferences.dart';
import 'package:icteach/services/workspace_navigation.dart';
import 'package:icteach/services/navigation_service.dart';
import 'package:icteach/screens/teacher/manage_modules_page.dart';
import 'package:icteach/utils/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await WorkspacePreferences.initialize();
    WorkspacePreferences.owner = 'teacher-a';
  });
  test(
    'tab and page persistence survive reload and remain account-scoped',
    () async {
      await WorkspacePreferences.saveTab('teacher', 3);
      await WorkspacePreferences.savePages('teacher', [
        {'kind': 'modules', 'classId': 'class-1', 'className': 'CSS'},
      ]);
      await WorkspacePreferences.initialize();
      expect(WorkspacePreferences.tab('teacher', 5), 3);
      expect(
        WorkspacePreferences.pages('teacher').single['classId'],
        'class-1',
      );
      WorkspacePreferences.owner = 'teacher-b';
      expect(WorkspacePreferences.tab('teacher', 5), 0);
      expect(WorkspacePreferences.pages('teacher'), isEmpty);
    },
  );
  test('invalid saved tabs and corrupt page data fall back safely', () async {
    await WorkspacePreferences.saveTab('teacher', 99);
    expect(WorkspacePreferences.tab('teacher', 5), 0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'workspace_v1_teacher-a_teacher_pages',
      'broken json',
    );
    expect(WorkspacePreferences.pages('teacher'), isEmpty);
  });
  test(
    'stable route roundtrip retains class and denies student staff restoration',
    () {
      final observer = WorkspaceNavigation();
      final data = observer.describe(
        const ManageModulesPage(classId: 'class-1', className: 'CSS'),
      )!;
      final page = observer.destination(data, 'teacher') as ManageModulesPage;
      expect(page.classId, 'class-1');
      expect(page.className, 'CSS');
      expect(observer.destination(data, 'student'), isNull);
      expect(observer.destination({'kind': 'unknown'}, 'teacher'), isNull);
      expect(observer.describe(const SizedBox()), isNull);
    },
  );
  for (final role in ['Teacher', 'Trainer']) {
    testWidgets(
      '$role sidebar labels visible with large text and short window',
      (tester) async {
        tester.view.physicalSize = const Size(1100, 440);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var selected = -1;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
                child: StaffSidebar(
                  role: role,
                  name: 'A long teacher or trainer display name',
                  selectedIndex: 1,
                  items: const [
                    (Icons.home, 'Overview'),
                    (Icons.groups, 'Classes'),
                    (Icons.forum, 'Discussions'),
                    (Icons.insights, 'Analytics'),
                    (Icons.person, 'Profile'),
                  ],
                  onSelected: (i) => selected = i,
                  onLogout: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final label = tester.widget<Text>(find.text('Classes'));
        expect(label.style?.color, Colors.white);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Classes'));
        expect(selected, 1);
        await tester.drag(find.byType(ListView), const Offset(0, -600));
        await tester.pumpAndSettle();
        expect(find.text('Sign out').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('dark app bars inherit white title and back icon correctly', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF0B2B4A),
            foregroundColor: Colors.white,
            leading: const BackButton(),
            title: const Text('Manage quizzes'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final titleContext = tester.element(find.text('Manage quizzes'));
    expect(DefaultTextStyle.of(titleContext).style.color, Colors.white);
    final backContext = tester.element(find.byType(BackButton));
    expect(IconTheme.of(backContext).color, Colors.white);
  });
  testWidgets('system back pops a detail page without removing dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) NavigationService.onWillPop(context);
            },
            child: Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const Scaffold(body: Text('Detail page')),
                  ),
                ),
                child: const Text('Open detail'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open detail'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open detail'), findsOneWidget);
    expect(find.text('Exit ICTeach?'), findsNothing);
  });
  testWidgets(
    'one screen app bar provides Back navigation without a global header',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          navigatorKey: NavigationService.navigatorKey,
          navigatorObservers: [WorkspaceNavigation.instance],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Destination')),
                      body: const SizedBox(),
                    ),
                  ),
                ),
                child: const Text('Open destination'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsNothing);
      await tester.tap(find.text('Open destination'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('ICTeach workspace'), findsNothing);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Open destination'), findsOneWidget);
      expect(find.text('Back'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
