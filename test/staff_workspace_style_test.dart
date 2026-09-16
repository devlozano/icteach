import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/staff_sidebar.dart';
import 'package:icteach/widgets/staff_workspace_header.dart';

void main() {
  for (final width in [320.0, 600.0, 1280.0]) {
    testWidgets('shared heading fits width $width', (tester) async {
      tester.view.physicalSize = Size(width, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaffPageHeading(
              title: 'Dashboard',
              subtitle: 'Welcome back to ICTeach Teacher',
              icon: Icons.dashboard_outlined,
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final role in ['Teacher', 'Trainer']) {
    testWidgets('$role sidebar scrolls and selects destinations', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StaffSidebar(
              role: role,
              name: 'Staff member',
              selectedIndex: 0,
              items: const [
                (Icons.dashboard, 'Dashboard'),
                (Icons.school, 'Classes'),
              ],
              onSelected: (index) => selected = index,
              onLogout: () {},
            ),
          ),
        ),
      );
      await tester.tap(find.text('Classes'));
      expect(selected, 1);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(find.text('Sign out'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
