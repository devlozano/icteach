import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icteach/services/workspace_navigation.dart';
import 'package:icteach/services/workspace_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final role in ['admin', 'teacher', 'trainer', 'student']) {
    test('$role fresh login discards saved tab and nested routes', () async {
      SharedPreferences.setMockInitialValues({});
      await WorkspacePreferences.initialize();
      WorkspacePreferences.owner = 'returning-user';
      await WorkspacePreferences.saveTab(role, 3);
      await WorkspacePreferences.saveSelection('admin_panel', 'School Profile');
      await WorkspacePreferences.saveSelection('school_name', 'ICTeach School');
      await WorkspacePreferences.savePages(role, [
        {'kind': 'notifications'},
      ]);
      WorkspacePreferences.owner = 'other-user';
      await WorkspacePreferences.saveTab(role, 2);
      await WorkspacePreferences.savePages(role, [
        {'kind': 'notifications'},
      ]);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('icteach_remember_me', true);
      await WorkspaceNavigation().startFreshSession('returning-user');
      expect(WorkspacePreferences.owner, 'returning-user');
      expect(WorkspacePreferences.tab(role, 8), 0);
      expect(
        WorkspacePreferences.selection('admin_panel') ?? 'Dashboard',
        'Dashboard',
      );
      expect(WorkspacePreferences.pages(role), isEmpty);
      expect(WorkspacePreferences.selection('school_name'), 'ICTeach School');
      expect(prefs.getBool('icteach_remember_me'), isTrue);
      WorkspacePreferences.owner = 'other-user';
      expect(WorkspacePreferences.tab(role, 8), 2);
      expect(WorkspacePreferences.pages(role), isNotEmpty);
    });
  }
  test('navigation still persists during an existing session', () async {
    SharedPreferences.setMockInitialValues({});
    await WorkspacePreferences.initialize();
    await WorkspaceNavigation().startFreshSession('user');
    await WorkspacePreferences.saveTab('teacher', 7);
    await WorkspacePreferences.savePages('teacher', [
      {'kind': 'notifications'},
    ]);
    await WorkspacePreferences.initialize();
    expect(WorkspacePreferences.tab('teacher', 8), 7);
    expect(WorkspacePreferences.pages('teacher'), isNotEmpty);
  });
}
