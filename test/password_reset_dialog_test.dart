import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/password_reset_dialog.dart';

void main() {
  testWidgets(
    'validates email and sends a trimmed address without a password',
    (tester) async {
      String? sent;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PasswordResetDialog(
              sendReset: (email) async {
                sent = email;
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(sent, isNull);
      await tester.enterText(
        find.byType(TextFormField),
        ' teacher@example.com ',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(sent, 'teacher@example.com');
      expect(find.text('Check your email'), findsOneWidget);
      expect(
        find.textContaining('open the link to choose a new password'),
        findsOneWidget,
      );
    },
  );
  testWidgets('blocks duplicate sends and allows retry after a network error', (
    tester,
  ) async {
    final pending = Completer<void>();
    int calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasswordResetDialog(
            initialEmail: 'trainer@example.com',
            sendReset: (_) {
              calls++;
              return calls == 1 ? pending.future : Future.value();
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(calls, 1);
    pending.completeError(
      FirebaseAuthException(code: 'network-request-failed'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Check your connection and try again.'), findsOneWidget);
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Check your email'), findsOneWidget);
  });
  testWidgets('unknown accounts receive the same neutral result', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PasswordResetDialog(
            initialEmail: 'student@example.com',
            sendReset: (_) async {
              throw FirebaseAuthException(code: 'user-not-found');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsOneWidget);
  });
  testWidgets(
    'dialog fits a narrow phone and can close during a pending request',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => PasswordResetDialog(
                    initialEmail: 'student@example.com',
                    sendReset: (_) => pending.future,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
