import 'package:flutter/foundation.dart';
import '../utils/student_email_csv_parser.dart';
import 'student_invitation_service.dart';

enum InvitationStatus { pending, sending, sent, skipped, failed }

class StudentInvitationRow {
  StudentInvitationRow(this.student);
  final StudentEmailRecord student;
  InvitationStatus status = InvitationStatus.pending;
  String? message;
}

typedef InviteStudent =
    Future<StudentInvitationResult> Function(StudentEmailRecord student);

/// Sends one request at a time and never automatically retries an uncertain send.
class StudentInvitationBatch extends ChangeNotifier {
  StudentInvitationBatch(
    List<StudentEmailRecord> students, {
    required this.invite,
    this.spacing = const Duration(milliseconds: 1100),
  }) : rows = students.map(StudentInvitationRow.new).toList(growable: false);
  final List<StudentInvitationRow> rows;
  final InviteStudent invite;
  final Duration spacing;
  bool running = false, stopRequested = false, _disposed = false;
  String? stopReason;
  int count(InvitationStatus status) =>
      rows.where((r) => r.status == status).length;
  int get completed =>
      count(InvitationStatus.sent) +
      count(InvitationStatus.skipped) +
      count(InvitationStatus.failed);

  void stop() {
    stopRequested = true;
    _changed();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    stopRequested = true;
    super.dispose();
  }

  Future<void> send({bool retryFailed = false}) async {
    if (running || _disposed) return;
    running = true;
    stopRequested = false;
    stopReason = null;
    if (retryFailed) {
      for (final row in rows.where(
        (r) => r.status == InvitationStatus.failed,
      )) {
        row.status = InvitationStatus.pending;
        row.message = null;
      }
    }
    _changed();
    var attempted = false;
    try {
      for (final row in rows) {
        if (stopRequested || _disposed) break;
        if (row.status != InvitationStatus.pending) continue;
        if (attempted) await Future<void>.delayed(spacing);
        if (stopRequested || _disposed) break;
        row.status = InvitationStatus.sending;
        row.message = null;
        _changed();
        attempted = true;
        try {
          final result = await invite(row.student);
          row.status = result.skipped
              ? InvitationStatus.skipped
              : InvitationStatus.sent;
          row.message = result.skipped
              ? 'Already enrolled or invited to this class.'
              : 'Invitation accepted by the email service.';
        } catch (error) {
          row.status = InvitationStatus.failed;
          row.message = error is StudentInvitationException
              ? error.message
              : 'Delivery was not confirmed. Check the connection and student inbox before retrying.';
          if (error is! StudentInvitationException || error.stopBatch) {
            stopReason = row.message;
            stopRequested = true;
          }
        }
        _changed();
      }
    } finally {
      running = false;
      _changed();
    }
  }
}
