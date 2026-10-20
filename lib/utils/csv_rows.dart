/// Strict CSV reader shared by the LRN and teacher email upload flows.
class CsvRows {
  // CSV state machine: quoted commas/newlines and doubled quotes are data.
  static List<List<String>> parse(
    String text, {
    required int maxRecords,
    required String limitMessage,
  }) {
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
      if (rows.length > maxRecords + 1) throw FormatException(limitMessage);
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
        if (closed || field.toString().trim().isNotEmpty) {
          throw const FormatException(
            'Unexpected quote in CSV. Escape quotes inside names as two double quotes.',
          );
        }
        field = StringBuffer();
        quoted = true;
      } else if (closed) {
        if (c != ' ' && c != '\t') {
          throw const FormatException(
            'Unexpected text after a quoted CSV field.',
          );
        }
      } else {
        field.write(c);
      }
    }
    if (quoted) {
      throw const FormatException('The CSV contains an unclosed quoted field.');
    }
    if (field.isNotEmpty || row.isNotEmpty || closed) endRow();
    return rows;
  }
}
