import '../../services/assessment_order.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../data/pre_assessment_data.dart';
import '../../services/content_access_service.dart';

class PreAssessmentPage extends StatefulWidget {
  final String classId;
  final String className;
  final WidgetBuilder builder;
  const PreAssessmentPage({
    super.key,
    required this.classId,
    required this.className,
    required this.builder,
  });
  @override
  State<PreAssessmentPage> createState() => _PreAssessmentPageState();
}

class _PreAssessmentPageState extends State<PreAssessmentPage> {
  late Future<bool> _access;
  late AssessmentOrder _order;
  final _answers = List<int?>.filled(PreAssessmentData.questions.length, null);
  bool _saving = false, _started = false, _continue = false;
  int _current = 0;
  Map<String, dynamic>? _result;

  void _randomize() => _order = AssessmentOrder(
    PreAssessmentData.questions.map((q) => q.options.length).toList(),
  );

  @override
  void initState() {
    super.initState();
    _randomize();
    _access = _check();
  }

  @override
  void didUpdateWidget(covariant PreAssessmentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _randomize();
      _answers.fillRange(0, _answers.length, null);
      _result = null;
      _continue = false;
      _started = false;
      _current = 0;
      _access = _check();
    }
  }

  Future<bool> _check() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Please sign in first.');
    if (await ContentAccessService.isClassStaff(widget.classId)) return true;
    final doc = await FirebaseFirestore.instance
        .collection('pre_assessments')
        .doc('${uid}_${widget.classId}')
        .get();
    return PreAssessmentData.isComplete(doc.data());
  }

  Future<void> _submit() async {
    if (_saving || _answers.any((a) => a == null)) return;
    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Please sign in first.');
      final answers = _answers.cast<int>();
      final result = PreAssessmentData.score(answers);
      final ref = FirebaseFirestore.instance
          .collection('pre_assessments')
          .doc('${user.uid}_${widget.classId}');
      final saved = await FirebaseFirestore.instance
          .runTransaction<Map<String, dynamic>>((transaction) async {
            final previous = await transaction.get(ref);
            if (PreAssessmentData.isComplete(previous.data())) {
              return previous.data()!;
            }
            final data = {
              ...result,
              'answers': answers,
              'version': PreAssessmentData.version,
              'completed': true,
              'studentId': user.uid,
              'studentName': user.displayName ?? user.email ?? 'Student',
              'classId': widget.classId,
              'completedAt': FieldValue.serverTimestamp(),
            };
            transaction.set(ref, data);
            return data;
          });
      if (mounted) setState(() => _result = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Assessment not saved. Reconnect and try again; your answers are still here.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _requestSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.fact_check_outlined,
          color: Color(0xFF2457C5),
          size: 36,
        ),
        title: const Text('Submit your pre-assessment?'),
        content: const Text(
          'Your answers will be saved as your diagnostic result. Review them now because this assessment can only be submitted once.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Review answers'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit assessment'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _submit();
  }

  String _answerText(int index) {
    final answers = _result?['answers'];
    final options = PreAssessmentData.questions[index].options;
    if (answers is! List || index >= answers.length || answers[index] is! int) {
      return 'Not recorded';
    }
    final answer = answers[index] as int;
    return answer >= 0 && answer < options.length
        ? options[answer]
        : 'Not recorded';
  }

  int? _answerIndex(int index) {
    final answers = _result?['answers'];
    return answers is List && index < answers.length && answers[index] is int
        ? answers[index] as int
        : null;
  }

  String _correctAnswerText(int index) {
    final question = PreAssessmentData.questions[index];
    return question.options[question.answer];
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _access,
    builder: (context, access) {
      if (access.data == true || _continue) return widget.builder(context);
      return Scaffold(
        backgroundColor: const Color(0xFFF4F7FC),
        appBar: AppBar(
          title: Text(
            access.connectionState == ConnectionState.waiting
                ? 'Modules'
                : 'Pre-assessment',
          ),
          backgroundColor: const Color(0xFF2457C5),
          foregroundColor: Colors.white,
        ),
        body: access.connectionState != ConnectionState.done
            ? const Center(child: CircularProgressIndicator())
            : access.hasError
            ? _ErrorState(onRetry: () => setState(() => _access = _check()))
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 980),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: _result != null
                          ? _results()
                          : !_started
                          ? _welcome()
                          : _questions(),
                    ),
                  ),
                ),
              ),
      );
    },
  );

  Widget _welcome() => ListView(
    key: const ValueKey('welcome'),
    padding: const EdgeInsets.all(20),
    children: [
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF183F96), Color(0xFF428DEB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x292457C5),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, box) {
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Tag('CSS READINESS CHECK'),
                const SizedBox(height: 14),
                Text(
                  'Discover what you already know',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This short diagnostic helps your trainer focus support on the topics where you need it most.',
                  style: TextStyle(
                    color: Color(0xFFEAF2FF),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ],
            );
            const art = Icon(
              Icons.psychology_alt_outlined,
              color: Colors.white,
              size: 100,
            );
            return box.maxWidth < 620
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      copy,
                      const SizedBox(height: 22),
                      const Center(child: art),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(flex: 3, child: copy),
                      const Expanded(flex: 2, child: art),
                    ],
                  );
          },
        ),
      ),
      const SizedBox(height: 18),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _Stat(
            Icons.quiz_outlined,
            PreAssessmentData.questions.length.toString(),
            'questions',
          ),
          const _Stat(Icons.timer_outlined, '5–10', 'minutes'),
          const _Stat(Icons.lock_open_outlined, 'Any score', 'unlocks modules'),
        ],
      ),
      const SizedBox(height: 18),
      Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFDCE5F5)),
        ),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Before you begin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              SizedBox(height: 14),
              _Guide(
                Icons.touch_app_outlined,
                'Choose the best answer for every question.',
              ),
              _Guide(
                Icons.sync_outlined,
                'Move back and change answers before submitting.',
              ),
              _Guide(
                Icons.school_outlined,
                'This is a learning diagnostic, not a certification exam.',
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      SizedBox(
        height: 54,
        child: FilledButton.icon(
          onPressed: () => setState(() => _started = true),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text(
            'Start pre-assessment',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    ],
  );

  Widget _questions() {
    final index = _order.questions[_current];
    final question = PreAssessmentData.questions[index];
    final answered = _answers.whereType<int>().length;
    final last = _current == _order.questions.length - 1;
    return Column(
      key: const ValueKey('questions'),
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 13),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Question ${_current + 1} of ${_order.questions.length}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    '$answered answered',
                    style: const TextStyle(
                      color: Color(0xFF58677E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 8,
                  value: answered / _answers.length,
                  backgroundColor: const Color(0xFFE3EAF5),
                ),
              ),
              const SizedBox(height: 11),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_order.questions.length, (position) {
                    final done = _answers[_order.questions[position]] != null;
                    final active = position == _current;
                    return Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: InkWell(
                        onTap: _saving
                            ? null
                            : () => setState(() => _current = position),
                        borderRadius: BorderRadius.circular(99),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: active
                                ? const Color(0xFF2457C5)
                                : done
                                ? const Color(0xFFDDF5E7)
                                : const Color(0xFFF0F3F8),
                          ),
                          child: done && !active
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: Color(0xFF287A46),
                                )
                              : Text(
                                  '${position + 1}',
                                  style: TextStyle(
                                    color: active
                                        ? Colors.white
                                        : const Color(0xFF536176),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
                side: const BorderSide(color: Color(0xFFDCE5F5)),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  key: ValueKey(index),
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Tag(question.competency, dark: true),
                      const SizedBox(height: 14),
                      Text(
                        question.prompt,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.25,
                            ),
                      ),
                      const SizedBox(height: 20),
                      for (final option in _order.options[index])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _Option(
                            marker: String.fromCharCode(
                              65 + _order.options[index].indexOf(option),
                            ),
                            text: question.options[option],
                            selected: _answers[index] == option,
                            onTap: _saving
                                ? null
                                : () =>
                                      setState(() => _answers[index] = option),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _saving || _current == 0
                    ? null
                    : () => setState(() => _current--),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Previous'),
              ),
              const Spacer(),
              if (!last)
                FilledButton.icon(
                  onPressed: _saving ? null : () => setState(() => _current++),
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next'),
                )
              else
                FilledButton.icon(
                  onPressed: _saving || answered != _answers.length
                      ? null
                      : _requestSubmit,
                  icon: _saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_saving ? 'Saving...' : 'Submit'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _results() {
    final score = (_result!['score'] as num?)?.toInt() ?? 0;
    final total = (_result!['totalQuestions'] as num?)?.toInt() ?? 12;
    final percentage = total == 0 ? 0 : (score / total * 100).round();
    final performance = percentage >= 85
        ? 'Strong foundation'
        : percentage >= 60
        ? 'Developing foundation'
        : 'Ready to build your foundation';
    final groups =
        _result!['competencyScores'] as Map<String, dynamic>? ?? const {};
    return ListView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: const Color(0xFF153A83),
            borderRadius: BorderRadius.circular(24),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              final meter = SizedBox(
                width: 145,
                height: 145,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: score / total,
                        strokeWidth: 13,
                        backgroundColor: Colors.white24,
                        color: const Color(0xFF70D99B),
                      ),
                    ),
                    Text(
                      '$score/$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              );
              final copy = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Tag('ASSESSMENT SAVED'),
                  const SizedBox(height: 12),
                  const Text(
                    'Your learning path is ready',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    '$performance · $percentage%',
                    style: const TextStyle(
                      color: Color(0xFF8EF0B3),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use the review below to see your strengths and the topics to focus on.',
                    style: const TextStyle(
                      color: Color(0xFFD8E6FF),
                      height: 1.45,
                    ),
                  ),
                ],
              );
              return box.maxWidth < 620
                  ? Column(children: [meter, const SizedBox(height: 24), copy])
                  : Row(
                      children: [
                        meter,
                        const SizedBox(width: 30),
                        Expanded(child: copy),
                      ],
                    );
            },
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Competency overview',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _Competency(
              'COC 1',
              'Computer systems servicing',
              (groups['COC1'] as num?)?.toInt() ?? 0,
              Icons.computer_outlined,
            ),
            _Competency(
              'COC 2',
              'Network fundamentals',
              (groups['COC2'] as num?)?.toInt() ?? 0,
              Icons.lan_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          'Answer review',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (final i in _order.questions)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: ExpansionTile(
              leading: CircleAvatar(
                backgroundColor:
                    _answerIndex(i) == PreAssessmentData.questions[i].answer
                    ? const Color(0xFFDDF5E7)
                    : const Color(0xFFFFE8E5),
                child: Icon(
                  _answerIndex(i) == PreAssessmentData.questions[i].answer
                      ? Icons.check
                      : Icons.close,
                  color:
                      _answerIndex(i) == PreAssessmentData.questions[i].answer
                      ? const Color(0xFF287A46)
                      : const Color(0xFFB83B31),
                ),
              ),
              title: Text(
                '${_order.questions.indexOf(i) + 1}. ${PreAssessmentData.questions[i].prompt}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your answer: ${_answerText(i)}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        if (_answerIndex(i) !=
                            PreAssessmentData.questions[i].answer) ...[
                          const SizedBox(height: 7),
                          Text(
                            'Correct answer: ${_correctAnswerText(i)}',
                            style: const TextStyle(
                              color: Color(0xFF287A46),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: FilledButton.icon(
            onPressed: () => setState(() => _continue = true),
            iconAlignment: IconAlignment.end,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text(
              'Continue to modules',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final bool dark;
  const _Tag(this.text, {this.dark = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: dark
          ? const Color(0xFFEAF1FF)
          : Colors.white.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: dark ? const Color(0xFF2457C5) : Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1,
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value, label;
  const _Stat(this.icon, this.value, this.label);
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 165),
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFDCE5F5)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF2457C5)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(color: Color(0xFF66758D))),
          ],
        ),
      ],
    ),
  );
}

class _Guide extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Guide(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: const Color(0xFF2457C5)),
        const SizedBox(width: 11),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _Option extends StatelessWidget {
  final String marker, text;
  final bool selected;
  final VoidCallback? onTap;
  const _Option({
    required this.marker,
    required this.text,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEAF1FF) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? const Color(0xFF2457C5) : const Color(0xFFD8E0EB),
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: selected
                  ? const Color(0xFF2457C5)
                  : const Color(0xFFF0F3F8),
              child: Text(
                marker,
                style: TextStyle(
                  color: selected ? Colors.white : const Color(0xFF536176),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected
                  ? const Color(0xFF2457C5)
                  : const Color(0xFFA4AFBF),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Competency extends StatelessWidget {
  final String title, subtitle;
  final int score;
  final IconData icon;
  const _Competency(this.title, this.subtitle, this.score, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 250, maxWidth: 460),
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDCE5F5)),
    ),
    child: Row(
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFEAF1FF),
          child: Icon(icon, color: const Color(0xFF2457C5)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF66758D)),
              ),
            ],
          ),
        ),
        Text(
          '$score/6',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 48,
            color: Color(0xFF66758D),
          ),
          const SizedBox(height: 12),
          const Text(
            'Unable to open the pre-assessment',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text('Check your connection, then try again.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}
