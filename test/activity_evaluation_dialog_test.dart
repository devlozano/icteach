import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/activity_evaluation_dialog.dart';

void main() {
  testWidgets('Later safely closes evaluation after comment input', (
    tester,
  ) async {
    ActivityEvaluation? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showActivityEvaluationDialog(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Appropriate'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('activity-evaluation-comment')),
      'Make the cable step clearer.',
    );
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('Activity evaluation'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Submit returns selected difficulty and trimmed comment', (
    tester,
  ) async {
    ActivityEvaluation? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                result = await showActivityEvaluationDialog(context);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('activity-evaluation-comment')),
      '  Clear instructions  ',
    );
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();

    expect(result?.difficulty, 3);
    expect(result?.comment, 'Clear instructions');
    expect(tester.takeException(), isNull);
  });
}
