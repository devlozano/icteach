import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/class_summary_service.dart';
import 'package:icteach/services/summary_pdf_service.dart';
import 'package:icteach/services/personal_summary_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PDF rows are normalized to the declared report columns', () {
    const section = SummarySection(
      'Flexible data',
      ['Name', 'Details', 'Missing'],
      [
        [
          'Learner',
          {'COC1': 5, 'COC2': 4},
        ],
        ['Extra values', 1, 2, 3],
      ],
    );

    final rows = SummaryPdfService.normalizedRows(section);
    expect(rows.every((row) => row.length == section.columns.length), isTrue);
    expect(rows.first[1], '{"COC1":5,"COC2":4}');
    expect(rows.first.last, isEmpty);
    expect(rows.last, ['Extra values', '1', '2']);
  });

  test('print summary builds a PDF with flexible report data', () async {
    final bytes = await SummaryPdfService.build(
      college: 'Cuyapo National High School',
      title: 'School Year 2026-2027 Summary',
      generatedAt: DateTime(2026, 11, 15),
      sections: const [
        SummarySection(
          'Class summary',
          ['Class', 'Teacher', 'Details'],
          [
            [
              'CSS 11',
              'Sample Teacher',
              {'students': 32, 'modules': 8},
            ],
          ],
        ),
      ],
    );
    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('class report sections are appropriate for each staff role', () {
    const sections = [
      SummarySection('Learning progress summary', [], []),
      SummarySection('Students', [], []),
      SummarySection('Module access', [], []),
      SummarySection('Quiz results', [], []),
      SummarySection('Pre-assessment', [], []),
      SummarySection('Trainer practical validation', [], []),
      SummarySection('Simulations', [], []),
      SummarySection('Teaching and course feedback', [], []),
    ];

    expect(
      ClassSummaryService.sectionsForRole(
        'trainer',
        sections,
      ).map((section) => section.title),
      ['Students', 'Trainer practical validation'],
    );
    expect(
      ClassSummaryService.sectionsForRole(
        'teacher',
        sections,
      ).map((section) => section.title),
      containsAll(['Quiz results', 'Simulations', 'Module access']),
    );
    expect(
      ClassSummaryService.sectionsForRole('admin', sections),
      hasLength(sections.length),
    );
  });

  test('print purposes include only the required summary', () {
    const sections = [
      SummarySection('Learning progress summary', [], []),
      SummarySection('Students', [], []),
      SummarySection('Module access', [], []),
      SummarySection('Quiz results', [], []),
      SummarySection('Trainer practical validation', [], []),
      SummarySection('Simulations', [], []),
    ];

    expect(
      ClassSummaryService.sectionsForPrint(
        ClassSummaryPrintPurpose.grades,
        ClassSummaryService.sectionsForRole('teacher', sections),
      ).map((section) => section.title),
      ['Learning progress summary'],
    );
    expect(
      ClassSummaryService.sectionsForPrint(
        ClassSummaryPrintPurpose.grades,
        ClassSummaryService.sectionsForRole('trainer', sections),
      ).map((section) => section.title),
      ['Trainer practical validation'],
    );
    expect(
      ClassSummaryService.sectionsForPrint(
        ClassSummaryPrintPurpose.progress,
        sections,
      ).map((section) => section.title),
      ['Learning progress summary'],
    );
    expect(
      ClassSummaryService.sectionsForPrint(
        ClassSummaryPrintPurpose.modules,
        sections,
      ).map((section) => section.title),
      ['Module access'],
    );
  });

  test('admin print summaries contain only the current page data', () {
    const sections = [
      SummarySection('Students', [], []),
      SummarySection('Class enrollment', [], []),
      SummarySection('Module publishing', [], []),
      SummarySection('Assessment summary', [], []),
    ];

    expect(
      AdminSummaryService.sectionsForPage(
        'Performance',
        sections,
      ).map((section) => section.title),
      ['Assessment summary'],
    );
    expect(
      AdminSummaryService.sectionsForPage(
        'Content Overview',
        sections,
      ).map((section) => section.title),
      ['Module publishing'],
    );
    expect(
      AdminSummaryService.sectionsForPage(
        'Manage Classes',
        sections,
      ).map((section) => section.title),
      ['Class enrollment'],
    );
  });
}
