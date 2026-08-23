import 'package:flutter_test/flutter_test.dart';
import 'package:mento/core/logic/logic.dart';
import 'package:mento/data/models/models.dart';

void main() {
  group('gamification', () {
    test('calculates deterministic points', () {
      expect(PointsCalculator.forTaskCompletion(PriorityLevel.urgent), 16);
      expect(PointsCalculator.forFocusMinutes(50, completedTarget: true), 15);
      expect(
        PointsCalculator.total(
          completedTasks: const [PriorityLevel.low, PriorityLevel.high],
          completedAssignments: const [PriorityLevel.medium],
          focusSessionMinutes: const [25],
          completedHabits: 2,
        ),
        10 + 14 + 40 + 5 + 6,
      );
    });

    test('awards only newly reached badges', () {
      const stats = GamificationStats(
        completedTasks: 2,
        completedAssignments: 1,
        focusMinutes: 70,
        currentStreak: 7,
        masteredTopics: 1,
        habitCompletions: 8,
      );
      final badges = BadgeAwardRules.newlyEarned(stats, {
        AchievementType.firstTask,
      });

      expect(badges, isNot(contains(AchievementType.firstTask)));
      expect(badges, contains(AchievementType.focusedHour));
      expect(badges, contains(AchievementType.sevenDayStreak));
      expect(badges, contains(AchievementType.topicMastered));
    });

    test('calculates current and longest streaks using unique dates', () {
      final dates = [
        DateTime(2026, 1, 1, 9),
        DateTime(2026, 1, 2, 9),
        DateTime(2026, 1, 2, 18),
        DateTime(2026, 1, 3, 9),
        DateTime(2026, 1, 5, 9),
        DateTime(2026, 1, 6, 9),
      ];

      expect(StreakCalculator.current(dates, asOf: DateTime(2026, 1, 7, 8)), 2);
      expect(StreakCalculator.longest(dates), 3);
    });
  });

  group('TopicMasteryCalculator', () {
    test('combines study, task, quiz, and recency evidence', () {
      final score = TopicMasteryCalculator.calculate(
        TopicEvidence(
          studyMinutes: 180,
          completedTasks: 4,
          totalTasks: 4,
          quizAverage: 0.9,
          lastActivityAt: DateTime.utc(2026, 1, 9),
        ),
        now: DateTime.utc(2026, 1, 10),
      );

      expect(score.total, closeTo(0.97, 0.0001));
      expect(score.isMastered, isTrue);
    });

    test('recency contribution decays transparently', () {
      final recent = TopicMasteryCalculator.calculate(
        TopicEvidence(
          studyMinutes: 60,
          completedTasks: 1,
          totalTasks: 2,
          lastActivityAt: DateTime.utc(2026, 1, 9),
        ),
        now: DateTime.utc(2026, 1, 10),
      );
      final old = TopicMasteryCalculator.calculate(
        TopicEvidence(
          studyMinutes: 60,
          completedTasks: 1,
          totalTasks: 2,
          lastActivityAt: DateTime.utc(2025, 1, 1),
        ),
        now: DateTime.utc(2026, 1, 10),
      );

      expect(recent.total, greaterThan(old.total));
    });
  });
}
