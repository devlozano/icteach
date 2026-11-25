import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/assignment_model.dart';

class AssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _ensureSubmissionReviewer() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');

    final profile = await _firestore.collection('users').doc(user.uid).get();
    final role = profile.data()?['role']?.toString().toLowerCase();
    const reviewerRoles = {'teacher', 'trainer', 'admin', 'administrator'};
    if (!reviewerRoles.contains(role)) {
      throw Exception('You are not allowed to review student submissions.');
    }
  }

  // Get all assignments for a class (sorted in memory)
  Stream<List<AssignmentModel>> getAssignmentsForClass(String classId) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('assignments')
        .snapshots()
        .map((snapshot) {
          final assignments = snapshot.docs
              .map((doc) => AssignmentModel.fromFirestore(doc))
              .toList();
          assignments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return assignments;
        });
  }

  // Get published assignments for students
  Stream<List<AssignmentModel>> getPublishedAssignmentsForClass(
    String classId,
  ) {
    return _firestore
        .collection('classes')
        .doc(classId)
        .collection('assignments')
        .where('isPublished', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final assignments = snapshot.docs
              .map((doc) => AssignmentModel.fromFirestore(doc))
              .toList();
          assignments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
          return assignments;
        });
  }

  // Create a new assignment
  Future<void> createAssignment(AssignmentModel assignment) async {
    try {
      final docRef = _firestore
          .collection('classes')
          .doc(assignment.classId)
          .collection('assignments')
          .doc();

      final data = assignment.toFirestore();
      data['id'] = docRef.id;
      data['createdAt'] = FieldValue.serverTimestamp();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await docRef.set(data);
      print('✅ Assignment created: ${assignment.title}');
    } catch (e) {
      print('❌ Error creating assignment: $e');
      rethrow;
    }
  }

  // ✅ FIXED: Update an existing assignment
  Future<void> updateAssignment(
    String classId,
    AssignmentModel assignment,
  ) async {
    try {
      final data = assignment.toFirestore();
      data['updatedAt'] = FieldValue.serverTimestamp();

      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('assignments')
          .doc(assignment.id)
          .update(data);
      print('✅ Assignment updated: ${assignment.title}');
    } catch (e) {
      print('❌ Error updating assignment: $e');
      rethrow;
    }
  }

  // Delete an assignment
  Future<void> deleteAssignment(String classId, String assignmentId) async {
    try {
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('assignments')
          .doc(assignmentId)
          .delete();
      print('✅ Assignment deleted: $assignmentId');
    } catch (e) {
      print('❌ Error deleting assignment: $e');
      rethrow;
    }
  }

  // Toggle publish status
  Future<void> togglePublish(
    String classId,
    String assignmentId,
    bool isPublished,
  ) async {
    try {
      await _firestore
          .collection('classes')
          .doc(classId)
          .collection('assignments')
          .doc(assignmentId)
          .update({
            'isPublished': isPublished,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      print('✅ Assignment publish toggled: $assignmentId -> $isPublished');
    } catch (e) {
      print('❌ Error toggling publish: $e');
      rethrow;
    }
  }

  // Submit assignment
  Future<void> submitAssignment(AssignmentSubmission submission) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }
      if (submission.studentId != user.uid) {
        throw Exception('Submission owner does not match the signed-in user.');
      }

      final docId = '${submission.assignmentId}_${user.uid}';
      await _firestore
          .collection('submissions')
          .doc(docId)
          .set(submission.toFirestore());
      print('✅ Assignment submitted: ${submission.assignmentId}');
    } catch (e) {
      print('❌ Error submitting assignment: $e');
      rethrow;
    }
  }

  // Get student's submission for an assignment
  Future<AssignmentSubmission?> getStudentSubmission(
    String assignmentId,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('submissions')
          .doc('${assignmentId}_${user.uid}')
          .get();

      if (doc.exists) {
        return AssignmentSubmission.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('❌ Error getting student submission: $e');
      return null;
    }
  }

  // Get all submissions for an assignment (teacher view)
  Future<List<AssignmentSubmission>> getSubmissionsForAssignment(
    String classId,
    String assignmentId,
  ) async {
    try {
      await _ensureSubmissionReviewer();
      final snapshot = await _firestore
          .collection('submissions')
          .where('classId', isEqualTo: classId)
          .where('assignmentId', isEqualTo: assignmentId)
          .get();

      final submissions = snapshot.docs
          .map((doc) => AssignmentSubmission.fromFirestore(doc))
          .toList();

      // Sort in memory by submittedAt (descending)
      submissions.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

      return submissions;
    } catch (e) {
      print('❌ Error getting submissions: $e');
      return [];
    }
  }

  // Grade a submission
  Future<void> gradeSubmission(
    String submissionId,
    int score,
    String feedback,
  ) async {
    try {
      await _ensureSubmissionReviewer();
      await _firestore.collection('submissions').doc(submissionId).update({
        'score': score,
        'feedback': feedback,
        'isGraded': true,
        'gradedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Submission graded: $submissionId');
    } catch (e) {
      print('❌ Error grading submission: $e');
      rethrow;
    }
  }

  // Check if student has submitted
  Future<bool> hasSubmitted(String assignmentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection('submissions')
          .doc('${assignmentId}_${user.uid}')
          .get();

      return doc.exists;
    } catch (e) {
      print('❌ Error checking submission: $e');
      return false;
    }
  }

  // Get submission count for an assignment
  Future<int> getSubmissionCount(String classId, String assignmentId) async {
    try {
      await _ensureSubmissionReviewer();
      final snapshot = await _firestore
          .collection('submissions')
          .where('classId', isEqualTo: classId)
          .where('assignmentId', isEqualTo: assignmentId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting submission count: $e');
      return 0;
    }
  }

  // Get graded count for an assignment
  Future<int> getGradedCount(String classId, String assignmentId) async {
    try {
      await _ensureSubmissionReviewer();
      final snapshot = await _firestore
          .collection('submissions')
          .where('classId', isEqualTo: classId)
          .where('assignmentId', isEqualTo: assignmentId)
          .where('isGraded', isEqualTo: true)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('❌ Error getting graded count: $e');
      return 0;
    }
  }

  // Get average score for an assignment
  Future<double> getAverageScore(String classId, String assignmentId) async {
    try {
      final submissions = await getSubmissionsForAssignment(
        classId,
        assignmentId,
      );
      final graded = submissions.where((s) => s.isGraded).toList();
      if (graded.isEmpty) return 0.0;

      final total = graded.fold<int>(0, (sum, s) => sum + s.score);
      return total / graded.length;
    } catch (e) {
      print('❌ Error getting average score: $e');
      return 0.0;
    }
  }
}
