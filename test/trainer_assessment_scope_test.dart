import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/screens/staff_outcomes.dart';

void main() {
  test('trainer assessment monitoring keeps only assigned class work', () {
    const assigned = {'class-a', 'class-b'};
    expect(
      trainerValidationBelongsToAssignedClass({
        'classId': 'class-a',
        'reviewerId': 'trainer',
      }, assigned),
      isTrue,
    );
    expect(
      trainerValidationBelongsToAssignedClass({
        'classId': 'teacher-only',
        'reviewerId': 'trainer',
      }, assigned),
      isFalse,
    );
  });
}
