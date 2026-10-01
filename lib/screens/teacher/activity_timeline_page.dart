import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/content_access_service.dart';

class ActivityTimelinePage extends StatefulWidget {
  final String classId;
  const ActivityTimelinePage({super.key, required this.classId});
  @override
  State<ActivityTimelinePage> createState() => _ActivityTimelinePageState();
}

class _ActivityTimelinePageState extends State<ActivityTimelinePage> {
  late final _staff = ContentAccessService.isClassStaff(widget.classId);
  late final _events = FirebaseFirestore.instance
      .collection('activity_events')
      .where('classId', isEqualTo: widget.classId)
      .snapshots();

  (IconData, Color, String) _style(String event) {
    if (event.contains('quiz')) {
      return (Icons.quiz_rounded, const Color(0xFF7C3AED), 'Quiz');
    }
    if (event.contains('simulation')) {
      return (Icons.memory_rounded, const Color(0xFF0891B2), 'Simulation');
    }
    if (event.contains('module') || event.contains('lesson')) {
      return (Icons.menu_book_rounded, const Color(0xFF2563EB), 'Lesson');
    }
    return (Icons.bolt_rounded, const Color(0xFFEA7C16), 'Activity');
  }

  String _date(DateTime? value) {
    if (value == null) return 'Syncing…';
    final local = value.toLocal();
    final now = DateTime.now();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return 'Today · $time';
    }
    return '${local.month}/${local.day}/${local.year} · $time';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FB),
    appBar: AppBar(
      title: const Text('Student activity timeline'),
      backgroundColor: const Color(0xFF0B2B4A),
      foregroundColor: Colors.white,
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
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _events,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load activity. Check connection and permissions.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final events = snapshot.data!.docs.toList()
              ..sort(
                (a, b) =>
                    ((b.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0)
                        .compareTo(
                          (a.data()['createdAt'] as Timestamp?)
                                  ?.millisecondsSinceEpoch ??
                              0,
                        ),
              );
            if (events.isEmpty) return const _TimelineEmpty();
            final students = events
                .map((doc) => doc.data()['studentId']?.toString())
                .whereType<String>()
                .toSet()
                .length;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0B2B4A), Color(0xFF176B87)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Wrap(
                    spacing: 28,
                    runSpacing: 16,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Learning activity',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'A live record of lessons, quizzes, practice, and simulations.',
                              style: TextStyle(color: Color(0xFFD7EAF1)),
                            ),
                          ],
                        ),
                      ),
                      _TimelineMetric(
                        value: '${events.length}',
                        label: 'Events',
                      ),
                      _TimelineMetric(value: '$students', label: 'Students'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                for (var i = 0; i < events.length; i++)
                  _card(events[i].data(), i == events.length - 1),
              ],
            );
          },
        );
      },
    ),
  );

  Widget _card(Map<String, dynamic> event, bool last) {
    final style = _style(event['event']?.toString() ?? 'activity');
    final date = (event['createdAt'] as Timestamp?)?.toDate();
    final errors = (event['errors'] as List?) ?? const [];
    final status = event['score'] == null
        ? style.$3
        : '${event['score']} / ${event['total']}';
    return Stack(
      children: [
        if (!last)
          const Positioned(
            left: 21,
            top: 40,
            bottom: 0,
            child: ColoredBox(
              color: Color(0xFFDCE5ED),
              child: SizedBox(width: 2),
            ),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: style.$2.withValues(alpha: .13),
                child: Icon(style.$1, color: style.$2, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFDDE6EE)),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 430;
                    final badge = _TimelineBadge(
                      label: status,
                      scored: event['score'] != null,
                      color: style.$2,
                    );
                    return ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      tilePadding: EdgeInsets.fromLTRB(
                        compact ? 14 : 18,
                        8,
                        compact ? 10 : 18,
                        8,
                      ),
                      title: Text(
                        event['studentName']?.toString() ??
                            event['studentId']?.toString() ??
                            'Student',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${event['title'] ?? event['contentId'] ?? style.$3} · ${_date(date)}',
                            ),
                            if (compact) ...[const SizedBox(height: 8), badge],
                          ],
                        ),
                      ),
                      trailing: compact ? null : badge,
                      children: [
                        if (errors.isEmpty)
                          const ListTile(
                            leading: Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            title: Text('No recorded task errors'),
                          ),
                        for (final error in errors)
                          ListTile(
                            leading: const Icon(Icons.build_outlined),
                            title: Text(error.toString()),
                          ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(18, 0, 18, 16),
                          child: Text(
                            'Practice records support instruction and are not physical competency certification.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimelineBadge extends StatelessWidget {
  const _TimelineBadge({
    required this.label,
    required this.scored,
    required this.color,
  });
  final String label;
  final bool scored;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: .18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          scored ? Icons.analytics_outlined : Icons.label_outline_rounded,
          size: 15,
          color: color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _TimelineMetric extends StatelessWidget {
  const _TimelineMetric({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    width: 100,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: const TextStyle(color: Color(0xFFD7EAF1))),
      ],
    ),
  );
}

class _TimelineEmpty extends StatelessWidget {
  const _TimelineEmpty();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 68,
            color: Color(0xFF94A3B8),
          ),
          SizedBox(height: 14),
          Text(
            'No student activity yet',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'Lesson, quiz, practice, and simulation events will appear here.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
