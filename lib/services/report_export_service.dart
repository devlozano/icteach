import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

class ReportExportService {
  static String encodeCsv(List<List<Object?>> rows) => rows
      .map(
        (row) => row
            .map((value) {
              var text = value?.toString() ?? '';
              // Prevent spreadsheet formula execution when a learner name begins with a formula prefix.
              if (RegExp(r'^\s*[=+@-]').hasMatch(text) ||
                  text.startsWith('\t') ||
                  text.startsWith('\r')) {
                text = "'$text";
              }
              return '"${text.replaceAll('"', '""')}"';
            })
            .join(','),
      )
      .join('\r\n');
  static Future<void> shareCsv(
    String filename,
    List<List<Object?>> rows,
  ) async {
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF${encodeCsv(rows)}'));
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv', name: filename)],
        fileNameOverrides: [filename],
      ),
    );
  }

  static Future<bool> downloadCsv(
    String filename,
    List<List<Object?>> rows,
  ) async {
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF${encodeCsv(rows)}'));
    final path = await FilePicker.saveFile(
      dialogTitle: 'Download student grades',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
      bytes: bytes,
    );
    // Web browsers do not return a local path after a successful download.
    return path != null || kIsWeb;
  }
}
