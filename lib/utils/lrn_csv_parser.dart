import 'dart:convert';

class LrnCsvRecord {
  final String lrn, firstName, lastName, middleName;
  const LrnCsvRecord(this.lrn, this.firstName, this.lastName, this.middleName);
  Map<String, dynamic> get names => {
    'firstName': firstName,
    'lastName': lastName,
    'middleName': middleName,
  };
}

class LrnCsvParser {
  static const maxBytes = 5 * 1024 * 1024;
  static const maxRecords = 10000;
  static final _lrn = RegExp(r'^[0-9]{12}$');

  static List<LrnCsvRecord> parseBytes(List<int> bytes) {
    if (bytes.isEmpty) throw const FormatException('The CSV file is empty.');
    if (bytes.length > maxBytes)
      throw const FormatException('CSV files must be 5 MB or smaller.');
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      throw const FormatException(
        'Save the file as CSV UTF-8, then upload it again.',
      );
    }
    final rows = _readRows(text.replaceFirst(RegExp(r'^\uFEFF'), ''));
    if (rows.isEmpty)
      throw const FormatException('The CSV file has no records.');
    String header(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'[\s_-]'), '');
    final first = rows.first.map(header).toList();
    final hasHeader = first.contains('lrn');
    var columns = <String, int>{
      'lrn': 0,
      'firstname': 1,
      'lastname': 2,
      'middlename': 3,
    };
    if (hasHeader) {
      columns = {};
      for (var i = 0; i < first.length; i++) {
        if (columns.containsKey(first[i]))
          throw FormatException('Duplicate header: ${rows.first[i]}.');
        columns[first[i]] = i;
      }
      if (!['lrn', 'firstname', 'lastname'].every(columns.containsKey)) {
        throw const FormatException(
          'Headers must include LRN, First Name and Last Name; Middle Name is optional.',
        );
      }
    }
    final records = <LrnCsvRecord>[];
    final seen = <String>{};
    for (var i = hasHeader ? 1 : 0; i < rows.length; i++) {
      final row = rows[i];
      if ((hasHeader && row.length != first.length) ||
          (!hasHeader && (row.length < 3 || row.length > 4))) {
        throw FormatException(
          'CSV record ${i + 1}: incorrect column count. Put names containing commas inside double quotes.',
        );
      }
      String field(String key) {
        final index = columns[key];
        return index == null || index >= row.length ? '' : row[index].trim();
      }

      final lrn = field('lrn');
      if (!_lrn.hasMatch(lrn))
        throw FormatException(
          'CSV record ${i + 1}: LRN must contain exactly 12 digits. Set the LRN column format to General in Excel, then save as CSV UTF-8. Verify that all 12 digits are saved; scientific notation is not accepted.',
        );
      if (!seen.add(lrn))
        throw FormatException(
          'CSV record ${i + 1}: duplicate LRN within the file. Remove duplicate rows and retry.',
        );
      final names = [
        'firstname',
        'lastname',
        'middlename',
      ].map((key) => field(key).replaceAll(RegExp(r'\s+'), ' ')).toList();
      if (names[0].isEmpty || names[1].isEmpty)
        throw FormatException(
          'CSV record ${i + 1}: First Name and Last Name are required.',
        );
      if (names.any((name) => name.length > 150))
        throw FormatException(
          'CSV record ${i + 1}: each name must be at most 150 characters.',
        );
      records.add(LrnCsvRecord(lrn, names[0], names[1], names[2]));
      if (records.length > maxRecords)
        throw const FormatException(
          'Import at most 10,000 records per CSV file.',
        );
    }
    if (records.isEmpty)
      throw const FormatException(
        'The CSV contains headers but no student records.',
      );
    return List.unmodifiable(records);
  }

  // CSV state machine: quoted commas/newlines and doubled quotes are data.
  static List<List<String>> _readRows(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false, closed = false;
    void endField() {
      row.add(field.toString());
      field = StringBuffer();
      closed = false;
    }

    void endRow() {
      endField();
      if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
      row = [];
      if (rows.length > maxRecords + 1)
        throw const FormatException(
          'Import at most 10,000 records per CSV file.',
        );
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      if (quoted) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          field.write(c);
        }
      } else if (c == ',') {
        endField();
      } else if (c == '\n' || c == '\r') {
        endRow();
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      } else if (c == '"') {
        if (closed || field.toString().trim().isNotEmpty)
          throw const FormatException(
            'Unexpected quote in CSV. Escape quotes inside names as two double quotes.',
          );
        field = StringBuffer();
        quoted = true;
      } else if (closed) {
        if (c != ' ' && c != '\t')
          throw const FormatException(
            'Unexpected text after a quoted CSV field.',
          );
      } else {
        field.write(c);
      }
    }
    if (quoted)
      throw const FormatException('The CSV contains an unclosed quoted field.');
    if (field.isNotEmpty || row.isNotEmpty || closed) endRow();
    return rows;
  }
}
