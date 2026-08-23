// Collects the shared fixed-value choices stored by Mento's data models.

enum EventType { lecture, tutorial, laboratory, seminar, personalStudy, other }

enum RecurrenceFrequency { none, daily, weekly, fortnightly, monthly }

enum PriorityLevel {
  low(1),
  medium(2),
  high(3),
  urgent(4);

  const PriorityLevel(this.weight);
  final int weight;
}

enum WorkStatus { notStarted, inProgress, completed, missed, cancelled }

enum PlanSource { deterministic, artificialIntelligence, user }

enum PlanBlockStatus { proposed, accepted, completed, missed, rejected }

enum FocusSessionState { running, paused, completed, cancelled }

enum HabitFrequency { daily, weekdays, weekends, selectedDays, timesPerWeek }

enum HabitCategory {
  hydration,
  movement,
  sleep,
  breaks,
  reading,
  mindfulness,
  custom,
}

enum AchievementType {
  firstTask,
  firstFocusSession,
  focusedHour,
  focusedTenHours,
  threeDayStreak,
  sevenDayStreak,
  thirtyDayStreak,
  assignmentCompleted,
  topicMastered,
  habitBuilder,
}

enum ThemePreference { system, light, dark }

enum SavedLocationType { campus, library, studySpace, cafe, home, other }
