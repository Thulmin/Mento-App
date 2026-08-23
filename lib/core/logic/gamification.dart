// Converts completed study activity into points, levels, streaks, and badges.

import '../../data/models/enums.dart';

abstract final class PointsCalculator {
  static int forTaskCompletion(PriorityLevel priority) =>
      8 + priority.weight * 2;

  static int forAssignmentCompletion(PriorityLevel priority) =>
      30 + priority.weight * 5;

  static int forFocusMinutes(
    int activeMinutes, {
    bool completedTarget = false,
  }) {
    if (activeMinutes < 0) {
      throw ArgumentError.value(activeMinutes, 'activeMinutes');
    }
    if (activeMinutes == 0) return 0;
    return activeMinutes ~/ 5 + (completedTarget ? 5 : 0);
  }

  static int forHabitCompletion() => 3;

  static int total({
    Iterable<PriorityLevel> completedTasks = const [],
    Iterable<PriorityLevel> completedAssignments = const [],
    Iterable<int> focusSessionMinutes = const [],
    int completedHabits = 0,
  }) {
    if (completedHabits < 0) {
      throw ArgumentError.value(completedHabits, 'completedHabits');
    }
    return completedTasks.fold<int>(
          0,
          (sum, priority) => sum + forTaskCompletion(priority),
        ) +
        completedAssignments.fold<int>(
          0,
          (sum, priority) => sum + forAssignmentCompletion(priority),
        ) +
        focusSessionMinutes.fold<int>(
          0,
          (sum, minutes) => sum + forFocusMinutes(minutes),
        ) +
        completedHabits * forHabitCompletion();
  }
}

final class GamificationStats {
  const GamificationStats({
    this.completedTasks = 0,
    this.completedAssignments = 0,
    this.focusMinutes = 0,
    this.currentStreak = 0,
    this.masteredTopics = 0,
    this.habitCompletions = 0,
  });

  final int completedTasks;
  final int completedAssignments;
  final int focusMinutes;
  final int currentStreak;
  final int masteredTopics;
  final int habitCompletions;
}

abstract final class BadgeAwardRules {
  static Set<AchievementType> earned(GamificationStats stats) {
    final result = <AchievementType>{};
    if (stats.completedTasks >= 1) result.add(AchievementType.firstTask);
    if (stats.focusMinutes >= 1) {
      result.add(AchievementType.firstFocusSession);
    }
    if (stats.focusMinutes >= 60) result.add(AchievementType.focusedHour);
    if (stats.focusMinutes >= 600) result.add(AchievementType.focusedTenHours);
    if (stats.currentStreak >= 3) result.add(AchievementType.threeDayStreak);
    if (stats.currentStreak >= 7) result.add(AchievementType.sevenDayStreak);
    if (stats.currentStreak >= 30) result.add(AchievementType.thirtyDayStreak);
    if (stats.completedAssignments >= 1) {
      result.add(AchievementType.assignmentCompleted);
    }
    if (stats.masteredTopics >= 1) {
      result.add(AchievementType.topicMastered);
    }
    if (stats.habitCompletions >= 7) {
      result.add(AchievementType.habitBuilder);
    }
    return Set.unmodifiable(result);
  }

  static Set<AchievementType> newlyEarned(
    GamificationStats stats,
    Set<AchievementType> alreadyAwarded,
  ) => Set.unmodifiable(earned(stats).difference(alreadyAwarded));
}

abstract final class StreakCalculator {
  /// A current streak remains intact until the end of the day following the
  /// latest qualifying activity, avoiding punishment early in the current day.
  static int current(
    Iterable<DateTime> qualifyingDates, {
    required DateTime asOf,
  }) {
    final dates =
        qualifyingDates
            .map(_dateOnly)
            .where((date) => !date.isAfter(_dateOnly(asOf)))
            .toSet();
    if (dates.isEmpty) return 0;
    final today = _dateOnly(asOf);
    var cursor =
        dates.contains(today) ? today : today.subtract(const Duration(days: 1));
    if (!dates.contains(cursor)) return 0;
    var count = 0;
    while (dates.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }

  static int longest(Iterable<DateTime> qualifyingDates) {
    final sorted = qualifyingDates.map(_dateOnly).toSet().toList()..sort();
    if (sorted.isEmpty) return 0;
    var longest = 1;
    var running = 1;
    for (var index = 1; index < sorted.length; index++) {
      if (sorted[index].difference(sorted[index - 1]).inDays == 1) {
        running++;
        if (running > longest) longest = running;
      } else {
        running = 1;
      }
    }
    return longest;
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
