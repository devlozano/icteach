import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:icteach/admin_login.dart';
import 'package:icteach/widgets/admin_workspace_sidebar.dart';

void main() {
  for (final role in ['Teacher', 'Trainer']) {
    for (final height in [200.0, 360.0, 800.0]) {
      testWidgets(
        '$role sidebar fits short windows and large text at $height',
        (tester) async {
          tester.view.physicalSize = Size(1100, height);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          int selected = -1;
          bool signedOut = false;
          await tester.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(1100, height),
                  textScaler: const TextScaler.linear(2),
                ),
                child: Row(
                  children: [
                    AdminWorkspaceSidebar(
                      role: role,
                      identity: const Text('Sign out'),
                      items: const [
                        (Icons.dashboard, 'Dashboard'),
                        (Icons.groups, 'Student Management'),
                        (Icons.book, 'Module Management'),
                        (Icons.person, 'Profile'),
                      ],
                      selectedIndex: 0,
                      onSelected: (index) => selected = index,
                      onLogout: () => signedOut = true,
                    ),
                    const Expanded(child: Scaffold(body: Text('Detail page'))),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(find.text('Profile'), 120);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Profile'));
          expect(selected, 3);
          await tester.scrollUntilVisible(find.byTooltip('Sign out'), 120);
          await tester.pumpAndSettle();
          await tester.tap(find.byTooltip('Sign out'));
          expect(signedOut, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  for (final width in [400.0, 800.0]) {
    testWidgets('login footer is centered at $width', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: AdminLoginPage()));
      await tester.pumpAndSettle();
      final text = find.text('ICTeach Learning Management System');
      final row = find.ancestor(of: text, matching: find.byType(Row)).first;
      expect(tester.getCenter(text).dx, closeTo(tester.getCenter(row).dx, .1));
      expect(tester.takeException(), isNull);
    });
  }
}
