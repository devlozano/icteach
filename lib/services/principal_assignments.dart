import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SectionDraft {
  String name = '', section = '';
}

class StaffAssignmentDraft {
  final sections = <SectionDraft>[SectionDraft()];
  String? teacherId;
  final classIds = <String>{};
}

class PrincipalAssignments {
  final FirebaseFirestore db;
  final String uid;
  PrincipalAssignments({FirebaseFirestore? firestore, String? principalId})
    : db = firestore ?? FirebaseFirestore.instance,
      uid = principalId ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  Future<void> requirePrincipal() async {
    final user = (await db.collection('users').doc(uid).get()).data();
    if (user?['role'] != 'admin' || user?['isActive'] == false) {
      throw StateError(
        'Only the principal can manage sections and assignments.',
      );
    }
  }

  Future<void> save(
    String staffId,
    String role,
    StaffAssignmentDraft draft,
  ) async {
    await requirePrincipal();
    final staffRef = db.collection('users').doc(staffId);
    final staff = (await staffRef.get()).data();
    if (staff?['role'] != role || staff?['isActive'] == false) {
      throw StateError('Choose an active $role account.');
    }
    if (role == 'teacher') {
      if (draft.sections.isEmpty ||
          draft.sections.length > 50 ||
          draft.sections.any(
            (s) => s.name.trim().isEmpty || s.section.trim().isEmpty,
          )) {
        throw StateError(
          'Enter a class name and section for every class (1 to 50 per save).',
        );
      }
      final year =
          (await db.collection('system_settings').doc('academic_year').get())
              .data()?['activeSchoolYear']
              ?.toString()
              .trim();
      if (year == null || year.isEmpty) {
        throw StateError(
          'Set the active school year in principal settings first.',
        );
      }
      final keys = draft.sections
          .map(
            (s) =>
                '${s.name.trim().toLowerCase()}|${s.section.trim().toLowerCase()}',
          )
          .toSet();
      if (keys.length != draft.sections.length) {
        throw StateError('Each class and section must be unique.');
      }
      final existing = await db
          .collection('classes')
          .where('schoolYear', isEqualTo: year)
          .get();
      if (existing.docs.any(
        (d) => keys.contains(
          '${(d.data()['name'] ?? '').toString().trim().toLowerCase()}|${(d.data()['sectionCode'] ?? '').toString().trim().toLowerCase()}',
        ),
      )) {
        throw StateError(
          'A class with this name and section already exists for this school year.',
        );
      }
      // Deterministic section IDs make duplicate concurrent saves conflict safely.
      final refs = draft.sections
          .map(
            (s) => db
                .collection('classes')
                .doc(
                  sha256
                      .convert(
                        utf8.encode(
                          '$year|${s.name.trim().toLowerCase()}|${s.section.trim().toLowerCase()}',
                        ),
                      )
                      .toString(),
                ),
          )
          .toList();
      await db.runTransaction((tx) async {
        final current = (await tx.get(staffRef)).data();
        if (current?['role'] != 'teacher' || current?['isActive'] == false) {
          throw StateError('Teacher is unavailable.');
        }
        for (final ref in refs) {
          if ((await tx.get(ref)).exists) {
            throw StateError(
              'A class with this name and section already exists for this school year.',
            );
          }
        }
        for (var i = 0; i < refs.length; i++) {
          final ref = refs[i], section = draft.sections[i];
          tx.set(ref, {
            'id': ref.id,
            'name': section.name.trim(),
            'sectionCode': section.section.trim(),
            'description': '',
            'teacherId': staffId,
            'teacherName': current?['name'] ?? current?['displayName'] ?? '',
            'teacherEmail': current?['email'] ?? '',
            'classCode': ref.id.substring(0, 7).toUpperCase(),
            'schoolYear': year,
            'status': 'active',
            'enrolledStudentIds': <String>[],
            'trainerIds': <String>[],
            'pendingReviews': 0,
            'createdBy': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } else if (role == 'trainer') {
      if (draft.teacherId == null || draft.classIds.isEmpty) {
        throw StateError('Select a teacher and at least one active class.');
      }
      if (draft.classIds.length > 50) {
        throw StateError('Assign up to 50 classes per save.');
      }
      final existingAssignments = await db
          .collection('classes')
          .where('trainerIds', arrayContains: staffId)
          .get();
      await db.runTransaction((tx) async {
        final teacher = (await tx.get(
          db.collection('users').doc(draft.teacherId),
        )).data();
        final trainer = (await tx.get(staffRef)).data();
        if (teacher?['role'] != 'teacher' ||
            teacher?['isActive'] == false ||
            trainer?['isActive'] == false) {
          throw StateError('Choose active staff accounts.');
        }
        final classes = <DocumentSnapshot<Map<String, dynamic>>>[];
        for (final id in draft.classIds) {
          final doc = await tx.get(db.collection('classes').doc(id));
          if (!doc.exists ||
              doc.data()?['teacherId'] != draft.teacherId ||
              doc.data()?['status'] == 'archived') {
            throw StateError(
              'A selected class is unavailable or belongs to another teacher. Refresh your selection.',
            );
          }
          classes.add(doc);
        }
        final selectedIds = draft.classIds;
        for (final classroom in existingAssignments.docs) {
          if (selectedIds.contains(classroom.id)) continue;
          tx.update(classroom.reference, {
            'trainerIds': FieldValue.arrayRemove([staffId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.delete(staffRef.collection('classes').doc(classroom.id));
        }
        for (final classroom in classes) {
          tx.update(classroom.reference, {
            'trainerIds': FieldValue.arrayUnion([staffId]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          tx.set(
            staffRef.collection('classes').doc(classroom.id),
            {
              'classId': classroom.id,
              'teacherId': draft.teacherId,
              'className': classroom.data()?['name'] ?? '',
              'role': 'trainer',
              'assignedBy': uid,
              'assignedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      });
    } else {
      throw StateError('Choose Teacher or Trainer.');
    }
  }
}
