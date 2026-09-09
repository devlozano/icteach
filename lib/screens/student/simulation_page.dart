import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/simulation_data.dart';
import '../../models/simulation_model.dart' as sim_models;
import '../../widgets/drag_drop_simulation.dart';
import '../../widgets/content_access_gate.dart';
import '../../widgets/activity_preparation_gate.dart';
import '../../services/learning_path_service.dart';

// Debug builds can open every simulation for local testing without recording
// practice or assessment progress. Release builds retain every prerequisite.
const bool _simulationTestingBypass = kDebugMode;

class SimulationPage extends StatelessWidget {
  final String classId;
  final String simulationId;
  final String title;
  final String? className;
  const SimulationPage({
    super.key,
    required this.classId,
    required this.simulationId,
    required this.title,
    this.className,
  });
  @override
  Widget build(BuildContext context) => ContentAccessGate(
    classId: classId,
    contentType: 'simulation',
    contentId: simulationId,
    builder: (_) => _simulationTestingBypass
        ? _SimulationSession(
            practice: true,
            testingBypass: true,
            classId: classId,
            simulationId: simulationId,
            title: title,
            className: className,
          )
        : ActivityPreparationGate(
            classId: classId,
            type: 'simulation',
            contentId: simulationId,
            title: title,
            sessionBuilder: (practice) => _SimulationSession(
              practice: practice,
              classId: classId,
              simulationId: simulationId,
              title: title,
              className: className,
            ),
          ),
  );
}

class _SimulationSession extends StatefulWidget {
  final bool practice;
  final bool testingBypass;
  final String classId;
  final String simulationId;
  final String title;
  final String? className;

  const _SimulationSession({
    required this.practice,
    this.testingBypass = false,
    required this.classId,
    required this.simulationId,
    required this.title,
    this.className,
  });

  @override
  State<_SimulationSession> createState() => _SimulationPageState();
}

class _SimulationPageState extends State<_SimulationSession> {
  sim_models.Simulation? _simulation;
  List<sim_models.Simulation> _prerequisites = [];
  bool _isLoading = true;
  bool _hasStarted = false;
  bool _isCompleted = false;
  bool _prerequisiteCompleted = true;
  bool _feedbackSubmitted = false;
  bool _savingProgress = false;
  List<String> _attemptErrors = [];

  @override
  void initState() {
    super.initState();

    _loadSimulation();
  }

  @override
  void dispose() {
    _setGameplayOrientation(false);
    super.dispose();
  }

  Future<void> _setGameplayOrientation(bool active) async {
    if (kIsWeb) return;
    await SystemChrome.setPreferredOrientations(
      active
          ? const [
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]
          : const [
              DeviceOrientation.portraitUp,
              DeviceOrientation.portraitDown,
            ],
    );
  }

  Future<void> _startGameplay() async {
    await _setGameplayOrientation(true);
    if (mounted) setState(() => _hasStarted = true);
  }

  Future<void> _loadSimulation() async {
    sim_models.Simulation? simulation;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId)
          .collection('simulations')
          .doc(widget.simulationId)
          .get();
      if (doc.exists) simulation = sim_models.Simulation.fromFirestore(doc);
    } catch (_) {}

    final bundledSimulation = SimulationData.getSimulationById(
      widget.simulationId,
    );
    if (widget.simulationId == 'sim_coc1_assembly' ||
        widget.simulationId == 'sim_coc1_cabling' ||
        widget.simulationId == 'sim_coc1_identification' ||
        widget.simulationId == 'sim_coc1_os_install') {
      // These practical labs rely on local compatibility metadata and
      // distractor parts that may not exist in older Firestore documents.
      simulation = bundledSimulation ?? simulation;
    } else {
      simulation ??= bundledSimulation;
    }
    var completed = false;
    var prerequisiteCompleted = true;
    final prerequisites = simulation == null
        ? <sim_models.Simulation>[]
        : SimulationData.getPrerequisiteChain(simulation.id);

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && simulation != null) {
      try {
        final progressRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('simulation_progress');
        final progress = await progressRef
            .doc('${widget.classId}_${simulation.id}')
            .get();
        completed =
            progress.data()?['completed'] == true &&
            progress.data()?['passed'] == true;

        if (simulation.requiredSimulationId != null) {
          final requiredProgress = await progressRef
              .doc('${widget.classId}_${simulation.requiredSimulationId}')
              .get();
          prerequisiteCompleted =
              requiredProgress.data()?['completed'] == true &&
              requiredProgress.data()?['passed'] == true;
        }
      } catch (_) {
        prerequisiteCompleted = simulation.requiredSimulationId == null;
      }
    } else {
      prerequisiteCompleted = simulation?.requiredSimulationId == null;
    }

    if (!mounted) return;
    setState(() {
      _simulation = simulation;
      _prerequisites = prerequisites;
      _isCompleted = widget.practice ? false : completed;
      _prerequisiteCompleted = widget.testingBypass || prerequisiteCompleted;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _scaffold(const Center(child: CircularProgressIndicator()));
    }
    if (_simulation == null) {
      return _scaffold(
        const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Simulation not found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('Please try again later.'),
            ],
          ),
        ),
      );
    }
    if (_isCompleted) return _buildCompletedPage();
    if (!_hasStarted) return _buildStartPage();

    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: _appBar(_simulation!.title),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: DragDropSimulation(
            practice: widget.practice,
            onFeedback: (errors) => _attemptErrors = errors,
            simulation: _simulation!,
            onComplete: _onComplete,
          ),
        ),
      ),
    );
  }

  Scaffold _scaffold(Widget body) =>
      Scaffold(appBar: _appBar(widget.title), body: body);

  AppBar _appBar(String title, {bool showHelp = false}) => AppBar(
    toolbarHeight: 42,
    leadingWidth: 48,
    elevation: 1,
    scrolledUnderElevation: 2,
    titleSpacing: 2,
    centerTitle: false,
    automaticallyImplyLeading: false,
    backgroundColor: const Color(0xFF0B2B4A),
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    leading: Padding(
      padding: const EdgeInsets.fromLTRB(7, 5, 3, 5),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: _leaveSimulation,
          borderRadius: BorderRadius.circular(8),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF0B2B4A),
            size: 21,
          ),
        ),
      ),
    ),
    title: Text(
      widget.className == null ? title : '$title • ${widget.className}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    ),
    actions: showHelp
        ? [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.help_outline, color: Colors.white),
              onPressed: _showHelp,
              tooltip: 'Help',
            ),
            const SizedBox(width: 3),
          ]
        : null,
  );

  Future<void> _leaveSimulation() async {
    await _setGameplayOrientation(false);
    if (mounted) Navigator.maybePop(context);
  }

  Widget _buildStartPage() {
    final locked = _isLocked();
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: _appBar(_simulation!.title, showHelp: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: _competencyColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getSimulationIcon(_simulation!.type),
                  size: 60,
                  color: _competencyColor,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _simulation!.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _simulation!.description,
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Competency', _simulation!.competency),
                    _buildInfoRow(
                      'Learning Outcome',
                      _simulation!.learningOutcome,
                    ),
                    _buildInfoRow(
                      'Items to Place',
                      '${_simulation!.items.length}',
                    ),
                    _buildInfoRow(
                      'Time Limit',
                      '${_simulation!.timeLimit} minutes',
                    ),
                    _buildInfoRow(
                      'Passing Score',
                      '${_simulation!.passingScore}%',
                    ),
                    if (_simulation!.requiredSimulationId != null)
                      _buildInfoRow(
                        'Requirement',
                        'Complete: ${_getPrerequisiteName()}',
                        warning: true,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: locked ? null : _startGameplay,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: locked
                        ? Colors.grey
                        : const Color(0xFF0B2B4A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    locked
                        ? 'Locked'
                        : widget.practice
                        ? 'Start ungraded practice'
                        : 'Start simulation assessment',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (locked) ...[
                const SizedBox(height: 8),
                const Text(
                  'Complete the required simulation first to unlock this.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Back to Simulations'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedPage() => Scaffold(
    backgroundColor: const Color(0xffF8FAFC),
    appBar: _appBar(_simulation!.title),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, size: 80, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              widget.practice
                  ? 'Practice completed (ungraded)'
                  : 'Simulation assessment completed!',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your progress for "${_simulation!.title}" has been saved.',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _feedbackSubmitted ? null : _showEvaluationDialog,
                icon: Icon(
                  _feedbackSubmitted ? Icons.check_circle : Icons.rate_review,
                ),
                label: Text(
                  _feedbackSubmitted
                      ? 'Evaluation submitted'
                      : 'Rate difficulty and give feedback',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await _setGameplayOrientation(true);
                      if (!mounted) return;
                      setState(() {
                        _hasStarted = true;
                        _isCompleted = false;
                      });
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back to List'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B2B4A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _showEvaluationDialog() async {
    var difficulty = 3;
    final commentController = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Activity evaluation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How difficult was this activity?'),
                Slider(
                  value: difficulty.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$difficulty / 5',
                  onChanged: (value) =>
                      setDialogState(() => difficulty = value.round()),
                ),
                Text(
                  const [
                    'Very easy',
                    'Easy',
                    'Appropriate',
                    'Difficult',
                    'Very difficult',
                  ][difficulty - 1],
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'What should be improved? (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) return;
                await FirebaseFirestore.instance
                    .collection('activity_feedback')
                    .add({
                      'studentId': user.uid,
                      'classId': widget.classId,
                      'simulationId': widget.simulationId,
                      'simulationTitle': _simulation!.title,
                      'difficulty': difficulty,
                      'comment': commentController.text.trim(),
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    commentController.dispose();
    if (submitted == true && mounted) {
      setState(() => _feedbackSubmitted = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you. Your evaluation was saved.')),
      );
    }
  }

  Widget _buildInfoRow(String label, String value, {bool warning = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: warning ? Colors.orange : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );

  void _showHelp() => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('How to Play'),
      scrollable: true,
      content: Text(
        '${_getInstructionText()}\n\n1. Choose a component and its tool/resource.\n\n2. Drag it to the correct target on the workbench.\n\n3. Use landscape orientation. Browse the parts tray with its arrows, tap a part to inspect it, and pinch the bench to zoom.\n\n4. Complete all tasks in the correct sequence.\n\nPrerequisites: ${_prerequisites.isEmpty ? "None" : _prerequisites.map((s) => s.title).join(", ")}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );

  Future<void> _onComplete(int score, int total, bool passed) async {
    if (_savingProgress) return;
    _savingProgress = true;
    final saved = await _saveProgress(score, total, passed);
    _savingProgress = false;
    if (!mounted) return;
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 30),
          content: const Text(
            'Simulation progress was not saved. Reconnect and retry saving.',
          ),
          action: SnackBarAction(
            label: 'Retry save',
            onPressed: () => _onComplete(score, total, passed),
          ),
        ),
      );
      return;
    }
    if (passed) {
      await _setGameplayOrientation(false);
      if (mounted) setState(() => _isCompleted = true);
    }
  }

  Future<bool> _saveProgress(int score, int total, bool passed) async {
    if (widget.testingBypass) return true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final db = FirebaseFirestore.instance;
      await LearningPathService.requirePrepared(
        widget.classId,
        'simulation',
        widget.simulationId,
        practice: widget.practice,
      );
      if (widget.practice) {
        await LearningPathService.savePractice(
          widget.classId,
          'simulation',
          widget.simulationId,
          widget.title,
          score,
          total,
        );
        return true;
      }
      final ref = db
          .collection('users')
          .doc(user.uid)
          .collection('simulation_progress')
          .doc('${widget.classId}_${widget.simulationId}');
      await db.runTransaction((transaction) async {
        final previous = (await transaction.get(ref)).data();
        final previouslyPassed = previous?['passed'] == true;
        final percentage = total == 0 ? 0 : (score / total * 100).round();
        final keepBest =
            previouslyPassed &&
            (!passed || ((previous?['percentage'] as num?) ?? 0) > percentage);
        transaction.set(ref, {
          'classId': widget.classId,
          'simulationId': widget.simulationId,
          'studentId': user.uid,
          'simulationTitle': _simulation!.title,
          'score': keepBest ? previous!['score'] : score,
          'total': keepBest ? previous!['total'] : total,
          'percentage': keepBest ? previous!['percentage'] : percentage,
          'passed': passed || previouslyPassed,
          'completed': passed || previouslyPassed,
          'completedAt': previouslyPassed
              ? previous!['completedAt']
              : passed
              ? FieldValue.serverTimestamp()
              : null,
          'updatedAt': FieldValue.serverTimestamp(),
          'attempts': FieldValue.increment(1),
          'lastErrors': _attemptErrors,
        }, SetOptions(merge: true));
        transaction.set(db.collection('activity_events').doc(), {
          'classId': widget.classId,
          'studentId': user.uid,
          'studentName': user.displayName ?? user.email ?? 'Student',
          'title': widget.title,
          'contentId': widget.simulationId,
          'event': 'simulation_completed',
          'mode': 'assessment',
          'score': score,
          'total': total,
          'passed': passed,
          'errors': _attemptErrors,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (passed) {
          transaction.set(
            db
                .collection('users')
                .doc(user.uid)
                .collection('completed_content')
                .doc('${widget.classId}_${widget.simulationId}'),
            {
              'classId': widget.classId,
              'contentId': widget.simulationId,
              'completedAt': FieldValue.serverTimestamp(),
            },
          );
        }
      });
      if (mounted && passed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  String _getInstructionText() {
    final action = switch (_simulation!.type) {
      'procedure' =>
        'Arrange the shuffled technician actions in the correct standards-based workflow.',
      'assembly' =>
        'Install the shuffled components in a safe manufacturer-approved sequence.',
      'cabling' =>
        'Inspect each shuffled connector, then match its keying and function to the correct port.',
      'identification' =>
        'Inspect each specimen and classify it from observable hardware evidence.',
      'networking' =>
        'Analyze the network requirements and place each shuffled item correctly.',
      _ => 'Complete every task using the correct technical procedure.',
    };
    return '$action You need ${_simulation!.passingScore}% to pass.';
  }

  bool _isLocked() => _simulation!.isLocked || !_prerequisiteCompleted;
  String _getPrerequisiteName() =>
      SimulationData.getSimulationById(
        _simulation!.requiredSimulationId ?? '',
      )?.title ??
      'Previous simulation';
  Color get _competencyColor =>
      _simulation!.competency == 'COC1' ? Colors.blue : Colors.green;

  IconData _getSimulationIcon(String type) {
    switch (type) {
      case 'assembly':
        return Icons.computer;
      case 'identification':
        return Icons.visibility;
      case 'networking':
        return Icons.wifi;
      case 'cabling':
        return Icons.linear_scale;
      default:
        return Icons.science;
    }
  }
}
