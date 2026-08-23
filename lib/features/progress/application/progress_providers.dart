// Combines study history into progress totals, streaks, and mastery summaries.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/logic.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

DateTime get _historyStart =>
    DateTime.now().subtract(const Duration(days: 370));
DateTime get _historyEnd => DateTime.now().add(const Duration(days: 370));

final progressTasksProvider = StreamProvider<List<StudyTask>>(
  (ref) => ref
      .watch(studentRepositoryProvider)
      .watchStudyTasks(dueFrom: _historyStart, dueBefore: _historyEnd),
);
final progressAssignmentsProvider = StreamProvider<List<Assignment>>(
  (ref) => ref
      .watch(studentRepositoryProvider)
      .watchAssignments(dueFrom: _historyStart, dueBefore: _historyEnd),
);
final progressFocusProvider = StreamProvider<List<FocusSession>>(
  (ref) => ref.watch(studentRepositoryProvider).watchFocusSessions(),
);
final progressHabitLogsProvider = StreamProvider<List<HabitLog>>(
  (ref) => ref
      .watch(studentRepositoryProvider)
      .watchHabitLogs(from: _historyStart, before: _historyEnd),
);
final progressAchievementsProvider = StreamProvider<List<Achievement>>(
  (ref) => ref.watch(studentRepositoryProvider).watchAchievements(),
);
final progressMasteryProvider = StreamProvider<List<TopicMasteryRecord>>(
  (ref) => ref.watch(studentRepositoryProvider).watchTopicMastery(),
);
final progressModulesProvider = StreamProvider<List<Module>>(
  (ref) => ref.watch(studentRepositoryProvider).watchModules(),
);

class ProgressSummary {
  const ProgressSummary({
    required this.points,
    required this.level,
    required this.completedTasks,
    required this.completedAssignments,
    required this.focusMinutes,
    required this.weekFocusMinutes,
    required this.habitCompletions,
    required this.currentStreak,
    required this.longestStreak,
    required this.masteredTopics,
    required this.badges,
  });

  final int points;
  final int level;
  final int completedTasks;
  final int completedAssignments;
  final int focusMinutes;
  final int weekFocusMinutes;
  final int habitCompletions;
  final int currentStreak;
  final int longestStreak;
  final int masteredTopics;
  final Set<AchievementType> badges;

  int get nextLevelAt => level * 250;
  int get previousLevelAt => (level - 1) * 250;
  double get levelProgress =>
      ((points - previousLevelAt) / (nextLevelAt - previousLevelAt)).clamp(
        0,
        1,
      );
}

ProgressSummary calculateProgressSummary({
  required List<StudyTask> tasks,
  required List<Assignment> assignments,
  required List<FocusSession> focusSessions,
  required List<HabitLog> habitLogs,
  required List<TopicMasteryRecord> mastery,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final completedTasks = tasks.where((item) => item.isCompleted).toList();
  final completedAssignments =
      assignments.where((item) => item.status == WorkStatus.completed).toList();
  final completedFocus =
      focusSessions
          .where(
            (item) =>
                item.state == FocusSessionState.completed && !item.isBreak,
          )
          .toList();
  final focusMinutes = completedFocus.fold<int>(
    0,
    (sum, item) => sum + item.accumulatedActiveSeconds ~/ 60,
  );
  final weekStart = DateTime(
    clock.year,
    clock.month,
    clock.day,
  ).subtract(Duration(days: clock.weekday - 1));
  final weekFocus = completedFocus
      .where((item) => !item.startedAt.isBefore(weekStart))
      .fold<int>(0, (sum, item) => sum + item.accumulatedActiveSeconds ~/ 60);
  final points = PointsCalculator.total(
    completedTasks: completedTasks.map((item) => item.priority),
    completedAssignments: completedAssignments.map((item) => item.priority),
    focusSessionMinutes: completedFocus.map(
      (item) => item.accumulatedActiveSeconds ~/ 60,
    ),
    completedHabits: habitLogs.where((item) => item.isCompleted).length,
  );
  final activityDates = <DateTime>[
    ...completedTasks.map((item) => item.completedAt).whereType<DateTime>(),
    ...completedFocus.map((item) => item.endedAt).whereType<DateTime>(),
    ...habitLogs.where((item) => item.isCompleted).map((item) => item.date),
  ];
  final currentStreak = StreakCalculator.current(activityDates, asOf: clock);
  final longestStreak = StreakCalculator.longest(activityDates);
  final mastered = mastery.where((item) => item.mastery >= 0.8).length;
  final stats = GamificationStats(
    completedTasks: completedTasks.length,
    completedAssignments: completedAssignments.length,
    focusMinutes: focusMinutes,
    currentStreak: currentStreak,
    masteredTopics: mastered,
    habitCompletions: habitLogs.where((item) => item.isCompleted).length,
  );
  return ProgressSummary(
    points: points,
    level: points ~/ 250 + 1,
    completedTasks: completedTasks.length,
    completedAssignments: completedAssignments.length,
    focusMinutes: focusMinutes,
    weekFocusMinutes: weekFocus,
    habitCompletions: habitLogs.where((item) => item.isCompleted).length,
    currentStreak: currentStreak,
    longestStreak: longestStreak,
    masteredTopics: mastered,
    badges: BadgeAwardRules.earned(stats),
  );
}

final achievementSyncProvider =
    NotifierProvider<AchievementSyncController, Set<AchievementType>>(
      AchievementSyncController.new,
    );

class AchievementSyncController extends Notifier<Set<AchievementType>> {
  @override
  Set<AchievementType> build() => <AchievementType>{};

  Future<void> sync(
    Set<AchievementType> earned,
    List<Achievement> existing,
  ) async {
    final persisted =
        existing
            .where((item) => item.isUnlocked)
            .map((item) => item.type)
            .toSet();
    final pending = earned.difference(persisted).difference(state);
    if (pending.isEmpty) return;
    state = {...state, ...pending};
    final repository = ref.read(studentRepositoryProvider);
    for (final type in pending) {
      final definition = _achievementDefinition(type);
      await repository.saveAchievement(
        Achievement(
          id: type.name,
          type: type,
          title: definition.$1,
          description: definition.$2,
          threshold: definition.$3,
          pointsReward: definition.$4,
          iconName: definition.$5,
          progress: 1,
          unlockedAt: DateTime.now(),
        ),
      );
    }
  }
}

(String, String, int, int, String) _achievementDefinition(
  AchievementType type,
) => switch (type) {
  AchievementType.firstTask => (
    'First step',
    'Complete your first study task.',
    1,
    20,
    'task_alt',
  ),
  AchievementType.firstFocusSession => (
    'Focused beginning',
    'Complete your first focus session.',
    1,
    30,
    'timer',
  ),
  AchievementType.focusedHour => (
    'Deep work',
    'Accumulate one focused hour.',
    60,
    50,
    'psychology',
  ),
  AchievementType.focusedTenHours => (
    'Focus craft',
    'Accumulate ten focused hours.',
    600,
    150,
    'workspace_premium',
  ),
  AchievementType.threeDayStreak => (
    'Steady start',
    'Make progress on three consecutive days.',
    3,
    40,
    'local_fire_department',
  ),
  AchievementType.sevenDayStreak => (
    'Consistency builder',
    'Make progress on seven consecutive days.',
    7,
    100,
    'calendar_month',
  ),
  AchievementType.thirtyDayStreak => (
    'Sustainable month',
    'Make progress on thirty consecutive days.',
    30,
    300,
    'military_tech',
  ),
  AchievementType.assignmentCompleted => (
    'Deadline defender',
    'Complete an assignment.',
    1,
    75,
    'assignment_turned_in',
  ),
  AchievementType.topicMastered => (
    'Module mastery',
    'Reach the organisational mastered threshold for a topic.',
    1,
    80,
    'school',
  ),
  AchievementType.habitBuilder => (
    'Balanced week',
    'Complete seven supportive habit actions.',
    7,
    60,
    'eco',
  ),
};
