import 'package:flutter/material.dart';
import 'staff_collection_ui.dart';

class ModuleStudentActivity {
  const ModuleStudentActivity({
    required this.id,
    required this.name,
    this.accessed = false,
    this.downloaded = false,
    this.requested = false,
  });
  final String id, name;
  final bool accessed, downloaded, requested;
}

class ModuleAccessOverview extends StatelessWidget {
  const ModuleAccessOverview({
    super.key,
    this.initiallyExpanded = false,
    required this.students,
    required this.accessed,
    required this.downloaded,
    required this.requested,
    required this.printAction,
  });
  final List<ModuleStudentActivity> students;
  final int accessed, downloaded, requested;
  final Widget printAction;

  final bool initiallyExpanded;
  @override
  Widget build(BuildContext context) {
    final ratio = students.isEmpty
        ? 0.0
        : (accessed / students.length).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.insights_outlined, color: staffBlue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Student activity',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: staffNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${students.length} enrolled students',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600
                  ? 3
                  : constraints.maxWidth >= 360
                  ? 2
                  : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: width,
                    child: _ActivityMetric(
                      label: 'Accessed',
                      count: accessed,
                      icon: Icons.visibility_outlined,
                      color: staffBlue,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _ActivityMetric(
                      label: 'Downloaded',
                      count: downloaded,
                      icon: Icons.download_done_rounded,
                      color: const Color(0xFF15803D),
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _ActivityMetric(
                      label: 'Download requests',
                      count: requested,
                      icon: Icons.file_download_outlined,
                      color: const Color(0xFFB45309),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            '$accessed of ${students.length} students have accessed this module',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: staffBlue,
              backgroundColor: const Color(0xFFEAF2FE),
              semanticsLabel: 'Students who accessed the module',
            ),
          ),
          const SizedBox(height: 8),
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: initiallyExpanded,
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              iconColor: staffBlue,
              title: const Text(
                'View student details',
                style: TextStyle(
                  fontSize: 14,
                  color: staffNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Downloaded = confirmed saved on the device. Browser requests do not confirm a saved file.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                ),
                Align(alignment: Alignment.centerRight, child: printAction),
                if (students.isEmpty)
                  const CollectionEmpty(
                    title: 'No enrolled students',
                    message:
                        'Student activity will appear here when students join this class.',
                    icon: Icons.people_outline,
                  ),
                for (final student in students)
                  _ActivityStudentRow(
                    key: ValueKey(student.id),
                    student: student,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActivityStudentRow extends StatelessWidget {
  const _ActivityStudentRow({super.key, required this.student});
  final ModuleStudentActivity student;
  @override
  Widget build(BuildContext context) {
    final name = student.name.trim().isEmpty ? 'Student' : student.name.trim();
    final identity = Row(
      children: [
        CircleAvatar(
          radius: 19,
          backgroundColor: const Color(0xFFEAF2FE),
          child: Text(
            name.characters.first.toUpperCase(),
            style: const TextStyle(
              color: staffBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: staffNavy,
            ),
          ),
        ),
      ],
    );
    final badges = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _ActivityBadge(
          label: student.accessed ? 'Accessed' : 'Not accessed',
          icon: student.accessed
              ? Icons.check_circle_outline
              : Icons.remove_circle_outline,
          color: student.accessed ? staffBlue : const Color(0xFF64748B),
        ),
        _ActivityBadge(
          label: student.downloaded
              ? 'Downloaded'
              : student.requested
              ? 'Requested · unconfirmed'
              : 'Not downloaded',
          icon: student.downloaded
              ? Icons.download_done_rounded
              : student.requested
              ? Icons.schedule
              : Icons.download_outlined,
          color: student.downloaded
              ? const Color(0xFF15803D)
              : student.requested
              ? const Color(0xFFB45309)
              : const Color(0xFF64748B),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 680
            ? Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 16),
                  Flexible(child: badges),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [identity, const SizedBox(height: 12), badges],
              ),
      ),
    );
  }
}

class _ActivityBadge extends StatelessWidget {
  const _ActivityBadge({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}
