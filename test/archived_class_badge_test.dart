import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/archived_class_badge.dart';

void main() {
  test('archive state uses the canonical class status', () {
    expect(isArchivedClass({'status': 'archived'}), isTrue);
    expect(isArchivedClass({'status': 'ARCHIVED'}), isTrue);
    expect(isArchivedClass({'status': 'active'}), isFalse);
  });

  testWidgets('archived class badge clearly labels the class', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: ArchivedClassBadge())),
    );

    expect(find.text('ARCHIVED'), findsOneWidget);
    expect(find.byType(ArchivedClassBadge), findsOneWidget);
  });
}
