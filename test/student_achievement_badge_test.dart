import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icteach/home.dart';
import 'package:icteach/services/student_achievement_service.dart';

void main() {
  testWidgets('achievement medal distinguishes unlocked and locked badges', (
    tester,
  ) async {
    const unlocked = StudentAchievement(
      title: 'Learning Champion',
      description: 'Complete 5 modules',
      icon: 'crown',
      current: 5,
      target: 5,
    );
    const locked = StudentAchievement(
      title: 'Simulation Specialist',
      description: 'Pass 5 simulations',
      icon: 'shield',
      current: 1,
      target: 5,
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              AchievementMedal(achievement: unlocked),
              AchievementMedal(achievement: locked),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
