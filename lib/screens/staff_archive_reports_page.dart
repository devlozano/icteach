import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/class_summary_service.dart';
import '../services/report_export_service.dart';
import '../services/workspace_data.dart';
import '../widgets/summary_print_button.dart';

class StaffSchoolYearSummary {
  const StaffSchoolYearSummary({
    required this.schoolYear,
    required this.classCount,
    required this.activeClasses,
    required this.archivedClasses,
    required this.studentCount,
  });

  final String schoolYear;
  final int classCount;
  final int activeClasses;
  final int archivedClasses;
  final int studentCount;
}

List<StaffSchoolYearSummary> buildStaffSchoolYearSummaries(
  Iterable<Map<String, dynamic>> classes,
) {
  final grouped = <String, List<Map<String, dynamic>>>{};
  for (final classroom in classes) {
    final value = classroom['schoolYear']?.toString().trim() ?? '';
    final year = value.isEmpty ? 'Unspecified' : value;
    grouped.putIfAbsent(year, () => []).add(classroom);
  }
  final years = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final year in years)
      StaffSchoolYearSummary(
        schoolYear: year,
        classCount: grouped[year]!.length,
        activeClasses: grouped[year]!
            .where((item) => item['status'] != 'archived')
            .length,
        archivedClasses: grouped[year]!
            .where((item) => item['status'] == 'archived')
            .length,
        studentCount: {
          for (final item in grouped[year]!)
            ...List<String>.from(
              item['enrolledStudentIds'] as List? ?? const [],
            ),
        }.length,
      ),
  ];
}

class StaffArchiveReportsPage extends StatefulWidget {
  const StaffArchiveReportsPage({
    super.key,
    required this.role,
    required this.onOpenClassReport,
  });

  final String role;
  final void Function(String classId, String className) onOpenClassReport;

  @override
  State<StaffArchiveReportsPage> createState() =>
      _StaffArchiveReportsPageState();
}

class _StaffArchiveReportsPageState extends State<StaffArchiveReportsPage> {
  String? _schoolYear;
  String? _classId;
  String _status = 'all';
  String _query = '';
  bool _exporting = false;

  bool get _trainer => widget.role == 'trainer';

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _classes(
    String uid,
  ) => _trainer
      ? WorkspaceData.assignedClasses(uid)
      : WorkspaceData.teacherClassDocs(uid);

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filtered(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> classes,
  ) {
    return classes.where((item) {
      final data = item.data();
      final archived = data['status']?.toString() == 'archived';
      if (_schoolYear != null &&
          data['schoolYear']?.toString() != _schoolYear) {
        return false;
      }
      if (_classId != null && item.id != _classId) return false;
      if (_status == 'active' && archived) return false;
      if (_status == 'archived' && !archived) return false;
      if (_query.isNotEmpty) {
        final text = [
          data['name'],
          data['sectionCode'],
          data['schoolYear'],
          data['teacherName'],
        ].join(' ').toLowerCase();
        if (!text.contains(_query)) return false;
      }
      return true;
    }).toList()..sort((a, b) {
      final byYear = (b.data()['schoolYear']?.toString() ?? '').compareTo(
        a.data()['schoolYear']?.toString() ?? '',
      );
      if (byYear != 0) return byYear;
      return (a.data()['name']?.toString() ?? '').compareTo(
        b.data()['name']?.toString() ?? '',
      );
    });
  }

  List<SummarySection> _overview(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> classes,
  ) {
    final students = <String>{};
    var active = 0;
    var archived = 0;
    for (final classroom in classes) {
      final data = classroom.data();
      students.addAll(
        List<String>.from(data['enrolledStudentIds'] as List? ?? const []),
      );
      if (data['status']?.toString() == 'archived') {
        archived++;
      } else {
        active++;
      }
    }
    final byYear = buildStaffSchoolYearSummaries(
      classes.map((item) => item.data()),
    );
    return [
      SummarySection(
        '${_trainer ? 'Trainer' : 'Teacher'} school year overview',
        const ['School year', 'Classes', 'Active', 'Archived', 'Students'],
        [
          [
            _schoolYear ?? 'All school years',
            classes.length,
            active,
            archived,
            students.length,
          ],
        ],
      ),
      SummarySection(
        'Summary by school year',
        const ['School year', 'Classes', 'Active', 'Archived', 'Students'],
        [
          for (final year in byYear)
            [
              year.schoolYear,
              year.classCount,
              year.activeClasses,
              year.archivedClasses,
              year.studentCount,
            ],
        ],
      ),
      SummarySection(
        'Class summary',
        const ['Class', 'Section', 'School year', 'Status', 'Students'],
        [
          for (final classroom in classes)
            [
              classroom.data()['name'] ?? 'Untitled class',
              classroom.data()['sectionCode'] ?? '',
              classroom.data()['schoolYear'] ?? '',
              classroom.data()['status'] == 'archived' ? 'Archived' : 'Active',
              (classroom.data()['enrolledStudentIds'] as List?)?.length ?? 0,
            ],
        ],
      ),
    ];
  }

  Future<List<SummarySection>> _reportSections(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> classes,
  ) async {
    final sections = <SummarySection>[..._overview(classes)];
    for (final classroom in classes) {
      final data = classroom.data();
      final className = data['name']?.toString() ?? 'Untitled class';
      final details = await ClassSummaryService.load(
        classroom.id,
        role: widget.role,
        userId: FirebaseAuth.instance.currentUser?.uid,
      );
      for (final section in details) {
        sections.add(
          SummarySection(
            '$className - ${section.title}',
            section.columns,
            section.rows,
          ),
        );
      }
    }
    return sections;
  }

  Future<void> _exportCsv(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> classes,
  ) async {
    setState(() => _exporting = true);
    try {
      final summaries = buildStaffSchoolYearSummaries(
        classes.map((item) => item.data()),
      );
      final rows = <List<Object?>>[
        ['SUMMARY BY SCHOOL YEAR'],
        ['School year', 'Classes', 'Active', 'Archived', 'Students'],
        for (final year in summaries)
          [
            year.schoolYear,
            year.classCount,
            year.activeClasses,
            year.archivedClasses,
            year.studentCount,
          ],
        const <Object?>[],
        ['CLASS DETAILS'],
        ['Class', 'Section', 'School year', 'Status', 'Students'],
        for (final classroom in classes)
          [
            classroom.data()['name'],
            classroom.data()['sectionCode'],
            classroom.data()['schoolYear'],
            classroom.data()['status'] == 'archived' ? 'Archived' : 'Active',
            (classroom.data()['enrolledStudentIds'] as List?)?.length ?? 0,
          ],
      ];
      final role = _trainer ? 'trainer' : 'teacher';
      final year = (_schoolYear ?? 'all-years').replaceAll(' ', '-');
      await ReportExportService.shareCsv('$role-report-$year.csv', rows);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sign in to view archived reports.'));
    }
    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      stream: _classes(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _Message(
            icon: Icons.cloud_off_rounded,
            title: 'Reports could not be loaded',
            message: snapshot.error.toString(),
          );
        }
        final allClasses = snapshot.data ?? const [];
        final years =
            allClasses
                .map(
                  (item) => item.data()['schoolYear']?.toString().trim() ?? '',
                )
                .where((year) => year.isNotEmpty)
                .toSet()
                .toList()
              ..sort((a, b) => b.compareTo(a));
        if (_schoolYear != null && !years.contains(_schoolYear)) {
          _schoolYear = null;
        }
        final yearClasses = allClasses
            .where(
              (item) =>
                  _schoolYear == null ||
                  item.data()['schoolYear']?.toString() == _schoolYear,
            )
            .toList();
        if (_classId != null &&
            !yearClasses.any((item) => item.id == _classId)) {
          _classId = null;
        }
        final classes = _filtered(allClasses);
        final archived = classes
            .where((item) => item.data()['status'] == 'archived')
            .length;
        final studentIds = <String>{
          for (final item in classes)
            ...List<String>.from(
              item.data()['enrolledStudentIds'] as List? ?? const [],
            ),
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(role: widget.role),
              const SizedBox(height: 16),
              _Filters(
                years: years,
                classes: yearClasses,
                schoolYear: _schoolYear,
                classId: _classId,
                status: _status,
                onYear: (value) => setState(() {
                  _schoolYear = value;
                  _classId = null;
                }),
                onClass: (value) => setState(() => _classId = value),
                onStatus: (value) => setState(() => _status = value),
                onSearch: (value) =>
                    setState(() => _query = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _Stat('Classes', '${classes.length}', Icons.class_outlined),
                  _Stat('Archived', '$archived', Icons.inventory_2_outlined),
                  _Stat(
                    'Students',
                    '${studentIds.length}',
                    Icons.people_outline,
                  ),
                  _Stat(
                    'School year',
                    _schoolYear ?? 'All years',
                    Icons.calendar_month_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'School year summary',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SummaryPrintButton(
                    title:
                        '${_trainer ? 'Trainer' : 'Teacher'} report - ${_schoolYear ?? 'All school years'}',
                    load: () => _reportSections(classes),
                  ),
                  const SizedBox(width: 6),
                  OutlinedButton.icon(
                    onPressed: classes.isEmpty || _exporting
                        ? null
                        : () => _exportCsv(classes),
                    icon: _exporting
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.table_view_outlined, size: 18),
                    label: const Text('CSV'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (classes.isEmpty)
                const _Message(
                  icon: Icons.inventory_2_outlined,
                  title: 'No classes match these filters',
                  message: 'Choose another school year, class, or status.',
                )
              else
                ...classes.map(
                  (item) => _ClassCard(
                    document: item,
                    onOpenReport: widget.onOpenClassReport,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.role});
  final String role;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF0F3A5B), Color(0xFF087F8C)],
      ),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Row(
      children: [
        const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 34),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Archives & Reports',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                role == 'trainer'
                    ? 'Review only your assigned classes and your own training records.'
                    : 'Review your active and archived classes by school year.',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Filters extends StatelessWidget {
  const _Filters({
    required this.years,
    required this.classes,
    required this.schoolYear,
    required this.classId,
    required this.status,
    required this.onYear,
    required this.onClass,
    required this.onStatus,
    required this.onSearch,
  });
  final List<String> years;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> classes;
  final String? schoolYear;
  final String? classId;
  final String status;
  final ValueChanged<String?> onYear;
  final ValueChanged<String?> onClass;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth < 720
          ? constraints.maxWidth
          : (constraints.maxWidth - 36) / 4;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: width,
            child: DropdownButtonFormField<String?>(
              initialValue: schoolYear,
              decoration: const InputDecoration(
                labelText: 'School year',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All years')),
                for (final year in years)
                  DropdownMenuItem(value: year, child: Text(year)),
              ],
              onChanged: onYear,
            ),
          ),
          SizedBox(
            width: width,
            child: DropdownButtonFormField<String?>(
              initialValue: classId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Class',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('All classes')),
                for (final item in classes)
                  DropdownMenuItem(
                    value: item.id,
                    child: Text(
                      item.data()['name']?.toString() ?? 'Untitled class',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              selectedItemBuilder: (context) => [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'All classes',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                for (final item in classes)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.data()['name']?.toString() ?? 'Untitled class',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: onClass,
            ),
          ),
          SizedBox(
            width: width,
            child: DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All classes')),
                DropdownMenuItem(value: 'active', child: Text('Active')),
                DropdownMenuItem(value: 'archived', child: Text('Archived')),
              ],
              onChanged: (value) {
                if (value != null) onStatus(value);
              },
            ),
          ),
          SizedBox(
            width: width,
            child: TextField(
              onChanged: onSearch,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.icon);
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 185,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF0891B2)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(label, style: const TextStyle(color: Color(0xFF64748B))),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({required this.document, required this.onOpenReport});
  final QueryDocumentSnapshot<Map<String, dynamic>> document;
  final void Function(String classId, String className) onOpenReport;

  @override
  Widget build(BuildContext context) {
    final data = document.data();
    final archived = data['status'] == 'archived';
    final name = data['name']?.toString() ?? 'Untitled class';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: archived
              ? const Color(0xFFF1F5F9)
              : const Color(0xFFE0F2FE),
          child: Icon(
            archived ? Icons.inventory_2_outlined : Icons.class_outlined,
            color: archived ? const Color(0xFF64748B) : const Color(0xFF0369A1),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            _Badge(archived: archived),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${data['sectionCode'] ?? 'No section'}  |  SY ${data['schoolYear'] ?? 'Unspecified'}  |  ${(data['enrolledStudentIds'] as List?)?.length ?? 0} students',
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              onPressed: () => onOpenReport(document.id, name),
              tooltip: 'Open class report',
              icon: const Icon(Icons.analytics_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.archived});
  final bool archived;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: archived ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      archived ? 'Archived' : 'Active',
      style: TextStyle(
        color: archived ? const Color(0xFF475569) : const Color(0xFF166534),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message({
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
    padding: const EdgeInsets.all(32),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE2E8F0)),
    ),
    child: Column(
      children: [
        Icon(icon, size: 40, color: const Color(0xFF64748B)),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(message, textAlign: TextAlign.center),
      ],
    ),
  );
}
