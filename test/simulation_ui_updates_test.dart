import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:icteach/admin/manage_teachers_page.dart';
import 'package:icteach/admin/manage_trainers_page.dart';
import 'package:icteach/widgets/simulation_motion.dart';

void main() {
  for (final role in ['teacher', 'trainer']) {
    testWidgets('Embedded ' + role + ' list keeps one admin shell', (
      tester,
    ) async {
      final db = FakeFirebaseFirestore();
      await db.collection('users').doc('staff').set({
        'role': role,
        'name': 'Test Staff',
        'email': 'staff@example.com',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Admin workspace')),
            body: SingleChildScrollView(
              child: role == 'teacher'
                  ? ManageTeachersPage(embedded: true, firestore: db)
                  : ManageTrainersPage(embedded: true, firestore: db),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.text('Test Staff'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Placement motion settles and honors reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SimulationPlacementMotion(
            identity: 'placed',
            child: Text('Placed'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    expect(tester.takeException(), isNull);
  });
}
