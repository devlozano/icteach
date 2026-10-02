import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/screens/student/module_view_page.dart';

void main() {
  testWidgets('student module status filters stay usable on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var selected = '';
    const entries = [
      ('All', 8, Icons.grid_view_rounded, Color(0xFF2563EB)),
      ('In Progress', 2, Icons.play_circle_outline_rounded, Color(0xFFF59E0B)),
      ('Completed', 3, Icons.check_circle_outline_rounded, Color(0xFF16A34A)),
      ('Not Started', 3, Icons.schedule_rounded, Color(0xFF64748B)),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 70,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var index = 0; index < entries.length; index++) ...[
                    if (index > 0) const SizedBox(width: 10),
                    ModuleStatusFilter(
                      label: entries[index].$1,
                      count: entries[index].$2,
                      icon: entries[index].$3,
                      color: entries[index].$4,
                      selected: index == 0,
                      onTap: () => selected = entries[index].$1,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('All'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Not Started'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('All'));
    expect(selected, 'All');
  });
}
