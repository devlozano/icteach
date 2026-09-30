import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/account_settings_section.dart';

void main() {
  testWidgets('profile settings expose practical account actions', (
    tester,
  ) async {
    var loggedOut = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSettingsSection(
            email: 'learner@example.com',
            role: 'student',
            accountDetails: const {
              'Name': 'Sample Learner',
              'Email': 'learner@example.com',
              'Role': 'Student',
              'LRN': '123456789012',
            },
            onLogout: () => loggedOut = true,
          ),
        ),
      ),
    );

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Account information'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);

    await tester.tap(find.text('Account information'));
    await tester.pumpAndSettle();
    expect(find.text('Sample Learner'), findsOneWidget);
    expect(find.text('123456789012'), findsOneWidget);
    expect(find.textContaining('read-only'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Logout'));
    expect(loggedOut, isTrue);
  });

  testWidgets('desktop staff settings can omit duplicate logout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountSettingsSection(
            email: 'teacher@example.com',
            role: 'teacher',
            accountDetails: const {'Role': 'Teacher'},
            onLogout: () {},
            showLogout: false,
          ),
        ),
      ),
    );

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Logout'), findsNothing);
  });
}
