import 'package:flutter/material.dart';
import '../../services/learning_continuation_service.dart';
import '../../services/learning_path_service.dart';
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
      if (mounted)
        setState(() {
          _loading = false;
          _error = error is StateError
              ? error.message.toString()
              : 'Unable to load the next activity. Check your connection and retry.';
        });
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
      testingBypass: false,
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
      if (mounted)
        setState(() {
          _opening = false;
          _error = error is StateError
              ? error.message.toString()
              : 'Unable to open the next activity. Check your connection and retry.';
        });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_toQuiz ? 'Continue to Quiz' : 'Continue to Simulation'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Module \u2192 Lesson \u2192 Quiz \u2192 Simulation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 20),
        if (_loading || _opening) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          Text(
            _opening
                ? 'Opening your next activity...'
                : 'Finding your next activity...',
            textAlign: TextAlign.center,
          ),
        ],
        if (_error != null) ...[
          Text(_error!),
          TextButton(onPressed: _load, child: const Text('Retry')),
        ],
        if (!_opening && _items?.isEmpty == true) ...[
          Text(
            _toQuiz
                ? 'Lesson completed. Your teacher has not linked a published quiz with questions yet. Your progress is saved.'
                : 'Quiz completed. Your teacher has not linked an available simulation yet. Your result is saved.',
          ),
          TextButton(onPressed: _load, child: const Text('Check again')),
        ],
        if (!_opening && _error == null && (_items?.length ?? 0) > 1)
          const Text('Choose the next activity:'),
        if (!_opening && _error == null)
          for (final item in _items ?? <LearningDestination>[])
            Card(
              child: ListTile(
                title: Text(item.title),
                trailing: const Icon(Icons.arrow_forward),
                onTap: _loading ? null : () => _open(item),
              ),
            ),
      ],
    ),
  );
}
