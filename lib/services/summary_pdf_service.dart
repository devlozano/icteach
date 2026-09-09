import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class SummarySection {
  final String title;
  final List<String> columns;
  final List<List<Object?>> rows;
  const SummarySection(this.title, this.columns, this.rows);
}

class SummaryPdfService {
  static Future<Uint8List> build({
    required String college,
    required String title,
    required List<SummarySection> sections,
    Uint8List? logo,
    DateTime? generatedAt,
  }) async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/roboto-regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/roboto-bold.ttf'),
    );
    final doc = pw.Document(
      title: title,
      author: college,
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    final generated = generatedAt ?? DateTime.now();
    final image = logo == null ? null : pw.MemoryImage(logo);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        maxPages: 500,
        header: (_) => pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 18),
          padding: const pw.EdgeInsets.only(bottom: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.teal)),
          ),
          child: pw.Row(
            children: [
              if (image != null) ...[
                pw.Image(image, width: 48, height: 48, fit: pw.BoxFit.contain),
                pw.SizedBox(width: 14),
              ],
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      college,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(title, style: const pw.TextStyle(fontSize: 12)),
                    pw.Text(
                      'ICTeach | Generated: ${generated.toIso8601String().substring(0, 16).replaceAll('T', ' ')}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
        build: (_) => [
          for (final section in sections) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              section.title,
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),
            if (section.rows.isEmpty)
              pw.Text('No records available.')
            else
              pw.TableHelper.fromTextArray(
                headers: section.columns,
                data: section.rows
                    .map((r) => r.map((v) => v?.toString() ?? '').toList())
                    .toList(),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.teal800,
                ),
                cellPadding: const pw.EdgeInsets.all(6),
                oddRowDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey100,
                ),
              ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static Future<void> printSummary(
    String title,
    List<SummarySection> sections,
  ) async {
    final profile =
        (await FirebaseFirestore.instance
                .collection('settings')
                .doc('school_profile')
                .get())
            .data();
    final college = profile?['name']?.toString().trim() ?? '';
    if (college.isEmpty) {
      throw StateError(
        'Set the college name in Admin > School Profile before printing.',
      );
    }
    Uint8List? logo;
    final url = profile?['logoUrl']?.toString() ?? '';
    if (url.isNotEmpty) {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) {
        throw StateError(
          'College logo could not be loaded. Check School Profile and retry.',
        );
      }
      logo = response.bodyBytes;
    }
    final bytes = await build(
      college: college,
      title: title,
      sections: sections,
      logo: logo,
    );
    await Printing.layoutPdf(name: title, onLayout: (_) async => bytes);
  }
}
