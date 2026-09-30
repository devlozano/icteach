import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/staff_workspace_header.dart';

void main() {
  testWidgets('admin top bar can hide notifications without affecting layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StaffTopBar(
            name: 'Administrator',
            showMenuButton: false,
            showIdentity: false,
            showNotifications: false,
          ),
        ),
      ),
    );

    expect(find.byTooltip('Notifications'), findsNothing);
    expect(find.text('Administration Workspace'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
