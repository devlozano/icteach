import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/academic_year_validation.dart';

class SchoolYearRolloverResult {
  const SchoolYearRolloverResult({
    required this.activeSchoolYear,
    required this.archivedClasses,
    required this.archiveNames,
  });

  final String activeSchoolYear;
  final int archivedClasses;
  final List<String> archiveNames;
}

class SchoolYearArchiveException implements Exception {
  const SchoolYearArchiveException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SchoolYearRolloverService {
  SchoolYearRolloverService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  String _text(dynamic value, int maximum, {String fallback = ''}) {
    final text = (value ?? fallback).toString().trim();
    return text.length <= maximum ? text : text.substring(0, maximum);
  }

  Map<String, dynamic> _classIndexData(
    DocumentSnapshot<Map<String, dynamic>> document,
    String schoolYear,
    dynamic archivedAt,
  ) {
    final data = document.data()!;
    return {
      'classId': document.id,
      'className': _text(
        data['className'] ?? data['name'],
        100,
        fallback: 'Class',
      ),
      'sectionCode': _text(data['sectionCode'] ?? data['section'], 60),
      'teacherId': _text(data['teacherId'], 128),
      'teacherName': _text(data['teacherName'], 200),
      'schoolYear': schoolYear,
      'sourcePath': document.reference.path,
      'archivedAt': archivedAt,
      'dataPreservedInSource': true,
    };
  }

  Future<String> archiveClass(
    String classId, {
    String reason = 'Archived by principal from Manage Classes',
  }) async {
    final classRef = _db.collection('classes').doc(classId);
    final results = await Future.wait([
      classRef.get(),
      _db.collection('system_settings').doc('academic_year').get(),
    ]);
    final classDocument = results[0];
    final settings = results[1];
    if (!classDocument.exists || classDocument.data() == null) {
      throw const SchoolYearArchiveException('This class no longer exists.');
    }

    final data = classDocument.data()!;
    final schoolYear = data['schoolYear']?.toString();
    final activeYear =
        settings.data()?['activeSchoolYear']?.toString() ??
        AcademicYearValidation.activeSchoolYear();
    final validationError = AcademicYearValidation.classArchiveError(
      status: data['status']?.toString(),
      classSchoolYear: schoolYear,
      activeSchoolYear: activeYear,
    );
    if (validationError != null) {
      throw SchoolYearArchiveException(validationError);
    }

    final archivedAt = FieldValue.serverTimestamp();
    final indexRef = _db
        .collection('school_year_archives')
        .doc(schoolYear!)
        .collection('classes')
        .doc(classId);
    final batch = _db.batch();
    batch.update(classRef, {
      'status': 'archived',
      'archivedAt': archivedAt,
      'archiveSchoolYear': schoolYear,
      'archiveReason': _text(reason, 200),
    });
    batch.set(
      indexRef,
      _classIndexData(classDocument, schoolYear, archivedAt),
      SetOptions(merge: true),
    );
    await batch.commit();

    final archivedCount = await _db
        .collection('classes')
        .where('schoolYear', isEqualTo: schoolYear)
        .where('status', isEqualTo: 'archived')
        .count()
        .get();
    await _db.collection('school_year_archives').doc(schoolYear).set({
      'name': schoolYear,
      'schoolYear': schoolYear,
      'status': 'archived',
      'classCount': archivedCount.count ?? 0,
      'dataLocation': 'classes and their nested subcollections',
      'dataPreservedInSource': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return schoolYear;
  }

  Future<SchoolYearRolloverResult> rollForward({
    String? targetSchoolYear,
  }) async {
    final settingsRef = _db.collection('system_settings').doc('academic_year');
    final settings = await settingsRef.get();
    final configured = settings.data()?['activeSchoolYear']?.toString();
    final calendarYear = AcademicYearValidation.activeSchoolYear();
    final requested = targetSchoolYear ?? calendarYear;
    final configuredStart = AcademicYearValidation.parseStartYear(configured);
    final requestedStart = AcademicYearValidation.parseStartYear(requested);
    final calendarStart = AcademicYearValidation.parseStartYear(calendarYear)!;

    if (requestedStart == null) {
      throw const FormatException('The selected school year is invalid.');
    }

    // Never move a principal-prepared future school year backwards.
    if (targetSchoolYear == null &&
        configuredStart != null &&
        configuredStart > calendarStart) {
      return SchoolYearRolloverResult(
        activeSchoolYear: configured!,
        archivedClasses: 0,
        archiveNames: const [],
      );
    }
    final effectiveYear = requested;
    final effectiveStart = AcademicYearValidation.parseStartYear(
      effectiveYear,
    )!;
    final classes = await _db.collection('classes').get();
    final pastClasses = classes.docs.where((document) {
      return AcademicYearValidation.isBefore(
        document.data()['schoolYear']?.toString(),
        effectiveYear,
      );
    }).toList();

    final grouped =
        <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final document in pastClasses) {
      final schoolYear = document.data()['schoolYear'].toString();
      grouped.putIfAbsent(schoolYear, () => []).add(document);
    }

    var archivedClasses = 0;
    for (final entry in grouped.entries) {
      final schoolYear = entry.key;
      final records = entry.value;
      for (var offset = 0; offset < records.length; offset += 200) {
        final end = (offset + 200).clamp(0, records.length);
        final batch = _db.batch();
        for (final document in records.sublist(offset, end)) {
          final data = document.data();
          final archivedAt = data['archivedAt'] ?? FieldValue.serverTimestamp();
          if (data['status'] != 'archived') {
            batch.update(document.reference, {
              'status': 'archived',
              'archivedAt': archivedAt,
              'archiveSchoolYear': schoolYear,
              'archiveReason': 'School year advanced to $effectiveYear',
            });
            archivedClasses++;
          }
          final indexRef = _db
              .collection('school_year_archives')
              .doc(schoolYear)
              .collection('classes')
              .doc(document.id);
          batch.set(
            indexRef,
            _classIndexData(document, schoolYear, archivedAt),
            SetOptions(merge: true),
          );
        }
        await batch.commit();
      }

      await _db.collection('school_year_archives').doc(schoolYear).set({
        'name': schoolYear,
        'schoolYear': schoolYear,
        'status': 'archived',
        'classCount': records.length,
        'dataLocation': 'classes and their nested subcollections',
        'dataPreservedInSource': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await settingsRef.set({
      'activeSchoolYear': effectiveYear,
      'startYear': effectiveStart,
      'endYear': effectiveStart + 1,
      'previousSchoolYear':
          configuredStart != null && configuredStart < effectiveStart
          ? configured
          : settings.data()?['previousSchoolYear'],
      'lastAutomaticArchiveCheckAt': FieldValue.serverTimestamp(),
      if (configuredStart == null || configuredStart < effectiveStart)
        'lastRolloverAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return SchoolYearRolloverResult(
      activeSchoolYear: effectiveYear,
      archivedClasses: archivedClasses,
      archiveNames: grouped.keys.toList()..sort(),
    );
  }
}
