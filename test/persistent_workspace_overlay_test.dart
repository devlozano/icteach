import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/workspace_navigation.dart';
import 'package:icteach/widgets/admin_workspace_sidebar.dart';
import 'package:icteach/widgets/staff_sidebar.dart';
import 'package:icteach/widgets/persistent_workspace.dart';

void main() {
  for (final role in ['Teacher', 'Trainer']) {
    for (final width in [390.0, 1440.0]) {
      for (final web in [true, false]) {
        testWidgets(
          role +
              ' ' +
              (web ? 'web' : 'app') +
              ' shell supports overlays at ' +
              width.toString(),
          (tester) async {
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final navigator = GlobalKey<NavigatorState>();
            await tester.pumpWidget(
              MaterialApp(
                navigatorKey: navigator,
                navigatorObservers: [WorkspaceNavigation.instance],
                builder: (context, child) => PersistentWorkspace(child: child!),
                home: Builder(
                  builder: (context) {
                    void home(int _) =>
                        PersistentWorkspace.returnHome(context, () {});
                    final sidebar = web
                        ? AdminWorkspaceSidebar(
                            role: role,
                            identity: Text(role),
                            items: const [(Icons.dashboard, 'Dashboard')],
                            selectedIndex: 0,
                            onSelected: home,
                            onLogout: () {},
                          )
                        : StaffSidebar(
                            role: role,
                            name: role,
                            items: const [(Icons.dashboard, 'Dashboard')],
                            selectedIndex: 0,
                            onSelected: home,
                            onLogout: () {},
                          );
                    PersistentWorkspace.register(context, sidebar);
                    return const Scaffold(body: Text('Home'));
                  },
                ),
              ),
            );
            await tester.pumpAndSettle();
            for (final page in [
              'Module Management',
              'Student Management',
              'Discussions',
              'Manage Classes',
              'Join Class',
              'Profile',
              'Notifications',
            ]) {
              navigator.currentState!.push(
                MaterialPageRoute<void>(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: Text(page),
                      actions: [
                        IconButton(
                          tooltip: 'Page action',
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => showDialog<void>(
                            context: context,
                            builder: (_) =>
                                const AlertDialog(title: Text('Dialog works')),
                          ),
                        ),
                      ],
                    ),
                    body: const TextField(),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
              await tester.longPress(find.byIcon(Icons.info_outline));
              await tester.pumpAndSettle();
              expect(find.text('Page action'), findsOneWidget);
              expect(tester.takeException(), isNull);
              await tester.tap(find.byIcon(Icons.info_outline));
              await tester.pumpAndSettle();
              expect(find.byType(AlertDialog), findsOneWidget);
              expect(tester.takeException(), isNull);
              navigator.currentState!.pop();
              await tester.pumpAndSettle();
              if (width >= 1000 && web) {
                await tester.longPress(find.byIcon(Icons.logout_rounded));
                await tester.pumpAndSettle();
                expect(find.text('Sign out'), findsOneWidget);
                expect(tester.takeException(), isNull);
              }
              if (width >= 1000) {
                await tester.tap(find.text('Dashboard'));
              } else {
                navigator.currentState!.pop();
              }
              await tester.pumpAndSettle();
              expect(find.text('Home'), findsOneWidget);
              expect(tester.takeException(), isNull);
            }
            await tester.pumpWidget(const SizedBox.shrink());
            PersistentWorkspace.clear();
          },
        );
      }
    }
  }
}
