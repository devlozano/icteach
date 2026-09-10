import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/register.dart';
import 'package:icteach/services/registration_invitation_service.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('LRN validation is available at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: RegisterPage()));
      expect(find.text('Learning Reference Number (LRN)'), findsOneWidget);
      expect(find.text('Verify LRN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('shows master-list names only after LRN verification', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RegisterPage(
          lrnVerifier: (_) async => const LrnIdentity(
            lrn: '123456789012',
            firstName: 'Niña',
            lastName: 'Dela Cruz',
          ),
        ),
      ),
    );

    expect(find.text('First Name'), findsNothing);
    await tester.enterText(find.byType(TextFormField).first, '123456789012');
    await tester.ensureVisible(find.text('Verify LRN'));
    await tester.tap(find.text('Verify LRN'));
    await tester.pumpAndSettle();

    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Niña'), findsOneWidget);
    expect(find.text('Dela Cruz'), findsNWidgets(2));

    await tester.enterText(find.byType(TextFormField).first, '000000000000');
    await tester.pump();
    expect(find.text('First Name'), findsNothing);
  });
}
