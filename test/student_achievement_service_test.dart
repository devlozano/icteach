import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/services/student_achievement_service.dart';

void main() {
  test('achievements reflect recorded student progress', () {
    final achievements = StudentAchievementService.calculate(
      quizPercentages: const [82, 100],
      completedModules: 2,
      passedSimulations: 1,
      assessmentCompleted: true,
    );
    final byTitle = {for (final item in achievements) item.title: item};
    expect(byTitle['Ready to Learn']!.unlocked, true);
    expect(byTitle['First Quiz']!.unlocked, true);
    expect(byTitle['Quiz Explorer']!.unlocked, false);
    expect(byTitle['Module Starter']!.unlocked, true);
    expect(byTitle['Perfect Score']!.unlocked, true);
    expect(byTitle['High Achiever']!.unlocked, true);
    expect(byTitle['Module Master']!.unlocked, false);
    expect(byTitle['Module Master']!.progress, closeTo(2 / 3, .001));
    expect(byTitle['Tech Explorer']!.unlocked, false);
    expect(byTitle['Simulation Rookie']!.unlocked, true);
    expect(achievements.length, 11);
  });

  test('new students start with every achievement locked', () {
    final achievements = StudentAchievementService.calculate(
      quizPercentages: const [],
      completedModules: 0,
      passedSimulations: 0,
      assessmentCompleted: false,
    );
    expect(achievements.every((item) => !item.unlocked), true);
  });
}
