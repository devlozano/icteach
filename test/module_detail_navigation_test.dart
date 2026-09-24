import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/models/module_model.dart';
import 'package:icteach/widgets/module_list_card.dart';
import 'package:icteach/widgets/module_access_overview.dart';
import 'package:icteach/screens/teacher/module_management_detail_page.dart';

void main() {
  final module = ModuleModel(
    id: 'lesson1',
    classId: 'class1',
    title: 'Computer hardware',
    description: 'Learn about computer components.',
    content: '',
    order: 0,
    isPublished: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  for (final size in [
    const Size(320, 640),
    const Size(740, 360),
    const Size(1280, 800),
  ]) {
    testWidgets('open module before actions and student activity at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var edits = 0;
      var publishes = 0;
      var deletes = 0;
      var activityBuilds = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: SingleChildScrollView(
                child: ModuleListCard(
                  module: module,
                  onOpen: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) {
                        activityBuilds++;
                        return ModuleDetailView(
                          module: module,
                          onEdit: () => edits++,
                          onDelete: () => deletes++,
                          onTogglePublish: () => publishes++,
                          activity: const ModuleAccessOverview(
                            students: [
                              ModuleStudentActivity(
                                id: 'student1',
                                name: 'Ana Santos',
                                accessed: true,
                              ),
                            ],
                            accessed: 1,
                            downloaded: 0,
                            requested: 0,
                            printAction: SizedBox.shrink(),
                            initiallyExpanded: true,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Unpublish'), findsNothing);
      expect(find.byType(ModuleAccessOverview), findsNothing);
      expect(activityBuilds, 0);
      await tester.tap(find.text('Computer hardware'));
      await tester.pumpAndSettle();
      expect(find.text('Module details'), findsOneWidget);
      expect(find.text('Computer hardware'), findsOneWidget);
      expect(find.text('Ana Santos'), findsOneWidget);
      for (final label in ['Edit', 'Unpublish']) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byTooltip('Delete module'));
      await tester.tap(find.byTooltip('Delete module'));
      expect(edits, 1);
      expect(publishes, 1);
      expect(deletes, 1);
      await tester.ensureVisible(find.text('Ana Santos'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Open module →'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.byType(ModuleAccessOverview), findsNothing);
    });
  }
}
