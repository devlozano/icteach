import 'package:flutter/material.dart';
import '../screens/teacher/manage_modules_page.dart';
import '../screens/teacher/manage_quizzes_page.dart';
import '../screens/teacher/manage_assignments_page.dart';
import '../screens/teacher/progress_tracker_page.dart';
import '../screens/teacher/assessment_review_page.dart';

Widget trainerDestination(String action, String classId, String className) {
  switch (action) {
    case 'modules':
    case 'videos':
      return ManageModulesPage(classId: classId, className: className);
    case 'quizzes':
      return ManageQuizzesPage(classId: classId, className: className);
    case 'assignments':
      return ManageAssignmentsPage(classId: classId, className: className);
    case 'progress':
      return ProgressTrackerPage(classId: classId, className: className);
    case 'competency':
      return AssessmentReviewPage(classId: classId, className: className);
    default:
      throw ArgumentError.value(
        action,
        'action',
        'Unknown trainer destination',
      );
  }
}
