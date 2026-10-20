import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../services/student_invitation_batch.dart';
import '../../services/student_invitation_service.dart';
import '../../utils/student_email_csv_parser.dart';

typedef PickStudentCsv = Future<({String name, List<int> bytes})?> Function();

class StudentEmailUploadPage extends StatefulWidget {
  const StudentEmailUploadPage({
    super.key,
    required this.classId,
    required this.className,
    this.pickCsv,
    this.invite,
  });
  final String classId, className;
  final PickStudentCsv? pickCsv;
  final InviteStudent? invite;
  @override
  State<StudentEmailUploadPage> createState() => _StudentEmailUploadPageState();
}

class _StudentEmailUploadPageState extends State<StudentEmailUploadPage> {
  StudentInvitationBatch? _batch;
  String? _fileName, _error;
  int _duplicates = 0;
  bool _picking = false, _saving = false;

  @override
  void dispose() {
    _batch?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<({String name, List<int> bytes})?> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > StudentEmailCsvParser.maxBytes) {
      throw const FormatException('Upload a CSV of 1 MB or smaller.');
    }
    if (file.bytes == null) {
      throw const FormatException(
        'Unable to read this file. Download it to your device and select it again.',
      );
    }
    return (name: file.name, bytes: file.bytes!);
  }

  Future<void> _upload() async {
    if (_picking || (_batch?.running ?? false)) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final file = await (widget.pickCsv ?? _pickFile)();
      if (!mounted || file == null) return;
      _batch?.dispose();
      _batch = null;
      _fileName = null;
      final parsed = StudentEmailCsvParser.parseBytes(file.bytes);
      final batch = StudentInvitationBatch(
        parsed.records,
        invite:
            widget.invite ??
            (student) => StudentInvitationService.invite(
              classId: widget.classId,
              email: student.email,
              firstName: student.firstName,
              lastName: student.lastName,
              skipIfAlreadyInvited: true,
            ),
      );
      batch.addListener(_changed);
      setState(() {
        _batch = batch;
        _fileName = file.name;
        _duplicates = parsed.duplicates;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      _batch?.dispose();
      _batch = null;
      _fileName = null;
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to open this CSV. Download the file and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _template() async {
    setState(() => _saving = true);
    try {
      await FilePicker.saveFile(
        dialogTitle: 'Save Gmail CSV template',
        fileName: 'student_gmail_template.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: Uint8List.fromList(utf8.encode(StudentEmailCsvParser.template)),
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not save the template. Create a CSV with headers: Gmail, First Name, Last Name.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final batch = _batch;
    final running = batch?.running ?? false;
    final pending = batch?.count(InvitationStatus.pending) ?? 0;
    final failed = batch?.count(InvitationStatus.failed) ?? 0;
    return PopScope(
      canPop: !running,
      child: Scaffold(
        appBar: AppBar(title: const Text('Upload Gmail accounts')),
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.className,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Upload student Gmail or school email addresses to invite them to this class. No LRN or password is needed.',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: running || _picking ? null : _upload,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            _picking ? 'Reading CSV…' : 'Upload Gmail CSV',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _saving || running ? null : _template,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Download template'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (batch == null)
                      const Text(
                        'CSV UTF-8 • Maximum 1 MB / 100 students. Required column: Gmail (Email also works). First Name and Last Name are optional.',
                      ),
                    const SizedBox(height: 8),
                    Text(
                      batch == null
                          ? 'Review the list below, then choose Send invitations. Students receive an email to set their own password.'
                          : 'Review the addresses below before sending invitations.',
                    ),
                    if (_error != null) _notice(_error!, error: true),
                    if (batch != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        '$_fileName • ${batch.rows.length} unique students',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (_duplicates > 0)
                        Text(
                          '$_duplicates duplicate ${_duplicates == 1 ? 'row was' : 'rows were'} removed from this upload.',
                        ),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          '${batch.count(InvitationStatus.sent)} sent • ${batch.count(InvitationStatus.skipped)} already invited • $failed not sent/confirmed • $pending pending',
                        ),
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: batch.completed / batch.rows.length,
                      ),
                      if (batch.stopReason != null)
                        _notice(batch.stopReason!, error: true),
                      if (running)
                        _notice(
                          batch.stopRequested
                              ? 'Stopping after the current student. Keep this page open until the request finishes.'
                              : 'Sending one invitation at a time. Keep this page open; you can stop after the current student.',
                        ),
                      if (failed > 0 && !running)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Check inboxes for unconfirmed deliveries before retrying. Successful invitations will not be resent.',
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            if (batch != null)
              SliverList.builder(
                itemCount: batch.rows.length,
                itemBuilder: (context, index) {
                  final row = batch.rows[index];
                  final (icon, label, color) = switch (row.status) {
                    InvitationStatus.pending => (
                      Icons.mail_outline,
                      'Ready to invite',
                      Colors.blueGrey,
                    ),
                    InvitationStatus.sending => (
                      Icons.hourglass_top,
                      'Sending…',
                      Colors.blue,
                    ),
                    InvitationStatus.sent => (
                      Icons.mark_email_read_outlined,
                      'Sent',
                      Colors.green,
                    ),
                    InvitationStatus.skipped => (
                      Icons.person_outline,
                      'Already invited',
                      Colors.blueGrey,
                    ),
                    InvitationStatus.failed => (
                      Icons.error_outline,
                      'Not sent / not confirmed',
                      Colors.red,
                    ),
                  };
                  return Card(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ListTile(
                      leading: Icon(icon, color: color),
                      title: Text(row.student.email),
                      subtitle: Text(
                        [
                          if (row.student.displayName.isNotEmpty)
                            row.student.displayName,
                          'CSV row ${row.student.row} • $label',
                          if (row.message != null) row.message!,
                        ].join('\n'),
                      ),
                    ),
                  );
                },
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
          ],
        ),
        bottomNavigationBar: batch == null
            ? null
            : SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (running)
                        OutlinedButton.icon(
                          onPressed: batch.stopRequested ? null : batch.stop,
                          icon: const Icon(Icons.stop_circle_outlined),
                          label: const Text('Stop after current student'),
                        ),
                      if (!running && pending > 0)
                        FilledButton.icon(
                          onPressed: _picking ? null : () => batch.send(),
                          icon: const Icon(Icons.send_outlined),
                          label: Text('Send invitations ($pending)'),
                        ),
                      if (!running && failed > 0)
                        OutlinedButton.icon(
                          onPressed: _picking
                              ? null
                              : () => batch.send(retryFailed: true),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry failed and remaining'),
                        ),
                      if (!running && pending == 0 && failed == 0)
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Back to class roster'),
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _notice(String text, {bool error = false}) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: TextStyle(
          color: error ? Theme.of(context).colorScheme.error : null,
        ),
      ),
    ),
  );
}
