import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:icteach/admin/principal_users_panel.dart';
import 'package:icteach/admin/create_staff_page.dart';
import 'package:icteach/admin/staff_assignment_fields.dart';
import 'package:icteach/services/principal_assignments.dart';

void main() {
  testWidgets(
    'default list includes active and inactive users and filters by search',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('t').set({
        'name': 'Teacher One',
        'role': 'teacher',
        'isActive': true,
      });
      await db.collection('users').doc('r').set({
        'name': 'Trainer Two',
        'role': 'trainer',
        'isActive': false,
      });
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PrincipalUsersPanel(firestore: db),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Teacher One'), findsOneWidget);
      expect(find.text('Trainer Two'), findsOneWidget);
      expect(find.text('All'), findsNWidgets(2));
      await tester.enterText(find.byType(TextField), 'Trainer');
      await tester.pumpAndSettle();
      expect(find.text('Teacher One'), findsNothing);
      expect(find.text('Trainer Two'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Add User starts at role selection and Teacher reveals section fields',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CreateStaffPage()));
      expect(find.byType(TextFormField), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teacher').last);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-count')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('section-count')));
      await tester.enterText(find.byKey(const ValueKey('section-count')), '2');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('section-name-1')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'trainer sees only chosen teachers classes and switching clears selection',
    (tester) async {
      final db = FakeFirebaseFirestore();
      for (final id in ['A', 'B']) {
        await db.collection('users').doc(id).set({
          'name': 'Teacher $id',
          'role': 'teacher',
          'isActive': true,
        });
        await db.collection('classes').doc(id).set({
          'name': 'Class $id',
          'teacherId': id,
          'status': 'active',
          'sectionCode': id,
        });
      }
      final draft = StaffAssignmentDraft();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                child: StaffAssignmentFields(
                  role: 'trainer',
                  draft: draft,
                  firestore: db,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teacher A').last);
      await tester.pumpAndSettle();
      expect(find.text('Class A - A'), findsOneWidget);
      expect(find.text('Class B - B'), findsNothing);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(draft.classIds, {'A'});
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Teacher B').last);
      await tester.pumpAndSettle();
      expect(draft.classIds, isEmpty);
      expect(find.text('Class B - B'), findsOneWidget);
    },
  );
}
