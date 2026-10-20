import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/screens/teacher/student_email_upload_page.dart';
import 'package:icteach/services/student_invitation_service.dart';

void main() {
  for (final size in [
    const Size(360, 640),
    const Size(740, 360),
    const Size(1280, 800),
  ]) {
    testWidgets('upload previews before sending and fits $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sent = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: StudentEmailUploadPage(
            classId: 'class',
            className: 'Grade 10 - Section A',
            pickCsv: () async => (
              name: 'students.csv',
              bytes: utf8.encode(
                'Gmail,First Name,Last Name\nlearner@gmail.com,Ana,Santos\nLEARNER@gmail.com,Ana,Santos',
              ),
            ),
            invite: (student) async {
              sent.add(student.email);
              return const StudentInvitationResult();
            },
          ),
        ),
      );
      await tester.tap(find.text('Upload Gmail CSV'));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(find.textContaining('1 unique students'), findsOneWidget);
      expect(find.textContaining('1 duplicate row was'), findsOneWidget);
      await tester.tap(find.text('Send invitations (1)'));
      await tester.pumpAndSettle();
      expect(sent, ['learner@gmail.com']);
      expect(find.text('Back to class roster'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('invalid file cannot send invitations', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StudentEmailUploadPage(
          classId: 'class',
          className: 'Class',
          pickCsv: () async =>
              (name: 'bad.csv', bytes: utf8.encode('Gmail\ninvalid')),
          invite: (_) async {
            calls++;
            return const StudentInvitationResult();
          },
        ),
      ),
    );
    await tester.tap(find.text('Upload Gmail CSV'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Row 2:'), findsOneWidget);
    expect(find.textContaining('Send invitations ('), findsNothing);
    expect(calls, 0);
  });
  testWidgets(
    'active upload blocks replacing the file and safely stops remaining rows',
    (tester) async {
      final gate = Completer<StudentInvitationResult>();
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: StudentEmailUploadPage(
            classId: 'class',
            className: 'Class',
            pickCsv: () async => (
              name: 'students.csv',
              bytes: utf8.encode('Gmail\na@example.com\nb@example.com'),
            ),
            invite: (_) {
              calls++;
              return gate.future;
            },
          ),
        ),
      );
      await tester.tap(find.text('Upload Gmail CSV'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Send invitations (2)'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Upload Gmail CSV'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Stop after current student'));
      await tester.pump();
      gate.complete(const StudentInvitationResult());
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('Send invitations (1)'), findsOneWidget);
    },
  );
  testWidgets(
    'closing the page while the picker fails does not update disposed state',
    (tester) async {
      final selection = Completer<({String name, List<int> bytes})?>();
      await tester.pumpWidget(
        MaterialApp(
          home: StudentEmailUploadPage(
            classId: 'class',
            className: 'Class',
            pickCsv: () => selection.future,
          ),
        ),
      );
      await tester.tap(find.text('Upload Gmail CSV'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      selection.completeError(const FormatException('Invalid file'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
