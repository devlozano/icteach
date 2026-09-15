import 'package:flutter/material.dart';
import '../services/student_outcomes.dart';

class SystemSurveyFlow extends StatefulWidget {
  const SystemSurveyFlow({
    super.key,
    required this.initialRatings,
    required this.initialComment,
    required this.onSave,
  });
  final Map<int, int> initialRatings;
  final String initialComment;
  final Future<void> Function(Map<int, int>, String) onSave;
  @override
  State<SystemSurveyFlow> createState() => _SystemSurveyFlowState();
}

class _SystemSurveyFlowState extends State<SystemSurveyFlow> {
  static const navy = Color(0xFF0B2B4A);
  static const blue = Color(0xFF1478E8);
  static const choices = [
    'Strongly Disagree',
    'Disagree',
    'Neutral',
    'Agree',
    'Strongly Agree',
  ];
  late final ratings = Map<int, int>.from(widget.initialRatings);
  late final comment = TextEditingController(text: widget.initialComment);
  late Map<int, int> savedRatings = Map<int, int>.from(widget.initialRatings);
  late String savedComment = widget.initialComment;
  int step = -1;
  bool saving = false, results = false;
  String? error;
  @override
  void dispose() {
    comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (saving || ratings.length != helpfulnessPrompts.length) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(Map<int, int>.from(ratings), comment.text.trim());
      if (mounted) {
        setState(() {
          savedRatings = Map<int, int>.from(ratings);
          savedComment = comment.text.trim();
          results = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'Could not save your response. Your answers are kept. Please retry.';
        });
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Widget _button(String label, VoidCallback? action, IconData icon) =>
      FilledButton.icon(
        onPressed: action,
        icon: Icon(icon, size: 19),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: blue,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  Widget _intro() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 20),
      Container(
        height: 150,
        decoration: BoxDecoration(
          color: const Color(0xFFE6F3FF),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.assignment_outlined, size: 108, color: blue),
            Positioned(
              right: 32,
              bottom: 18,
              child: CircleAvatar(
                backgroundColor: navy,
                radius: 25,
                child: Icon(
                  Icons.school_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      const Text(
        'Your Feedback Matters!',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: navy,
        ),
      ),
      const SizedBox(height: 16),
      const Text(
        'Tell us how ICTeach helped you learn and prepare for your NC II assessment. Your answers help improve the learning experience.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, height: 1.5, color: navy),
      ),
      const SizedBox(height: 24),
      const Card(
        color: Color(0xFFE6F3FF),
        elevation: 0,
        child: ListTile(
          leading: Icon(Icons.schedule, color: blue),
          title: Text('Four questions and your suggestions'),
          subtitle: Text('It only takes a few minutes.'),
        ),
      ),
      const SizedBox(height: 24),
      _button(
        savedRatings.length == helpfulnessPrompts.length
            ? 'Update Survey'
            : 'Start Survey',
        () => setState(() => step = 0),
        Icons.arrow_forward,
      ),
      if (savedRatings.length == helpfulnessPrompts.length)
        TextButton(
          onPressed: () => setState(() => results = true),
          child: const Text('View Results'),
        ),
    ],
  );
  Widget _questions() {
    final suggestion = step == helpfulnessPrompts.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          child: Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: (step + 1) / (helpfulnessPrompts.length + 1),
                  minHeight: 7,
                  color: blue,
                  backgroundColor: const Color(0xFFDDEFFD),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 16),
              Text(
                '${step + 1} of ${helpfulnessPrompts.length + 1}',
                style: const TextStyle(color: navy),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: blue,
                    child: Text(
                      (step + 1).toString(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      suggestion
                          ? 'What suggestions can you give to improve ICTeach?'
                          : helpfulnessPrompts[step],
                      style: const TextStyle(
                        fontSize: 20,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: navy,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (suggestion)
                TextField(
                  controller: comment,
                  enabled: !saving,
                  maxLines: 6,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                    hintText: 'Type your suggestions here (optional)...',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(),
                  ),
                )
              else
                for (var score = 5; score >= 1; score--)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: ratings[step] == score
                          ? const Color(0xFFEAF4FF)
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: ratings[step] == score
                              ? blue
                              : const Color(0xFFDDE5ED),
                        ),
                      ),
                      child: Semantics(
                        selected: ratings[step] == score,
                        button: true,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: saving
                              ? null
                              : () => setState(() => ratings[step] = score),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Icon(
                                  ratings[step] == score
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  color: ratings[step] == score
                                      ? blue
                                      : Colors.blueGrey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    choices[score - 1],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: saving ? null : () => setState(() => step--),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _button(
                  saving
                      ? 'Submitting...'
                      : suggestion
                      ? 'Submit'
                      : 'Next',
                  saving
                      ? null
                      : suggestion
                      ? _submit
                      : ratings[step] == null
                      ? null
                      : () => setState(() => step++),
                  suggestion ? Icons.send_outlined : Icons.arrow_forward,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _results() => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: blue,
          child: Icon(Icons.assessment_outlined, color: Colors.white),
        ),
        title: Text(
          'Survey Results',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: navy,
          ),
        ),
        subtitle: Text('Your saved response. Staff can review this feedback.'),
      ),
      const SizedBox(height: 16),
      for (var i = 0; i < helpfulnessPrompts.length; i++)
        Card(
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: (savedRatings[i] ?? 0) / 5,
                          strokeWidth: 6,
                          color: const Color(0xFF16B69B),
                          backgroundColor: const Color(0xFFE1F5EF),
                        ),
                      ),
                      Text(
                        '${savedRatings[i] ?? 0}/5',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: navy,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        helpfulnessPrompts[i],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        choices[(savedRatings[i] ?? 1) - 1],
                        style: const TextStyle(color: blue),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      if (savedComment.isNotEmpty)
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your suggestions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(savedComment),
              ],
            ),
          ),
        ),
      const SizedBox(height: 20),
      _button(
        'Edit response',
        () => setState(() {
          results = false;
          step = 0;
        }),
        Icons.edit_outlined,
      ),
      TextButton(
        onPressed: () => Navigator.maybePop(context),
        child: const Text('Back to Profile'),
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving && (step == -1 || results),
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && !saving) setState(() => step--);
    },
    child: ColoredBox(
      color: const Color(0xFFF4FAFF),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SafeArea(
            top: false,
            child: results
                ? _results()
                : step < 0
                ? _intro()
                : _questions(),
          ),
        ),
      ),
    ),
  );
}
