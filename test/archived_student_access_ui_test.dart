import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/activity_preparation_gate.dart';

void main() {
  testWidgets(
    'archived simulation entry offers practice without graded controls',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ActivityPreparationGate(
            classId: 'archived-class',
            type: 'simulation',
            contentId: 'pc-assembly',
            title: 'PC Assembly',
            practiceOnly: true,
            sessionBuilder: (_) => const SizedBox.shrink(),
          ),
        ),
      );

      expect(find.text('Start practice'), findsOneWidget);
      expect(find.textContaining('graded simulation'), findsNothing);
      expect(find.textContaining('class is already archived'), findsNothing);
    },
  );
}
