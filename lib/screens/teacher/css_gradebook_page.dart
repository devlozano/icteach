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
                        for (final student in widget.students.entries)
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
                            ...widget.students.entries.map((s) {
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
              for (final student in widget.students.entries)
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
                              studentId: student.key,
                              studentName: student.value,
                              term: term,
                              profile: profile,
                              year: schoolYear,
                              initial: CssGradebookService.readScores(
                                all['${student.key}_$term'] ?? {},
                              ),
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
                                    Icons.edit_outlined,
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
                                'Edit Term $term scores',
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
    required this.studentId,
    required this.studentName,
    required this.term,
    required this.profile,
    required this.year,
    required this.initial,
  });
  final CssGradebookService service;
  final String studentId, studentName;
  final int term, year;
  final CssGradingProfile profile;
  final Map<String, GradeScore> initial;
  @override
  State<_TermEditor> createState() => _TermEditorState();
}

class _TermEditorState extends State<_TermEditor> {
  final form = GlobalKey<FormState>();
  late final raw = [
    for (final key in DepEdGrading.components)
      TextEditingController(text: widget.initial[key]?.raw.toString() ?? ''),
  ];
  late final maximum = [
    for (final key in DepEdGrading.components)
      TextEditingController(
        text: widget.initial[key]?.maximum.toString() ?? '',
      ),
  ];
  bool busy = false;
  bool dirty = false;
  @override
  void dispose() {
    for (final c in [...raw, ...maximum]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, GradeScore> scores() => {
    for (var i = 0; i < DepEdGrading.components.length; i++)
      if (raw[i].text.trim().isNotEmpty && maximum[i].text.trim().isNotEmpty)
        DepEdGrading.components[i]: GradeScore(
          double.parse(raw[i].text),
          double.parse(maximum[i].text),
        ),
  };

  TableRow _scoreInputRow({
    required String label,
    required List<TextEditingController> controllers,
    required String keyPrefix,
    required Color background,
  }) {
    return TableRow(
      decoration: BoxDecoration(color: background),
      children: [
        _ScoreCellLabel(label),
        for (var i = 0; i < DepEdGrading.components.length; i++)
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextFormField(
              key: ValueKey('$keyPrefix-${DepEdGrading.components[i]}'),
              controller: controllers[i],
              enabled: !busy,
              inputFormatters: [ScoreInputFormatter()],
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.next,
              onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: keyPrefix == 'possible'
                    ? const Color(0xFFFFFDF4)
                    : Colors.white,
                border: const OutlineInputBorder(),
                hintText: '0',
                isDense: true,
              ),
              onChanged: (_) => setState(() => dirty = true),
              validator: (_) {
                final earned = raw[i].text.trim();
                final possible = maximum[i].text.trim();
                if (earned.isEmpty && possible.isEmpty) return null;
                final earnedValue = double.tryParse(earned);
                final possibleValue = double.tryParse(possible);
                if (earnedValue == null ||
                    possibleValue == null ||
                    !earnedValue.isFinite ||
                    !possibleValue.isFinite ||
                    possibleValue <= 0 ||
                    possibleValue > 1000000 ||
                    earnedValue < 0 ||
                    earnedValue > possibleValue) {
                  return keyPrefix == 'possible'
                      ? 'Positive maximum'
                      : '0 to maximum';
                }
                return null;
              },
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    DepEdTermResult? result;
    try {
      result = DepEdGrading.calculate(scores(), widget.profile, widget.year);
    } catch (_) {
      result = null;
    }
    return PopScope(
      canPop: !dirty && !busy,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || busy) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unsaved scores?'),
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
          title: Text('Term ${widget.term} | ${widget.studentName}'),
        ),
        body: Form(
          key: form,
          child: InsightsList(
            children: [
              const InsightsHeader(
                title: 'Record component scores',
                icon: Icons.edit_note,
                subtitle:
                    'Review the computed result below, then save your changes.',
              ),
              const InsightsPanel(
                child: Text(
                  'Enter the earned and possible points for the learner’s quiz, simulation, and assignment. Retain the individual activity records as supporting evidence.',
                  style: TextStyle(color: insightsMuted, height: 1.5),
                ),
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
                      child: Row(
                        children: [
                          const Icon(
                            Icons.grid_on_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${widget.studentName} • Term ${widget.term}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const Text(
                            'SCORE SHEET',
                            style: TextStyle(
                              color: Color(0xFFD8F3E7),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: 720,
                        child: Table(
                          border: TableBorder.all(
                            color: const Color(0xFFB8C7D6),
                          ),
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          columnWidths: const {
                            0: FlexColumnWidth(1.15),
                            1: FlexColumnWidth(),
                            2: FlexColumnWidth(),
                            3: FlexColumnWidth(),
                          },
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFFDDEAE3),
                              ),
                              children: [
                                const _ScoreCellLabel('COMPONENT'),
                                for (final label in DepEdGrading.labels)
                                  _ScoreCellLabel(label.toUpperCase()),
                              ],
                            ),
                            _scoreInputRow(
                              label: 'POSSIBLE POINTS',
                              controllers: maximum,
                              keyPrefix: 'possible',
                              background: const Color(0xFFFFF6D8),
                            ),
                            _scoreInputRow(
                              label: 'STUDENT SCORE',
                              controllers: raw,
                              keyPrefix: 'earned',
                              background: Colors.white,
                            ),
                            const TableRow(
                              decoration: BoxDecoration(
                                color: Color(0xFFF2F6F9),
                              ),
                              children: [
                                _ScoreCellLabel('GRADE WEIGHT'),
                                _ScoreCellLabel('20%'),
                                _ScoreCellLabel('65%'),
                                _ScoreCellLabel('15%'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Enter Possible Points first, then enter the student score below it. Only numbers are accepted, and a student score cannot exceed its possible points.',
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
              if (result != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Quiz weighted score: ${result.quiz.toStringAsFixed(2)}\n'
                      'Simulation weighted score: ${result.simulation.toStringAsFixed(2)}\n'
                      'Assignment weighted score: ${result.assignment.toStringAsFixed(2)}\n'
                      'Initial grade: ${result.initial.toStringAsFixed(2)}\n'
                      'Term grade: ${result.grade} | ${DepEdGrading.descriptor(result.grade)}',
                    ),
                  ),
                )
              else
                const Text(
                  'Incomplete: quiz, simulation, and assignment scores are required for a term grade.',
                ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: busy
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setState(() => busy = true);
                        try {
                          await widget.service.save(
                            widget.studentId,
                            widget.term,
                            scores(),
                          );
                          if (!mounted) return;
                          setState(() {
                            busy = false;
                            dirty = false;
                          });
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) Navigator.pop(context);
                          });
                        } catch (_) {
                          if (mounted && context.mounted) {
                            setState(() => busy = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to save scores. Your edits are still here.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                child: Text(busy ? 'Saving…' : 'Save scores'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreCellLabel extends StatelessWidget {
  const _ScoreCellLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF24364B),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: .25,
        ),
      ),
    );
  }
}
