import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:icteach/admin/manage_teachers_page.dart';
import 'package:icteach/admin/manage_trainers_page.dart';
import 'package:icteach/widgets/admin_delete_staff_button.dart';

void main() {
  for (final role in ['teacher', 'trainer']) {
    testWidgets('Admin ' + role + ' list exposes account deletion', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('staff').set({
        'role': role,
        'name': 'Staff Member',
        'email': 'staff@example.test',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: role == 'teacher'
              ? ManageTeachersPage(firestore: db)
              : ManageTrainersPage(firestore: db),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete account'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Permanently delete Staff Member'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect((await db.collection('users').doc('staff').get()).exists, true);
    });
  }
  testWidgets('failed deletion remains retryable and never silently closes', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminDeleteStaffButton(
            uid: 'staff',
            role: 'trainer',
            name: 'Trainer',
            onDelete: () async {
              calls++;
              if (calls == 1) throw StateError('Authorization required');
            },
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Delete account'));
    await tester.pumpAndSettle();
    expect(calls, 0);
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    expect(find.text('Authorization required'), findsOneWidget);
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
