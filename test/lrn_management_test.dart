import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/lrn_management_service.dart';
import 'package:icteach/services/lrn_csv_import_service.dart';
import 'package:icteach/utils/lrn_csv_parser.dart';
import 'package:icteach/widgets/lrn_folder_browser.dart';

void main() {
  test(
    'folder imports, moves, and deletion preserve claimed LRNs and accounts',
    () async {
      final db = FakeFirebaseFirestore();
      final service = LrnManagementService(firestore: db);
      final folder = await service.createFolder('  Grade 12  ', kind: 'class');
      expect(
        (await db.collection('lrn_folders').doc(folder).get()).data()!['name'],
        'Grade 12',
      );
      expect(
        (await db.collection('lrn_folders').doc(folder).get()).data()!['kind'],
        'class',
      );
      final importer = LrnCsvImportService(firestore: db, folderId: folder);
      final rows = [
        const LrnCsvRecord('123456789012', 'Ana', 'Cruz', ''),
        const LrnCsvRecord('123456789013', 'Ben', 'Reyes', ''),
      ];
      expect((await importer.importRecords(rows)).added, 2);
      final pending = db.collection('lrn_master_list').doc(rows[0].lrn);
      final registered = db.collection('lrn_master_list').doc(rows[1].lrn);
      expect((await pending.get()).data()!['folderId'], folder);
      await registered.update({
        'isRegistered': true,
        'registeredUid': 'student',
      });
      await db.collection('users').doc('student').set({'role': 'student'});
      await service.move(rows[1].lrn, '');
      expect((await registered.get()).data()!['registeredUid'], 'student');
      await service.delete(rows[0].lrn);
      expect((await pending.get()).exists, isFalse);
      await service.delete(rows[1].lrn);
      expect((await registered.get()).data()!['archived'], true);
      expect((await db.collection('users').doc('student').get()).exists, true);
      expect((await importer.importRecords([rows[1]])).skipped, 1);
      expect((await registered.get()).data()!['isRegistered'], true);
    },
  );

  test(
    'deleting a batch folder removes pending LRNs and archives claims',
    () async {
      final db = FakeFirebaseFirestore();
      final service = LrnManagementService(firestore: db);
      final folder = await service.createFolder('Batch 2026', kind: 'batch');
      await db.collection('lrn_master_list').doc('123456789012').set({
        'firstName': 'Ana',
        'lastName': 'Cruz',
        'isRegistered': false,
        'folderId': folder,
      });
      await db.collection('lrn_master_list').doc('123456789013').set({
        'firstName': 'Ben',
        'lastName': 'Reyes',
        'isRegistered': true,
        'registeredUid': 'student',
        'folderId': folder,
      });

      expect(await service.deleteFolder(folder), 2);
      expect(
        (await db.collection('lrn_folders').doc(folder).get()).exists,
        isFalse,
      );
      expect(
        (await db.collection('lrn_master_list').doc('123456789012').get())
            .exists,
        isFalse,
      );
      final claimed =
          (await db.collection('lrn_master_list').doc('123456789013').get())
              .data()!;
      expect(claimed['archived'], true);
      expect(claimed['registeredUid'], 'student');
    },
  );

  testWidgets(
    'legacy records are Unfiled; folders filter records; delete requires confirmation',
    (tester) async {
      final db = FakeFirebaseFirestore();
      await db.collection('lrn_folders').doc('a').set({
        'name': 'Class A',
        'kind': 'class',
      });
      await db.collection('lrn_master_list').doc('123456789012').set({
        'firstName': 'Ana',
        'lastName': 'Cruz',
        'isRegistered': false,
      });
      await db.collection('lrn_master_list').doc('123456789013').set({
        'firstName': 'Ben',
        'lastName': 'Reyes',
        'isRegistered': false,
        'folderId': 'a',
      });
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LrnFolderBrowser(
                firestore: db,
                enabled: true,
                onFolderChanged: (id, _) {
                  selected = id;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('123456789012'), findsOneWidget);
      expect(find.text('123456789013'), findsNothing);
      await tester.tap(find.text('Class: Class A (1)'));
      await tester.pumpAndSettle();
      expect(selected, 'a');
      expect(find.text('123456789013'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete LRN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(
        (await db.collection('lrn_master_list').doc('123456789013').get())
            .exists,
        true,
      );
      await tester.tap(find.byTooltip('Delete LRN'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(
        (await db.collection('lrn_master_list').doc('123456789013').get())
            .exists,
        false,
      );
      expect(find.textContaining('This folder is empty.'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete Class A folder and its LRNs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete folder and LRNs'));
      await tester.pumpAndSettle();
      expect((await db.collection('lrn_folders').doc('a').get()).exists, false);
      expect(find.text('Unfiled / 1 LRN records'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('folder browser fits a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = FakeFirebaseFirestore();
    await db.collection('lrn_master_list').doc('123456789012').set({
      'firstName': 'Ana',
      'lastName': 'Cruz',
      'isRegistered': true,
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LrnFolderBrowser(
              firestore: db,
              enabled: true,
              onFolderChanged: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Delete LRN'), findsOneWidget);
  });
}
