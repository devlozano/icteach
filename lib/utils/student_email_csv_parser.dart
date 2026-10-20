import 'dart:convert';
import 'csv_rows.dart';

class StudentEmailRecord {
  const StudentEmailRecord({
    required this.email,
    this.firstName = '',
    this.lastName = '',
    required this.row,
  });
  final String email, firstName, lastName;
  final int row;
  String get displayName =>
      [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
}

class StudentEmailCsv {
  const StudentEmailCsv(this.records, this.duplicates);
  final List<StudentEmailRecord> records;
  final int duplicates;
}

class StudentEmailCsvParser {
  static const maxBytes = 1024 * 1024;
  static const maxRecords = 100;
  static const template = 'Gmail,First Name,Last Name\r\n';
  static final _email = RegExp(
    r'^[a-z0-9.!#$%&\x27*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$',
  );

  static StudentEmailCsv parseBytes(List<int> bytes) {
    if (bytes.isEmpty) throw const FormatException('The CSV file is empty.');
    if (bytes.length > maxBytes) {
      throw const FormatException('Upload a CSV of 1 MB or smaller.');
    }
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const FormatException(
        'Save the spreadsheet as CSV UTF-8 and upload it again.',
      );
    }
    final rows = CsvRows.parse(
      text.replaceFirst(RegExp(r'^\uFEFF'), ''),
      maxRecords: maxRecords,
      limitMessage: 'Upload at most 100 students per file.',
    );
    if (rows.isEmpty) {
      throw const FormatException('The CSV file has no student addresses.');
    }
    String header(String value) {
      final key = value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
      return switch (key) {
        'gmail' ||
        'gmailaccount' ||
        'gmailaddress' ||
        'emailaddress' ||
        'studentemail' => 'email',
        _ => key,
      };
    }

    final headers = rows.first.map(header).toList();
    final hasHeader = headers.contains('email');
    var columns = <String, int>{'email': 0, 'firstname': 1, 'lastname': 2};
    if (hasHeader) {
      columns = {};
      for (var i = 0; i < headers.length; i++) {
        if (!['email', 'firstname', 'lastname'].contains(headers[i])) {
          throw FormatException(
            'Unknown column "${rows.first[i]}". Use Gmail, First Name, Last Name. Names are optional; no LRN is needed.',
          );
        }
        if (columns.containsKey(headers[i])) {
          throw FormatException('Duplicate column: ${rows.first[i]}.');
        }
        columns[headers[i]] = i;
      }
    }
    final records = <StudentEmailRecord>[];
    final seen = <String>{};
    var duplicates = 0;
    for (var index = hasHeader ? 1 : 0; index < rows.length; index++) {
      final row = rows[index];
      final number = index + 1;
      if ((hasHeader && row.length != headers.length) ||
          (!hasHeader && (row.isEmpty || row.length > 3))) {
        throw FormatException(
          'Row $number: incorrect number of columns. Put names containing commas inside double quotes.',
        );
      }
      String field(String key) {
        final position = columns[key];
        return position == null || position >= row.length
            ? ''
            : row[position].trim();
      }

      final address = field('email').toLowerCase();
      final local = address.split('@').first;
      if (address.length > 254 ||
          local.length > 64 ||
          local.startsWith('.') ||
          local.endsWith('.') ||
          local.contains('..') ||
          !_email.hasMatch(address)) {
        throw FormatException(
          'Row $number: enter a valid Gmail or school email address. Upload addresses, not LRNs or passwords.',
        );
      }
      final first = field('firstname').replaceAll(RegExp(r'\s+'), ' ');
      final last = field('lastname').replaceAll(RegExp(r'\s+'), ' ');
      if (first.length > 80 || last.length > 80) {
        throw FormatException(
          'Row $number: names must be 80 characters or fewer.',
        );
      }
      if (seen.add(address)) {
        records.add(
          StudentEmailRecord(
            email: address,
            firstName: first,
            lastName: last,
            row: number,
          ),
        );
      } else {
        duplicates++;
      }
      if (records.length + duplicates > maxRecords) {
        throw const FormatException('Upload at most 100 students per file.');
      }
    }
    if (records.isEmpty) {
      throw const FormatException(
        'Add student addresses below the header before uploading.',
      );
    }
    return StudentEmailCsv(List.unmodifiable(records), duplicates);
  }
}
