import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/data/simulation_data.dart';
import 'package:icteach/widgets/simulation_description.dart';

void main() {
  for (final size in [const Size(320, 640), const Size(740, 360)]) {
    for (final simulation in SimulationData.getAllSimulations()) {
      testWidgets(
        '${simulation.id} descriptions fit $size with large text and dark theme',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final item = simulation.items.first;
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => SimulationItemDescriptionDialog(
                        item: item,
                        resource: 'Use the correct tool for this component.',
                        control:
                            'Follow the keyed orientation before insertion.',
                      ),
                    ),
                    child: const Text('Inspect'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Inspect'));
          await tester.pumpAndSettle();
          if (item.description.trim().isNotEmpty)
            expect(find.text(item.description.trim()), findsOneWidget);
          expect(
            tester
                .widget<AlertDialog>(find.byType(AlertDialog))
                .backgroundColor,
            Colors.white,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
          expect(find.byType(AlertDialog), findsNothing);
        },
      );
    }
  }
  testWidgets(
    'description text keeps explicit contrast and hides empty sections',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: const Scaffold(
            body: Column(
              children: [
                SimulationDescriptionSection(
                  title: 'Description',
                  text: 'Handle by the edges.',
                ),
                SimulationDescriptionSection(title: 'Empty', text: '  '),
              ],
            ),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Handle by the edges.')).style!.color,
        const Color(0xFF334155),
      );
      expect(find.text('Empty'), findsNothing);
    },
  );
}
