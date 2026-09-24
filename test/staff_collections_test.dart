import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/models/module_model.dart';
import 'package:icteach/widgets/module_library.dart';
import 'package:icteach/widgets/roster_directory.dart';
import 'package:icteach/widgets/module_list_card.dart';

ModuleModel lesson(String id, String title, bool published) => ModuleModel(
  id: id,
  classId: 'class',
  title: title,
  description: 'Prepare and maintain computer systems safely.',
  content: '',
  order: 0,
  isPublished: published,
  competencies: ['Hardware'],
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  final modules = [
    lesson('1', 'Computer hardware basics', true),
    lesson('2', 'Network setup', false),
  ];
  for (final size in [
    const Size(320, 640),
    const Size(740, 360),
    const Size(1280, 800),
  ]) {
    testWidgets('module library fits $size and actions work', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var edits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ModuleLibrary(
              modules: modules,
              onCreate: () {},
              itemBuilder: (m) =>
                  ModuleListCard(module: m, onOpen: () => edits++),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      for (
        var i = 0;
        i < 12 && find.text('Open module →').hitTestable().evaluate().isEmpty;
        i++
      ) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -180));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Open module →').hitTestable().first);
      expect(edits, 1);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('module search combines with draft filter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModuleLibrary(
            modules: modules,
            onCreate: () {},
            itemBuilder: (m) => Text('Result: ${m.title}'),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Drafts'));
    await tester.pump();
    expect(find.text('Result: Network setup'), findsOneWidget);
    expect(find.text('Result: Computer hardware basics'), findsNothing);
    await tester.enterText(find.byType(TextField), 'HARDWARE');
    await tester.pump();
    expect(
      find.text('Result: Network setup'),
      findsOneWidget,
    ); // Competency search.
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.pump();
    expect(find.text('No matching modules'), findsOneWidget);
  });
  testWidgets('roster search and role filters work at narrow width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RosterDirectory(
            students: const [
              {'id': 'a', 'name': 'Ana', 'email': 'ana@school.test'},
            ],
            trainers: const [
              {'id': 'b', 'name': 'Ben', 'email': 'ben@school.test'},
            ],
            itemBuilder: (user, trainer) => Text('Person: ${user['name']}'),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byType(TextField), 'ANA@SCHOOL');
    await tester.pump();
    expect(find.text('Person: Ana'), findsOneWidget);
    expect(find.text('Person: Ben'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Trainers'));
    await tester.pump();
    expect(find.text('No matching people'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Person: Ben'), findsOneWidget);
    expect(find.text('Person: Ana'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('module access cards are built only near the viewport', (
    tester,
  ) async {
    var built = 0;
    final many = List.generate(80, (i) => lesson('$i', 'Lesson $i', true));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModuleLibrary(
            modules: many,
            onCreate: () {},
            itemBuilder: (m) {
              built++;
              return SizedBox(height: 240, child: Text(m.title));
            },
          ),
        ),
      ),
    );
    expect(built, lessThan(10));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(built, greaterThan(0));
    expect(built, lessThan(80));
  });
}
