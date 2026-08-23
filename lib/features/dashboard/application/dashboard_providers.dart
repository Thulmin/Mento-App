// Loads the upcoming academic and focus data shown on the Today dashboard.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

final dashboardEventsProvider = StreamProvider<List<TimetableEvent>>((ref) {
  final now = DateTime.now();
  return ref
      .watch(studentRepositoryProvider)
      .watchTimetableEvents(
        rangeStart: DateTime(now.year, now.month, now.day),
        rangeEnd: now.add(const Duration(days: 14)),
      );
});
final dashboardModulesProvider = StreamProvider<List<Module>>(
  (ref) => ref.watch(studentRepositoryProvider).watchModules(),
);
final dashboardAssignmentsProvider = StreamProvider<List<Assignment>>(
  (ref) => ref
      .watch(studentRepositoryProvider)
      .watchAssignments(
        dueFrom: DateTime.now().subtract(const Duration(days: 365)),
        dueBefore: DateTime.now().add(const Duration(days: 730)),
      ),
);
final dashboardExamsProvider = StreamProvider<List<Exam>>(
  (ref) => ref
      .watch(studentRepositoryProvider)
      .watchExams(
        from: DateTime.now().subtract(const Duration(days: 365)),
        before: DateTime.now().add(const Duration(days: 730)),
      ),
);
final dashboardTasksProvider = StreamProvider<List<StudyTask>>(
  (ref) => ref
      .watch(studentRepositoryProvider)
      .watchStudyTasks(
        dueFrom: DateTime.now().subtract(const Duration(days: 365)),
        dueBefore: DateTime.now().add(const Duration(days: 730)),
      ),
);
final dashboardPlansProvider = StreamProvider<List<StudyPlan>>(
  (ref) => ref.watch(studentRepositoryProvider).watchStudyPlans(),
);
final dashboardHabitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(studentRepositoryProvider).watchHabits(),
);
final dashboardHabitLogsProvider = StreamProvider<List<HabitLog>>(
  (ref) => ref
      .watch(studentRepositoryProvider)
      .watchHabitLogs(
        from: DateTime.now().subtract(const Duration(days: 45)),
        before: DateTime.now().add(const Duration(days: 1)),
      ),
);
final dashboardFocusProvider = StreamProvider<List<FocusSession>>(
  (ref) => ref.watch(studentRepositoryProvider).watchFocusSessions(),
);
