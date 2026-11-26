import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../data/simulation_data.dart';
import '../../data/interactive_quizzes.dart';
import '../../models/quiz_model.dart';
import '../../models/simulation_model.dart' as simulation_models;
import '../../services/content_access_service.dart';
import '../../services/learning_path_service.dart';

class LearningPathManager extends StatefulWidget {
  final String classId;
  const LearningPathManager({super.key, required this.classId});

  static List<simulation_models.Simulation> availableSimulations() =>
      SimulationData.getAllSimulations();

  @override
  State<LearningPathManager> createState() => _LearningPathManagerState();
}

class _LearningPathManagerState extends State<LearningPathManager> {
  late final Future<bool> _staff = ContentAccessService.isClassStaff(
    widget.classId,
  );
  Future<void> _edit(String type, String id, String title) async {
    try {
      await LearningPathService.requireActive(widget.classId);
      final root = FirebaseFirestore.instance
          .collection('classes')
          .doc(widget.classId);
      final modules =
          (await root
                  .collection('modules')
                  .where('isPublished', isEqualTo: true)
                  .get())
              .docs;
      final quizDocs = await root.collection('quizzes').get();
      final quizzes =
          InteractiveQuizzes.merge(
                widget.classId,
                quizDocs.docs.map((doc) => QuizModel.fromFirestore(doc)),
              )
              .where(
                (q) =>
                    q.isPublished &&
                    (q.questions.isNotEmpty ||
                        InteractiveQuizzes.activity(widget.classId, q.id) !=
                            null),
              )
              .toList();
      final ref = root
          .collection('learning_paths')
          .doc(LearningPathService.key(type, id));
      var old = (await ref.get()).data();
      final migrated = InteractiveQuizzes.activity(widget.classId, id);
      if (old == null && migrated != null) {
        old =
            (await root
                    .collection('learning_paths')
                    .doc(LearningPathService.key('simulation', migrated.id))
                    .get())
                .data();
      }
      String? moduleId = old?['moduleId'];
      String? quizId = old?['quizId'];
      if (!modules.any((m) => m.id == moduleId)) moduleId = null;
      if (!quizzes.any((q) => q.id == quizId)) quizId = null;
      if (!mounted) return;
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: Text('Learning path: $title'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      type == 'simulation'
                          ? 'Choose the lesson students must complete before simulation practice, and the theory quiz required before the simulation assignment.'
                          : 'Choose the published lesson students must complete before taking this quiz. Quizzes have one scored attempt and no practice mode.',
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: moduleId,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: type == 'simulation'
                            ? 'Required published module'
                            : 'Required published module',
                      ),
                      items: modules
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(
                                m.data()['title'] ?? m.id,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => update(() => moduleId = v),
                    ),
                    if (type == 'simulation')
                      DropdownButtonFormField<String>(
                        initialValue: quizId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Part 1: teacher/trainer theory quiz',
                        ),
                        items: quizzes
                            .map(
                              (q) => DropdownMenuItem(
                                value: q.id,
                                child: Text(
                                  q.title,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => update(() => quizId = v),
                      ),
                    if (modules.isEmpty ||
                        (type == 'simulation' && quizzes.isEmpty))
                      const Text(
                        'Publish a module and a nonempty theory quiz first.',
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    moduleId == null || (type == 'simulation' && quizId == null)
                    ? null
                    : () => Navigator.pop(context, true),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (save != true) return;
      if (!await ContentAccessService.isClassStaff(widget.classId)) {
        throw StateError('Staff access required.');
      }
      await LearningPathService.requireActive(widget.classId);
      final batch = FirebaseFirestore.instance.batch();
      batch.set(ref, {
        'moduleId': moduleId,
        'quizId': type == 'simulation' ? quizId : null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // The same lesson prepares students for the terminology/theory stage.
      if (type == 'simulation' &&
          !(await root.collection('learning_paths').doc('quiz_$quizId').get())
              .exists) {
        batch.set(
          root.collection('learning_paths').doc('quiz_$quizId'),
          {'moduleId': moduleId, 'updatedAt': FieldValue.serverTimestamp()},
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save learning path: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FB),
    appBar: AppBar(
      backgroundColor: const Color(0xFF172554),
      foregroundColor: Colors.white,
      title: const Text('Simulation assignment links'),
    ),
    body: FutureBuilder<bool>(
      future: _staff,
      builder: (context, staff) {
        if (staff.hasError || staff.data == false) {
          return const Center(
            child: Text('Class teacher/trainer access required.'),
          );
        }
        if (!staff.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final simulations = LearningPathManager.availableSimulations();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _LearningPathHero(),
            const SizedBox(height: 18),
            Text(
              'Simulation learning paths',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF172554),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose the lesson and theory quiz students complete before each practical assignment.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 12),
            for (final competency in ['COC1', 'COC2']) ...[
              _PathSection(
                title: '$competency simulations',
                icon: Icons.precision_manufacturing_outlined,
                count: simulations
                    .where((item) => item.competency == competency)
                    .length,
                children: [
                  for (final simulation in simulations.where(
                    (item) => item.competency == competency,
                  ))
                    _PathItem(
                      key: ValueKey('learning_path_${simulation.id}'),
                      icon: simulation.type == 'disassembly'
                          ? Icons.build_circle_outlined
                          : Icons.science_outlined,
                      title: simulation.title,
                      subtitle: simulation.learningOutcome,
                      actionLabel: 'Configure link',
                      onTap: () =>
                          _edit('simulation', simulation.id, simulation.title),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 16),
          ],
        );
      },
    ),
  );
}

class _LearningPathHero extends StatelessWidget {
  const _LearningPathHero();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1D4ED8), Color(0xFF4338CA)],
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: const [
        BoxShadow(
          color: Color(0x242563EB),
          blurRadius: 20,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.account_tree_outlined, color: Colors.white, size: 30),
        const SizedBox(height: 12),
        Text(
          'Build the learning sequence',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Connect each activity to the content students need before they begin.',
          style: TextStyle(color: Color(0xFFDDE7FF), height: 1.4),
        ),
        const SizedBox(height: 18),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _SetupStep(number: '1', label: 'Publish lesson'),
            _SetupStep(number: '2', label: 'Publish quiz'),
            _SetupStep(number: '3', label: 'Link activity'),
            _SetupStep(number: '4', label: 'Check access'),
          ],
        ),
      ],
    ),
  );
}

class _SetupStep extends StatelessWidget {
  final String number;
  final String label;
  const _SetupStep({required this.number, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: .22)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 11,
          backgroundColor: Colors.white,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF3730A3),
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _PathSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final int count;
  final List<Widget> children;
  const _PathSection({
    required this.title,
    required this.icon,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: const Color(0xFF4338CA)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172554),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        ...children,
      ],
    ),
  );
}

class _PathItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback onTap;
  const _PathItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: actionLabel,
            child: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    ),
  );
}
