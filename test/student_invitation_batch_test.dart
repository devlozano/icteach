import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/student_invitation_batch.dart';
import 'package:icteach/services/student_invitation_service.dart';
import 'package:icteach/utils/student_email_csv_parser.dart';

void main() {
  final students = List.generate(
    3,
    (i) => StudentEmailRecord(email: 'student$i@example.com', row: i + 2),
  );
  test(
    'sends serially, blocks duplicate start, and stops after the in-flight student',
    () async {
      final gate = Completer<StudentInvitationResult>();
      final sent = <String>[];
      final batch = StudentInvitationBatch(
        students,
        spacing: Duration.zero,
        invite: (student) {
          sent.add(student.email);
          return gate.future;
        },
      );
      final run = batch.send();
      await batch.send();
      expect(sent, hasLength(1));
      batch.stop();
      gate.complete(const StudentInvitationResult());
      await run;
      expect(batch.count(InvitationStatus.sent), 1);
      expect(batch.count(InvitationStatus.pending), 2);
      expect(batch.running, false);
      batch.dispose();
    },
  );
  test(
    'continues row-specific failures and retries only failed rows',
    () async {
      final calls = <String>[];
      var fail = true;
      final batch = StudentInvitationBatch(
        students,
        spacing: Duration.zero,
        invite: (student) async {
          calls.add(student.email);
          if (student == students[1] && fail) {
            throw const StudentInvitationException(
              'Non-student account',
              stopBatch: false,
            );
          }
          return StudentInvitationResult(skipped: student == students[2]);
        },
      );
      await batch.send();
      expect(batch.count(InvitationStatus.sent), 1);
      expect(batch.count(InvitationStatus.failed), 1);
      expect(batch.count(InvitationStatus.skipped), 1);
      fail = false;
      await batch.send(retryFailed: true);
      expect(calls, [
        'student0@example.com',
        'student1@example.com',
        'student2@example.com',
        'student1@example.com',
      ]);
      expect(batch.count(InvitationStatus.sent), 2);
      batch.dispose();
    },
  );
  test(
    'service failure stops the queue without reporting unsent students as sent',
    () async {
      final batch = StudentInvitationBatch(
        students,
        spacing: Duration.zero,
        invite: (_) async {
          throw const StudentInvitationException('Service unavailable');
        },
      );
      await batch.send();
      expect(batch.count(InvitationStatus.failed), 1);
      expect(batch.count(InvitationStatus.pending), 2);
      expect(batch.count(InvitationStatus.sent), 0);
      expect(batch.stopReason, 'Service unavailable');
      batch.dispose();
    },
  );
  test(
    'disposing during a request prevents further sends and notifications',
    () async {
      final gate = Completer<StudentInvitationResult>();
      var calls = 0;
      final batch = StudentInvitationBatch(
        students,
        spacing: Duration.zero,
        invite: (_) {
          calls++;
          return gate.future;
        },
      );
      final run = batch.send();
      batch.dispose();
      gate.complete(const StudentInvitationResult());
      await run;
      expect(calls, 1);
    },
  );
}
