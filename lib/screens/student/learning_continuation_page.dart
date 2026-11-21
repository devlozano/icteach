import 'package:flutter/material.dart';
import '../../services/learning_continuation_service.dart';
import '../../services/learning_path_service.dart';
import '../../widgets/learning_flow_indicator.dart';
import 'take_quiz_page.dart';
import 'simulation_page.dart';

/// Continues through teacher-assigned links without bypassing access gates.
class LearningContinuationPage extends StatefulWidget {
  final String classId;
  final String? moduleId, quizId;
  final Future<List<LearningDestination>> Function()? loadDestinations;
  final Future<Widget> Function(LearningDestination)? destinationBuilder;
  const LearningContinuationPage({
    super.key,
    required this.classId,
    this.moduleId,
    this.quizId,
    this.loadDestinations,
    this.destinationBuilder,
  });
  @override
  State<LearningContinuationPage> createState() =>
      _LearningContinuationPageState();
}

class _LearningContinuationPageState extends State<LearningContinuationPage> {
  List<LearningDestination>? _items;
  String? _error;
  bool _opening = false, _loading = false;
  bool get _toQuiz => widget.quizId == null;
  static const _wait = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<List<LearningDestination>> _loadAssigned() async {
    await LearningPathService.requireActive(widget.classId);
    return LearningContinuationService.next(
      widget.classId,
      moduleId: widget.moduleId,
      quizId: widget.quizId,
    );
  }

  Future<void> _load() async {
    if (_loading || _opening) return;
    setState(() {
      _loading = true;
      _error = null;
      _items = null;
    });
    try {
      final items = await (widget.loadDestinations?.call() ?? _loadAssigned())
          .timeout(_wait);
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      if (items.length == 1) await _open(items.single);
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error is StateError
              ? error.message.toString()
              : 'Unable to load the next activity. Check your connection and retry.';
        });
      }
    }
  }

  Future<Widget> _destination(LearningDestination item) async {
    if (item.quiz != null) {
      await LearningPathService.requireQuizAvailable(widget.classId, item.id);
      if (await LearningPathService.hasCompletedQuiz(widget.classId, item.id)) {
        return LearningContinuationPage(
          classId: widget.classId,
          quizId: item.id,
        );
      }
      return TakeQuizPage(classId: widget.classId, quiz: item.quiz!);
    }
    if (!await LearningPathService.hasCompletedQuiz(
      widget.classId,
      widget.quizId!,
    )) {
      throw StateError(
        'Complete the linked quiz before continuing to simulation.',
      );
    }
    return SimulationPage(
      classId: widget.classId,
      simulationId: item.id,
      title: item.title,
    );
  }

  Future<void> _open(LearningDestination item) async {
    if (_opening || _loading) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final page =
          await (widget.destinationBuilder?.call(item) ?? _destination(item))
              .timeout(_wait);
      if (!mounted) return;
      // Replace the transition page so Back never restarts automatic forwarding.
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => page));
    } catch (error) {
      if (mounted) {
        setState(() {
          _opening = false;
          _error = error is StateError
              ? error.message.toString()
              : 'Unable to open the next activity. Check your connection and retry.';
        });
      }
    }
  }

  Color get _accent =>
      _toQuiz ? const Color(0xFF6D5DFB) : const Color(0xFF0F9F8F);
  Color get _deep =>
      _toQuiz ? const Color(0xFF35279A) : const Color(0xFF08675E);
  Color get _soft =>
      _toQuiz ? const Color(0xFFF1EEFF) : const Color(0xFFE7F8F4);
  IconData get _stageIcon =>
      _toQuiz ? Icons.quiz_rounded : Icons.build_circle_rounded;

  Widget _hero(BuildContext context) => Container(
    key: ValueKey(_toQuiz),
    padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_deep, _accent],
      ),
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: _accent.withValues(alpha: 0.24),
          blurRadius: 28,
          offset: const Offset(0, 14),
        ),
      ],
    ),
    child: Stack(
      children: [
        Positioned(
          right: -10,
          top: -18,
          child: Icon(
            _toQuiz ? Icons.edit_note_rounded : Icons.memory_rounded,
            size: 126,
            color: Colors.white.withValues(alpha: 0.08),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: Text(
                _toQuiz ? 'STEP 2 OF 3' : 'STEP 3 OF 3',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.82, end: 1),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) =>
                      Transform.scale(scale: value, child: child),
                  child: Container(
                    width: 66,
                    height: 66,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(_stageIcon, color: _accent, size: 34),
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _toQuiz ? 'Continue to Quiz' : 'Continue to Simulation',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        _toQuiz
                            ? 'Your module is complete. The next knowledge check is ready.'
                            : 'Your quiz is complete. Continue with the hands-on activity.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.84),
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  Widget _status(BuildContext context) {
    final waiting = _loading || _opening;
    final hasNoActivity = !_opening && _items?.isEmpty == true;
    final hasChoices = !_opening && (_items?.length ?? 0) > 1;
    final title = _error != null
        ? 'We could not open the next step'
        : hasNoActivity
        ? 'Waiting for an assigned activity'
        : hasChoices
        ? 'Choose your next assigned activity'
        : _opening
        ? 'Opening your next activity...'
        : 'Finding your assigned activity...';
    final message = _error != null
        ? _error!
        : hasNoActivity
        ? _toQuiz
              ? 'Your progress is saved. Ask your teacher to link and publish a quiz.'
              : 'Your quiz result is saved. Ask your teacher to link an available simulation.'
        : hasChoices
        ? 'More than one activity is available. Select the one assigned by your teacher.'
        : _toQuiz
        ? 'Checking the published quiz and your access...'
        : 'Checking the linked simulation and your access...';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Container(
        key: ValueKey('$_error-$waiting-$hasNoActivity-$_opening'),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _error == null
                ? _accent.withValues(alpha: 0.14)
                : Theme.of(context).colorScheme.error.withValues(alpha: 0.25),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E293B).withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _error == null
                    ? _soft
                    : Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: waiting
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _accent,
                      ),
                    )
                  : Icon(
                      _error != null
                          ? Icons.wifi_off_rounded
                          : Icons.schedule_rounded,
                      color: _error != null
                          ? Theme.of(context).colorScheme.error
                          : _accent,
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF172033),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                  if (_error != null || hasNoActivity) ...[
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: _deep,
                        backgroundColor: _soft,
                      ),
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded, size: 19),
                      label: Text(_error != null ? 'Retry' : 'Check again'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _destinationCard(LearningDestination item) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: _loading ? null : () => _open(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _accent.withValues(alpha: 0.15)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_stageIcon, color: _accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _toQuiz ? 'Assigned quiz' : 'Assigned simulation',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF5F7FB),
    appBar: AppBar(
      backgroundColor: _deep,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(_toQuiz ? 'Continue to Quiz' : 'Continue to Simulation'),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _hero(context),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE6EAF1)),
                  ),
                  child: LearningFlowIndicator(
                    current: _toQuiz
                        ? LearningFlowStage.quiz
                        : LearningFlowStage.simulation,
                    compact: true,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _toQuiz ? 'Module complete' : 'Quiz complete',
                  style: TextStyle(
                    color: _deep,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                _status(context),
                if (!_opening && _error == null && (_items?.length ?? 0) > 1)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
                    child: Row(
                      children: [
                        Icon(Icons.route_rounded, size: 20, color: _accent),
                        const SizedBox(width: 8),
                        const Text(
                          'Choose the next assigned activity',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF172033),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!_opening && _error == null)
                  for (final item in _items ?? <LearningDestination>[])
                    _destinationCard(item),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
