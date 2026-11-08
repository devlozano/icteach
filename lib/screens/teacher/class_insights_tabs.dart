part of 'progress_tracker_page.dart';

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.insights});
  final _ClassInsights insights;
  @override
  Widget build(BuildContext context) {
    final active = insights.students.where((s) => s.hasActivity).toList();
    final attention = insights.students
        .where((s) => !s.hasActivity || s.overallAverage < 75)
        .toList();
    final average = insights.students.isEmpty
        ? null
        : insights.students.fold<double>(
                0,
                (total, s) => total + s.overallAverage,
              ) /
              insights.students.length;
    return InsightsList(
      children: [
        const InsightsHeader(
          title: 'Your class at a glance',
          icon: Icons.space_dashboard_outlined,
          eyebrow: 'OVERVIEW',
          subtitle:
              'Review participation, activity results, and learners who may need support.',
        ),
        InsightsStats(
          items: [
            (
              label: 'Enrolled students',
              value: '${insights.students.length}',
              icon: Icons.people_outline,
            ),
            (
              label: 'Students active',
              value: '${active.length}',
              icon: Icons.bolt_outlined,
            ),
            (
              label: 'Activity average',
              value: average == null ? '—' : '${average.round()}%',
              icon: Icons.insights_outlined,
            ),
            (
              label: 'Need attention',
              value: '${attention.length}',
              icon: Icons.support_agent_outlined,
            ),
          ],
        ),
        const InsightsPanel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: insightsTeal, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Activity averages summarize quizzes and simulations. Open Grades for the official three-term CSS computation.',
                  style: TextStyle(color: insightsMuted, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final chart = InsightsPanel(
              child: LeaderboardChart(
                title: 'Activity results',
                entries: active
                    .map(
                      (s) => <String, dynamic>{
                        'studentName': s.name,
                        'percentage': s.overallAverage,
                      },
                    )
                    .toList(),
              ),
            );
            final support = InsightsPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Students needing attention',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: insightsNavy,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'No activity or an activity average below 75%.',
                    style: TextStyle(color: insightsMuted, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  if (insights.students.isEmpty)
                    const Text('Enroll students to start tracking progress.')
                  else if (attention.isEmpty)
                    const Text(
                      'Everyone has activity and is above the support threshold.',
                    )
                  else
                    for (final student in attention)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFFFFF2DF),
                              child: Icon(
                                student.hasActivity
                                    ? Icons.trending_down
                                    : Icons.hourglass_empty,
                                size: 18,
                                color: const Color(0xFF975A16),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    student.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: insightsNavy,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    student.hasActivity
                                        ? 'Activity average ${student.overallAverage.round()}%'
                                        : 'No quiz or simulation activity yet',
                                    style: const TextStyle(
                                      color: insightsMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                ],
              ),
            );
            return constraints.maxWidth < 850
                ? Column(children: [chart, support])
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: chart),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: support),
                    ],
                  );
          },
        ),
      ],
    );
  }
}

class _StudentsTab extends StatefulWidget {
  const _StudentsTab({required this.students});
  final List<_StudentInsight> students;
  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab>
    with AutomaticKeepAliveClientMixin {
  String query = '';
  String filter = 'All students';
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final visible = widget.students
        .where(
          (s) =>
              s.name.toLowerCase().contains(query.toLowerCase()) &&
              (filter == 'All students' ||
                  (filter == 'No activity'
                      ? !s.hasActivity
                      : s.hasActivity && s.overallAverage < 75)),
        )
        .toList();
    return InsightsList(
      key: const ValueKey('insights-students'),
      children: [
        const InsightsHeader(
          title: 'Student progress',
          subtitle:
              'Find a learner and review quiz and practical activity results.',
          icon: Icons.people_outline,
          eyebrow: 'STUDENTS',
        ),
        InsightsPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Search students by name',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => query = value.trim()),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in [
                    'All students',
                    'Below 75%',
                    'No activity',
                  ])
                    ChoiceChip(
                      label: Text(label),
                      selected: filter == label,
                      onSelected: (_) => setState(() => filter = label),
                    ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            '${visible.length} of ${widget.students.length} students',
            style: const TextStyle(color: insightsMuted),
          ),
        ),
        if (visible.isEmpty)
          InsightsEmpty(
            icon: Icons.person_search_outlined,
            title: widget.students.isEmpty
                ? 'No enrolled students'
                : 'No matching students',
            subtitle: widget.students.isEmpty
                ? 'Students will appear here after joining the class.'
                : 'Try another name or select a different filter.',
          ),
        for (final student in visible)
          InsightsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFEAF2F7),
                      foregroundColor: insightsNavy,
                      child: Text(
                        student.name.isEmpty
                            ? '?'
                            : student.name.characters.first.toUpperCase(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: insightsNavy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Last activity: ${_formatDate(student.lastActivity)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: insightsMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InsightsPill(
                      'Quizzes: ${student.quizCount} · ${student.quizCount == 0 ? 'No score' : '${student.quizAverage.round()}%'}',
                      color: const Color(0xFF355EA8),
                    ),
                    InsightsPill(
                      'Simulations: ${student.simulationCount} · ${student.simulationCount == 0 ? 'No score' : '${student.simulationAverage.round()}%'}',
                    ),
                    InsightsPill(
                      'Passed: ${student.passedSimulations}',
                      color: const Color(0xFF587147),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ResultBar(
                  value: student.hasActivity ? student.overallAverage : null,
                  label: 'Activity average',
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SimulationsTab extends StatelessWidget {
  const _SimulationsTab({required this.records});
  final List<Map<String, dynamic>> records;
  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      final title =
          record['simulationTitle']?.toString() ??
          record['title']?.toString() ??
          record['simulationId']?.toString() ??
          'Simulation';
      grouped.putIfAbsent(title, () => []).add(record);
    }
    final passed = records.where((item) => item['passed'] == true).length;
    return InsightsList(
      children: [
        const InsightsHeader(
          title: 'Practical learning',
          subtitle: 'See how the class performs across hands-on simulations.',
          icon: Icons.memory_outlined,
          eyebrow: 'SIMULATIONS',
        ),
        InsightsStats(
          items: [
            (
              label: 'Simulations with results',
              value: '${grouped.length}',
              icon: Icons.memory_outlined,
            ),
            (
              label: 'Student records',
              value: '${records.length}',
              icon: Icons.assignment_outlined,
            ),
            (
              label: 'Passed records',
              value: '$passed',
              icon: Icons.check_circle_outline,
            ),
            (
              label: 'Pass rate',
              value: records.isEmpty
                  ? '—'
                  : '${(passed / records.length * 100).round()}%',
              icon: Icons.trending_up,
            ),
          ],
        ),
        if (records.isEmpty)
          const InsightsEmpty(
            icon: Icons.precision_manufacturing_outlined,
            title: 'No simulation attempts',
            subtitle:
                'Student simulation results will appear here as learners complete activities.',
          ),
        for (final entry in grouped.entries)
          Builder(
            builder: (context) {
              final passed = entry.value
                  .where((item) => item['passed'] == true)
                  .length;
              final average =
                  entry.value.fold<double>(
                    0,
                    (total, item) =>
                        total + ((item['percentage'] as num?)?.toDouble() ?? 0),
                  ) /
                  entry.value.length;
              final retries = entry.value.fold<int>(
                0,
                (total, item) =>
                    total +
                    (((item['attempts'] as num?)?.toInt() ?? 1) - 1).clamp(
                      0,
                      999,
                    ),
              );
              return InsightsPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: insightsNavy,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        InsightsPill(
                          'Records: ${entry.value.length}',
                          color: insightsMuted,
                        ),
                        InsightsPill('Passed: $passed'),
                        InsightsPill(
                          'Retries: $retries',
                          color: const Color(0xFF975A16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _ResultBar(
                      value: average,
                      label: 'Average simulation result',
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

class _FeedbackTab extends StatelessWidget {
  const _FeedbackTab({
    required this.feedback,
    required this.questionnaireResponses,
  });
  final List<Map<String, dynamic>> feedback, questionnaireResponses;
  @override
  Widget build(BuildContext context) => InsightsList(
    key: const ValueKey('insights-feedback'),
    children: [
      const InsightsHeader(
        title: 'Listen to your learners',
        subtitle:
            'Review teaching questionnaires and feedback from practical activities.',
        icon: Icons.forum_outlined,
        eyebrow: 'FEEDBACK',
      ),
      InsightsStats(
        items: [
          (
            label: 'Questionnaire responses',
            value: '${questionnaireResponses.length}',
            icon: Icons.fact_check_outlined,
          ),
          (
            label: 'Simulation feedback',
            value: '${feedback.length}',
            icon: Icons.chat_bubble_outline,
          ),
        ],
      ),
      if (feedback.isEmpty && questionnaireResponses.isEmpty)
        const InsightsEmpty(
          icon: Icons.mark_chat_unread_outlined,
          title: 'No feedback submitted',
          subtitle:
              'Learner responses will appear here when they submit feedback.',
        ),
      if (questionnaireResponses.isNotEmpty) ...[
        const _SectionLabel('Teaching questionnaires'),
        for (final response in questionnaireResponses)
          InsightsPanel(
            padding: EdgeInsets.zero,
            child: ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              title: Text(
                response['questionnaireTitle']?.toString() ?? 'Questionnaire',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: insightsNavy,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(response['studentName']?.toString() ?? 'Student'),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    response['summary']?.toString() ?? 'Response submitted',
                    style: const TextStyle(color: insightsMuted, height: 1.5),
                  ),
                ),
                const SizedBox(height: 12),
                for (final rating in Map<String, dynamic>.from(
                  response['ratings'] as Map? ?? {},
                ).entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '${(response['ratingPrompts'] as Map?)?[rating.key] ?? rating.key}',
                            style: const TextStyle(color: insightsMuted),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InsightsPill('${rating.value}/5'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
      if (feedback.isNotEmpty) ...[
        const _SectionLabel('Simulation feedback'),
        for (final item in feedback)
          InsightsPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['simulationTitle']?.toString() ?? 'Simulation',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: insightsNavy,
                  ),
                ),
                const SizedBox(height: 10),
                InsightsPill(
                  'Difficulty: ${item['difficulty'] ?? 'Not rated'}',
                  color: insightsMuted,
                ),
                const SizedBox(height: 14),
                Text(
                  item['comment']?.toString().trim().isNotEmpty == true
                      ? item['comment'].toString()
                      : 'No written comment',
                  style: const TextStyle(height: 1.6, color: insightsMuted),
                ),
              ],
            ),
          ),
      ],
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14, top: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w800,
        color: insightsNavy,
      ),
    ),
  );
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({required this.value, required this.label});
  final double? value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          Text(
            label,
            style: const TextStyle(color: insightsMuted, fontSize: 13),
          ),
          Text(
            value == null ? 'No activity' : '${value!.round()}%',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: insightsNavy,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LinearProgressIndicator(
        value: value == null ? 0 : (value! / 100).clamp(0, 1),
        minHeight: 7,
        borderRadius: BorderRadius.circular(8),
        color: insightsTeal,
        backgroundColor: const Color(0xFFEAF0F5),
      ),
    ],
  );
}
