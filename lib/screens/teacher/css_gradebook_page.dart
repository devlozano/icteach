import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/css_gradebook_service.dart';
import '../../services/report_export_service.dart';
import '../../utils/deped_grading.dart';
import '../../widgets/insights_ui.dart';
import '../../utils/score_input_formatter.dart';

class CssGradebookPage extends StatefulWidget {
  const CssGradebookPage({
    super.key,
    required this.classId,
    required this.students,
    this.service,
  });
  final String classId;
  final Map<String, String> students;
  final CssGradebookService? service;
  @override
  State<CssGradebookPage> createState() => _CssGradebookPageState();
}

class _CssGradebookPageState extends State<CssGradebookPage> {
  late final service = widget.service ?? CssGradebookService(widget.classId);
  late final settings = service.book.snapshots();
  late final records = service.book.collection('records').snapshots();
  final year = TextEditingController(text: '2026');
  bool busy = false;
  int term = 1;
  @override
  void dispose() {
    year.dispose();
    super.dispose();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: settings,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(
          child: Text('Unable to load gradebook. Check access and retry.'),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final config = snapshot.data!.data();
      if (config == null) {
        return InsightsList(
          children: [
            const InsightsHeader(
              title: 'Set up your gradebook',
              eyebrow: 'CSS / TECHPRO',
              icon: Icons.auto_stories_outlined,
              subtitle: 'Track each learner across three grading terms.',
            ),
            const InsightsPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Senior high grading weights',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: insightsNavy,
                    ),
                  ),
                  SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      InsightsPill('Quiz 20%'),
                      InsightsPill('Simulation 65%'),
                      InsightsPill('Assignment 15%'),
                    ],
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Set the school year before entering scores. It stays fixed after setup to keep saved grades consistent.',
                    style: TextStyle(color: insightsMuted, height: 1.5),
                  ),
                ],
              ),
            ),
            TextField(
              controller: year,
              keyboardType: TextInputType.number,
              inputFormatters: [
                ScoreInputFormatter(decimal: false, maximum: 2100),
              ],
              decoration: const InputDecoration(
                labelText: 'School year starting year',
                helperText: '2026 means SY 2026–2027',
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final y = int.tryParse(year.text.trim());
                      if (y == null || y < 2026 || y > 2100) {
                        message(
                          'Enter a school year starting in 2026 or later.',
                        );
                        return;
                      }
                      setState(() => busy = true);
                      try {
                        await service.configure(CssGradingProfile.techPro, y);
                      } catch (_) {
                        if (mounted) {
                          message('Unable to save setup. Please retry.');
                        }
                      } finally {
                        if (mounted) setState(() => busy = false);
                      }
                    },
              child: Text(busy ? 'Saving…' : 'Create three-term gradebook'),
            ),
          ],
        );
      }
      final profile = CssGradingProfile.values.byName(
        config['profile'] as String,
      );
      final schoolYear = config['year'] as int;
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: records,
        builder: (context, data) {
          if (data.hasError) {
            return const Center(child: Text('Unable to load saved grades.'));
          }
          if (!data.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final all = {for (final doc in data.data!.docs) doc.id: doc.data()};
          final students = widget.students.entries.toList()
            ..sort(
              (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
            );
          DepEdTermResult? result(String id, int t) => DepEdGrading.calculate(
            CssGradebookService.readScores(all['${id}_$t'] ?? {}),
            profile,
            schoolYear,
          );
          return InsightsList(
            key: const ValueKey('insights-grades'),
            children: [
              InsightsHeader(
                title: 'CSS gradebook',
                eyebrow: 'SY $schoolYear–${schoolYear + 1}',
                icon: Icons.auto_stories_outlined,
                subtitle:
                    'Select a term, then open a student to enter or review scores.',
              ),
              InsightsStats(
                items: [
                  (
                    label: 'Enrolled students',
                    value: '${widget.students.length}',
                    icon: Icons.people_outline,
                  ),
                  (
                    label: 'Term $term completed',
                    value:
                        '${widget.students.keys.where((id) => result(id, term) != null).length}',
                    icon: Icons.task_alt,
                  ),
                  (
                    label: 'Awaiting scores',
                    value:
                        '${widget.students.keys.where((id) => result(id, term) == null).length}',
                    icon: Icons.edit_note,
                  ),
                  (
                    label: 'Final grades ready',
                    value:
                        '${widget.students.keys.where((id) => [1, 2, 3].every((t) => result(id, t) != null)).length}',
                    icon: Icons.verified_outlined,
                  ),
                ],
              ),
              InsightsPanel(
                padding: EdgeInsets.zero,
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: const Text(
                    'Grading guide',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: insightsNavy,
                    ),
                  ),
                  subtitle: Text('Quiz 20% · Simulation 65% · Assignment 15%'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    Text(
                      schoolYear == 2026
                          ? 'Adjusted DepEd transmutation (SY 2026–2027).'
                          : 'Zero-based grades (SY 2027–2028 onward).',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Enter total earned and possible points for the quiz, simulation, and assignment. Blank scores stay incomplete; enter 0 only for an actual zero.',
                      style: TextStyle(color: insightsMuted, height: 1.5),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  for (var t = 1; t <= 3; t++)
                    ChoiceChip(
                      label: Text('Term $t'),
                      selected: term == t,
                      onSelected: (_) => setState(() => term = t),
                    ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Preview & export report'),
                    onPressed: () async {
                      final rows = <List<Object?>>[
                        [
                          'Student',
                          'Term 1',
                          'Term 2',
                          'Term 3',
                          'Final grade',
                        ],
                        for (final student in students)
                          [
                            student.value,
                            for (var t = 1; t <= 3; t++)
                              result(student.key, t)?.grade ?? 'Incomplete',
                            DepEdGrading.finalGrade([
                                  for (var t = 1; t <= 3; t++)
                                    result(student.key, t)?.grade,
                                ]) ??
                                'Incomplete',
                          ],
                      ];
                      final export = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(
                            'Grade report | SY $schoolYear–${schoolYear + 1}',
                          ),
                          content: SizedBox(
                            width: 760,
                            height: 420,
                            child: SingleChildScrollView(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowColor: const WidgetStatePropertyAll(
                                    Color(0xFFE8F0F8),
                                  ),
                                  columns: [
                                    for (final label in rows.first)
                                      DataColumn(label: Text('$label')),
                                  ],
                                  rows: [
                                    for (final row in rows.skip(1))
                                      DataRow(
                                        cells: [
                                          for (final cell in row)
                                            DataCell(Text('$cell')),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton.icon(
                              onPressed: rows.length == 1
                                  ? null
                                  : () => Navigator.pop(context, true),
                              icon: const Icon(Icons.download),
                              label: const Text('Export CSV for Excel'),
                            ),
                          ],
                        ),
                      );
                      if (export != true) return;
                      try {
                        await ReportExportService.shareCsv(
                          'css-grades-$schoolYear.csv',
                          [
                            [
                              'School year',
                              'Profile',
                              'Student',
                              'Term 1',
                              'Term 2',
                              'Term 3',
                              'Final grade',
                              'Descriptor',
                            ],
                            ...students.map((s) {
                              final grades = [
                                for (var t = 1; t <= 3; t++)
                                  result(s.key, t)?.grade,
                              ];
                              final finalGrade = DepEdGrading.finalGrade(
                                grades,
                              );
                              return <Object?>[
                                '$schoolYear-${schoolYear + 1}',
                                profile.label,
                                s.value,
                                ...grades.map((g) => g ?? 'Incomplete'),
                                finalGrade ?? 'Incomplete',
                                finalGrade == null
                                    ? ''
                                    : DepEdGrading.descriptor(finalGrade),
                              ];
                            }),
                          ],
                        );
                      } catch (_) {
                        if (mounted) {
                          message('Unable to export grades. Please retry.');
                        }
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.students.isEmpty)
                const InsightsEmpty(
                  icon: Icons.group_outlined,
                  title: 'No enrolled students',
                  subtitle:
                      'Enrolled learners will appear here for score entry.',
                ),
              for (final student in students)
                Builder(
                  builder: (context) {
                    final grades = [
                      for (var t = 1; t <= 3; t++)
                        result(student.key, t)?.grade,
                    ];
                    final finalGrade = DepEdGrading.finalGrade(grades);
                    return InsightsPanel(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _TermEditor(
                              service: service,
                              students: students,
                              term: term,
                              profile: profile,
                              year: schoolYear,
                              initial: {
                                for (final learner in students)
                                  learner.key: CssGradebookService.readScores(
                                    all['${learner.key}_$term'] ?? {},
                                  ),
                              },
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      student.value,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: insightsNavy,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.table_chart_outlined,
                                    color: insightsTeal,
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (var t = 0; t < 3; t++)
                                    InsightsPill(
                                      'Term ${t + 1}: ${grades[t] ?? "Incomplete"}',
                                      color: t + 1 == term
                                          ? insightsTeal
                                          : insightsMuted,
                                    ),
                                ],
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                child: Divider(
                                  height: 1,
                                  color: insightsBorder,
                                ),
                              ),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    'Final: ${finalGrade ?? "Incomplete"}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: insightsNavy,
                                    ),
                                  ),
                                  if (finalGrade != null)
                                    InsightsPill(
                                      DepEdGrading.descriptor(finalGrade),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Open Term $term class score sheet',
                                style: const TextStyle(
                                  color: insightsTeal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      );
    },
  );
}

class _TermEditor extends StatefulWidget {
  const _TermEditor({
    required this.service,
    required this.students,
    required this.term,
    required this.profile,
    required this.year,
    required this.initial,
  });
  final CssGradebookService service;
  final List<MapEntry<String, String>> students;
  final int term, year;
  final CssGradingProfile profile;
  final Map<String, Map<String, GradeScore>> initial;
  @override
  State<_TermEditor> createState() => _TermEditorState();
}

class _TermEditorState extends State<_TermEditor> {
  final form = GlobalKey<FormState>();
  late final fields = <String, List<TextEditingController>>{
    for (final student in widget.students)
      student.key: [
        for (final component in DepEdGrading.components)
          TextEditingController(
            text: _shown(widget.initial[student.key]?[component]),
          ),
      ],
  };
  bool busy = false, dirty = false;

  static String _shown(GradeScore? score) {
    if (score == null || score.maximum <= 0) return '';
    final value = score.raw / score.maximum * 100;
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(2);
  }

  Map<String, GradeScore> _scores(String id) => {
    for (var i = 0; i < DepEdGrading.components.length; i++)
      if (fields[id]![i].text.trim().isNotEmpty)
        DepEdGrading.components[i]: GradeScore(
          double.parse(fields[id]![i].text),
          100,
        ),
  };

  DepEdTermResult? _result(String id) {
    try {
      return DepEdGrading.calculate(_scores(id), widget.profile, widget.year);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    for (final row in fields.values) {
      for (final field in row) {
        field.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() => busy = true);
    try {
      for (final student in widget.students) {
        await widget.service.save(
          student.key,
          widget.term,
          _scores(student.key),
        );
      }
      if (!mounted) return;
      setState(() {
        busy = false;
        dirty = false;
      });
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to save scores. Your edits are still here.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !dirty && !busy,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop || busy) return;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard unsaved scores?'),
          content: const Text(
            'The class score sheet contains unsaved changes.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      if (discard == true && mounted) {
        setState(() => dirty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: insightsNavy,
        foregroundColor: Colors.white,
        title: Text('Term ${widget.term} class score sheet'),
      ),
      body: Form(
        key: form,
        child: InsightsList(
          children: [
            InsightsHeader(
              title: 'Record component scores',
              eyebrow:
                  '${widget.students.length} STUDENTS • TERM ${widget.term}',
              icon: Icons.table_chart_outlined,
              subtitle:
                  'Enter every learner’s component score in one class spreadsheet.',
            ),
            InsightsPanel(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFF176B45),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.grid_on_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'CLASS SCORE SHEET',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          'SCORES 0–100',
                          style: TextStyle(
                            color: Color(0xFFD8F3E7),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: 820,
                      child: Table(
                        border: TableBorder.all(color: const Color(0xFFB8C7D6)),
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        columnWidths: const {
                          0: FlexColumnWidth(1.8),
                          1: FlexColumnWidth(),
                          2: FlexColumnWidth(),
                          3: FlexColumnWidth(),
                          4: FixedColumnWidth(92),
                        },
                        children: [
                          const TableRow(
                            decoration: BoxDecoration(color: Color(0xFFDDEAE3)),
                            children: [
                              _ScoreCellLabel('STUDENT'),
                              _ScoreCellLabel('QUIZ\n20%'),
                              _ScoreCellLabel('SIMULATION\n65%'),
                              _ScoreCellLabel('ASSIGNMENT\n15%'),
                              _ScoreCellLabel('TERM GRADE'),
                            ],
                          ),
                          for (var i = 0; i < widget.students.length; i++)
                            _row(widget.students[i], i),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Students are arranged alphabetically. Enter 0 to 100 for each component. Leave a cell blank only when it has not been graded.',
                      style: TextStyle(
                        color: insightsMuted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: busy ? null : _save,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(busy ? 'Saving…' : 'Save class scores'),
            ),
          ],
        ),
      ),
    ),
  );

  TableRow _row(MapEntry<String, String> student, int rowIndex) {
    final row = fields[student.key]!;
    final result = _result(student.key);
    return TableRow(
      decoration: BoxDecoration(
        color: rowIndex.isEven ? Colors.white : const Color(0xFFF7F9FB),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Text(
            student.value,
            style: const TextStyle(
              color: insightsNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        for (var i = 0; i < DepEdGrading.components.length; i++)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextFormField(
              key: ValueKey(
                'score-${student.key}-${DepEdGrading.components[i]}',
              ),
              controller: row[i],
              enabled: !busy,
              inputFormatters: [ScoreInputFormatter(maximum: 100)],
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(),
                hintText: '—',
                isDense: true,
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return null;
                final score = double.tryParse(text);
                return score == null ||
                        !score.isFinite ||
                        score < 0 ||
                        score > 100
                    ? '0–100'
                    : null;
              },
              onChanged: (_) => setState(() => dirty = true),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            result?.grade.toString() ?? '—',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }
}

class _ScoreCellLabel extends StatelessWidget {
  const _ScoreCellLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF24364B),
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
