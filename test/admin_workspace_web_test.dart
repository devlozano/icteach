import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/admin_workspace_layout.dart';
import 'package:icteach/widgets/admin_workspace_sidebar.dart';
import 'package:icteach/widgets/workspace_dashboard.dart';
import 'package:icteach/widgets/workspace_stat.dart';

void main() {
  for (final role in ['Teacher', 'Trainer']) {
    for (final size in [
      const Size(320, 640),
      const Size(740, 360),
      const Size(1000, 800),
      const Size(1440, 900),
    ]) {
      testWidgets(
        '$role admin layout at $size: navigation and page scrolling',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          int selected = 0;
          bool actionCalled = false;
          await tester.pumpWidget(
            MaterialApp(
              home: StatefulBuilder(
                builder: (context, setState) {
                  return AdminWorkspaceLayout(
                    sidebarBuilder: (close) => AdminWorkspaceSidebar(
                      role: role,
                      identity: const Text('Staff Member'),
                      items: const [
                        (Icons.dashboard, 'Dashboard'),
                        (Icons.school, 'Classes'),
                      ],
                      selectedIndex: selected,
                      onSelected: (index) {
                        setState(() => selected = index);
                        close();
                      },
                      onLogout: () {},
                    ),
                    topBarBuilder: (showMenu) => Builder(
                      builder: (context) => SizedBox(
                        height: 52,
                        child: Row(
                          children: [
                            if (showMenu)
                              IconButton(
                                tooltip: 'Open menu',
                                icon: const Icon(Icons.menu),
                                onPressed: () =>
                                    Scaffold.of(context).openDrawer(),
                              ),
                            Text('$role Workspace'),
                          ],
                        ),
                      ),
                    ),
                    title: selected == 0 ? 'Dashboard' : 'Classes',
                    subtitle: 'Welcome back',
                    icon: Icons.dashboard,
                    child: WorkspaceDashboard(
                      stats: const WorkspaceStats(
                        cards: [
                          WorkspaceStatData(
                            title: 'Classes',
                            value: '12',
                            subtitle: 'Assigned classes',
                            icon: Icons.school,
                            color: Colors.cyan,
                          ),
                          WorkspaceStatData(
                            title: 'Students',
                            value: '100',
                            subtitle: 'Currently enrolled',
                            icon: Icons.people,
                            color: Colors.green,
                          ),
                          WorkspaceStatData(
                            title: 'Pending Reviews',
                            value: '3',
                            subtitle: 'Awaiting review',
                            icon: Icons.pending,
                            color: Colors.orange,
                          ),
                        ],
                      ),
                      content: const SizedBox(
                        height: 180,
                        child: Text('Class records'),
                      ),
                      actions: [
                        (
                          Icons.add,
                          'Create or Join Class',
                          () => actionCalled = true,
                        ),
                        (Icons.menu_book, 'Manage Modules', () {}),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(NavigationBar), findsNothing);
          if (size.width < 1000) {
            expect(find.byType(Drawer), findsNothing);
            await tester.tap(find.byTooltip('Open menu'));
            await tester.pumpAndSettle();
            expect(find.byType(Drawer), findsOneWidget);
          } else {
            expect(
              tester.getSize(find.byType(AdminWorkspaceSidebar)).width,
              260,
            );
          }
          await tester.tap(
            find.descendant(
              of: find.byType(AdminWorkspaceSidebar),
              matching: find.text('Classes'),
            ),
          );
          await tester.pumpAndSettle();
          expect(selected, 1);
          expect(tester.widget<Scaffold>(find.byType(Scaffold)).appBar, isNull);
          if (size.width < 1000) expect(find.byType(Drawer), findsNothing);
          await tester.scrollUntilVisible(
            find.text('Create or Join Class'),
            250,
            scrollable: find
                .descendant(
                  of: find.byType(SingleChildScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.tap(find.text('Create or Join Class'));
          expect(actionCalled, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
