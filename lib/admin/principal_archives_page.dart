import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../screens/teacher/progress_tracker_page.dart';

const _navy = Color(0xFF0F172A);
const _blue = Color(0xFF0891B2);
const _background = Color(0xFFF1F5F9);
const _border = Color(0xFFDCE4EC);
const _muted = Color(0xFF64748B);

Map<String, List<Map<String, dynamic>>> groupArchivedClassesByYear(
  Iterable<Map<String, dynamic>> classes,
) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final classroom in classes) {
    if (classroom['status'] != 'archived') continue;
    final year = classroom['schoolYear']?.toString().trim();
    final label = year == null || year.isEmpty ? 'Unspecified year' : year;
    groups.putIfAbsent(label, () => []).add(classroom);
  }
  for (final records in groups.values) {
    records.sort(
      (a, b) =>
          (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? ''),
    );
  }
  return Map.fromEntries(
    groups.entries.toList()..sort((a, b) => b.key.compareTo(a.key)),
  );
}

class PrincipalArchivesPage extends StatefulWidget {
  const PrincipalArchivesPage({super.key});

  @override
  State<PrincipalArchivesPage> createState() => _PrincipalArchivesPageState();
}

class _PrincipalArchivesPageState extends State<PrincipalArchivesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ArchiveOverview(
          searchChanged: (value) {
            setState(() => _query = value.trim().toLowerCase());
          },
        ),
        const SizedBox(height: 18),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('classes')
              .where('status', isEqualTo: 'archived')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            if (snapshot.hasError) {
              return _ArchiveMessage(
                icon: Icons.cloud_off_rounded,
                title: 'Archives could not be loaded',
                message: snapshot.error.toString(),
              );
            }

            final records = (snapshot.data?.docs ?? [])
                .map((document) {
                  return <String, dynamic>{
                    ...document.data(),
                    '_documentId': document.id,
                  };
                })
                .where((data) {
                  if (_query.isEmpty) return true;
                  return [
                    data['name'],
                    data['sectionCode'],
                    data['teacherName'],
                    data['schoolYear'],
                  ].any(
                    (value) => value.toString().toLowerCase().contains(_query),
                  );
                });
            final groups = groupArchivedClassesByYear(records);
            if (groups.isEmpty) {
              return _ArchiveMessage(
                icon: Icons.inventory_2_outlined,
                title: _query.isEmpty
                    ? 'No archived school years yet'
                    : 'No archive matches your search',
                message: _query.isEmpty
                    ? 'At rollover, complete classes and their records will '
                          'appear here under the school year name.'
                    : 'Try a class name, section, teacher, or school year.',
              );
            }

            return Column(
              children: groups.entries
                  .map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _SchoolYearArchive(
                        schoolYear: entry.key,
                        classes: entry.value,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ArchiveOverview extends StatelessWidget {
  const _ArchiveOverview({required this.searchChanged});

  final ValueChanged<String> searchChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final explanation = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: _blue),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'School year archive',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Archived classes are hidden from active student, '
                      'teacher, and trainer workspaces. Their lessons, scores, '
                      'submissions, and reports remain preserved.',
                      style: TextStyle(color: _muted, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          );
          final search = SizedBox(
            width: constraints.maxWidth < 720 ? double.infinity : 300,
            child: TextField(
              onChanged: searchChanged,
              decoration: InputDecoration(
                hintText: 'Search archives...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: _background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          );
          if (constraints.maxWidth < 720) {
            return Column(
              children: [explanation, const SizedBox(height: 16), search],
            );
          }
          return Row(
            children: [
              Expanded(child: explanation),
              const SizedBox(width: 24),
              search,
            ],
          );
        },
      ),
    );
  }
}

class _SchoolYearArchive extends StatelessWidget {
  const _SchoolYearArchive({required this.schoolYear, required this.classes});

  final String schoolYear;
  final List<Map<String, dynamic>> classes;

  @override
  Widget build(BuildContext context) {
    final studentTotal = classes.fold<int>(
      0,
      (total, data) =>
          total + ((data['enrolledStudentIds'] as List?)?.length ?? 0),
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _navy,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.calendar_month_rounded, color: Colors.white),
        ),
        title: Text(
          'School Year $schoolYear',
          style: const TextStyle(color: _navy, fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          '${classes.length} ${classes.length == 1 ? 'class' : 'classes'}  •  '
          '$studentTotal student records',
          style: const TextStyle(color: _muted),
        ),
        children: classes
            .map((classroom) => _ArchivedClassCard(data: classroom))
            .toList(),
      ),
    );
  }
}

class _ArchivedClassCard extends StatelessWidget {
  const _ArchivedClassCard({required this.data});

  final Map<String, dynamic> data;

  String _archivedDate() {
    final value = data['archivedAt'];
    if (value is! Timestamp) return 'Date unavailable';
    return DateFormat('MMM d, yyyy').format(value.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final classId = data['_documentId']?.toString() ?? '';
    final name = data['name']?.toString() ?? 'Untitled class';
    final section = data['sectionCode']?.toString() ?? 'No section';
    final teacher = data['teacherName']?.toString() ?? 'Unassigned teacher';
    final students = (data['enrolledStudentIds'] as List?)?.length ?? 0;
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Wrap(
                spacing: 14,
                runSpacing: 7,
                children: [
                  _ArchiveFact(icon: Icons.badge_outlined, text: section),
                  _ArchiveFact(icon: Icons.person_outline, text: teacher),
                  _ArchiveFact(
                    icon: Icons.people_outline,
                    text: '$students students',
                  ),
                  _ArchiveFact(
                    icon: Icons.event_available_outlined,
                    text: 'Archived ${_archivedDate()}',
                  ),
                ],
              ),
            ],
          );
          final reportButton = OutlinedButton.icon(
            onPressed: classId.isEmpty
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProgressTrackerPage(
                        classId: classId,
                        className: name,
                      ),
                    ),
                  ),
            icon: const Icon(Icons.analytics_outlined, size: 18),
            label: const Text('View preserved reports'),
          );
          if (constraints.maxWidth < 680) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [details, const SizedBox(height: 13), reportButton],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 16),
              reportButton,
            ],
          );
        },
      ),
    );
  }
}

class _ArchiveFact extends StatelessWidget {
  const _ArchiveFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 15, color: _muted),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(color: _muted, fontSize: 12)),
    ],
  );
}

class _ArchiveMessage extends StatelessWidget {
  const _ArchiveMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(36),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        Icon(icon, size: 42, color: _muted),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _navy,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.4),
        ),
      ],
    ),
  );
}
