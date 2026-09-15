import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/widgets/system_survey_flow.dart';
import 'package:icteach/widgets/delete_trainer_account_dialog.dart';
import 'package:icteach/services/trainer_account_deletion.dart';

void main() {
  Future<void> openSurvey(
    WidgetTester tester, {
    bool fail = false,
    Map<int, int> initial = const {},
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SystemSurveyFlow(
            initialRatings: initial,
            initialComment: '',
            onSave: (ratings, comment) async {
              if (fail) throw Exception('offline');
            },
          ),
        ),
      ),
    );
    await tester.tap(
      find.text(initial.isEmpty ? 'Start Survey' : 'Update Survey'),
    );
    await tester.pumpAndSettle();
  }

  Future<void> answerAll(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('Strongly Agree'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('Survey requires answers and submits directly to saved results', (
    tester,
  ) async {
    await openSurvey(tester);
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Next'),
    );
    expect(button.onPressed, isNull);
    await answerAll(tester);
    expect(find.text('5 of 5'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'More examples');
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Survey Results'), findsOneWidget);
    expect(find.text('Thank You!'), findsNothing);
    expect(find.text('5/5'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Failed save retains answers and permits retry', (tester) async {
    await openSurvey(tester, fail: true);
    await answerAll(tester);
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not save'), findsOneWidget);
    expect(find.text('Survey Results'), findsNothing);
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });
  testWidgets('Saved results do not display unsaved edits', (tester) async {
    await openSurvey(tester, initial: {0: 3, 1: 3, 2: 3, 3: 3});
    await tester.tap(find.text('Strongly Agree'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('View Results'));
    await tester.tap(find.text('View Results'));
    await tester.pumpAndSettle();
    expect(find.text('3/5'), findsWidgets);
    expect(find.text('5/5'), findsNothing);
  });
  for (final size in [const Size(360, 640), const Size(740, 360)]) {
    testWidgets('Survey fits ' + size.toString(), (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SystemSurveyFlow(
              initialRatings: const {},
              initialComment: '',
              onSave: (_, __) async {},
            ),
          ),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Start Survey'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Start Survey'));
      await tester.pumpAndSettle();
      expect(find.text('1 of 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'Deletion stops before changing data when reauthentication fails',
    () async {
      final calls = <String>[];
      await expectLater(
        TrainerAccountDeletion.run(
          reauthenticate: () async {
            throw Exception('password');
          },
          removeProfile: () async {
            calls.add('profile');
          },
          removeAccount: () async {
            calls.add('account');
          },
          restoreProfile: () async {
            calls.add('restore');
          },
        ),
        throwsException,
      );
      expect(calls, isEmpty);
    },
  );
  test('Deletion restores profile if Auth deletion fails', () async {
    final calls = <String>[];
    await expectLater(
      TrainerAccountDeletion.run(
        reauthenticate: () async {
          calls.add('reauth');
        },
        removeProfile: () async {
          calls.add('profile');
        },
        removeAccount: () async {
          calls.add('account');
          throw Exception('network');
        },
        restoreProfile: () async {
          calls.add('restore');
        },
      ),
      throwsException,
    );
    expect(calls, ['reauth', 'profile', 'account', 'restore']);
  });
  test('Successful deletion does not restore profile', () async {
    final calls = <String>[];
    await TrainerAccountDeletion.run(
      reauthenticate: () async {
        calls.add('reauth');
      },
      removeProfile: () async {
        calls.add('profile');
      },
      removeAccount: () async {
        calls.add('account');
      },
      restoreProfile: () async {
        calls.add('restore');
      },
    );
    expect(calls, ['reauth', 'profile', 'account']);
  });
  testWidgets('Delete dialog requires password and cancel does not delete', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                builder: (_) => DeleteTrainerAccountDialog(
                  onDelete: (_) async {
                    calls++;
                  },
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
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your current password.'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(DeleteTrainerAccountDialog), findsNothing);
    expect(calls, 0);
  });
  test('Profile deletion failure leaves the sign-in account intact', () async {
    var accountDeleted = false;
    await expectLater(
      TrainerAccountDeletion.run(
        reauthenticate: () async {},
        removeProfile: () async {
          throw Exception('permission-denied');
        },
        removeAccount: () async {
          accountDeleted = true;
        },
        restoreProfile: () async {},
      ),
      throwsException,
    );
    expect(accountDeleted, isFalse);
  });
  testWidgets('Confirmed deletion sends password and closes successfully', (
    tester,
  ) async {
    String? received;
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (_) => DeleteTrainerAccountDialog(
                    onDelete: (password) async {
                      received = password;
                    },
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Test-password');
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    expect(received, 'Test-password');
    expect(result, isTrue);
    expect(find.byType(DeleteTrainerAccountDialog), findsNothing);
  });
}
