import 'package:flutter_test/flutter_test.dart';
import 'package:mento/data/models/models.dart';
import 'package:mento/features/dashboard/presentation/dashboard_screen.dart';

void main() {
  StudyTask task({
    required String id,
    required DateTime dueAt,
    required WorkStatus status,
  }) => StudyTask(
    id: id,
    title: id,
    dueAt: dueAt,
    estimatedMinutes: 25,
    priority: PriorityLevel.medium,
    status: status,
  );

  test('Today progress includes only due-today tasks and their completion', () {
    final asOf = DateTime(2026, 7, 18, 12);
    final result = calculateTodayTaskProgress([
      task(
        id: 'today-complete',
        dueAt: DateTime(2026, 7, 18, 8),
        status: WorkStatus.completed,
      ),
      task(
        id: 'today-open',
        dueAt: DateTime(2026, 7, 18, 23, 59),
        status: WorkStatus.inProgress,
      ),
      task(
        id: 'yesterday-complete',
        dueAt: DateTime(2026, 7, 17, 23, 59),
        status: WorkStatus.completed,
      ),
      task(
        id: 'tomorrow-complete',
        dueAt: DateTime(2026, 7, 19),
        status: WorkStatus.completed,
      ),
    ], asOf: asOf);

    expect(result.total, 2);
    expect(result.completed, 1);
    expect(result.value, 0.5);
  });

  test('Today progress is zero when no tasks are due today', () {
    final result = calculateTodayTaskProgress([
      task(
        id: 'later',
        dueAt: DateTime(2026, 7, 19),
        status: WorkStatus.notStarted,
      ),
    ], asOf: DateTime(2026, 7, 18));

    expect(result.total, 0);
    expect(result.completed, 0);
    expect(result.value, 0);
  });
}
