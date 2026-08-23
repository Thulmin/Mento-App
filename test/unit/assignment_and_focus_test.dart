import 'package:flutter_test/flutter_test.dart';
import 'package:mento/core/logic/logic.dart';
import 'package:mento/data/models/models.dart';

void main() {
  Assignment assignment({
    List<Subtask> subtasks = const [],
    double manualProgress = 0,
    WorkStatus status = WorkStatus.inProgress,
  }) => Assignment(
    id: 'a1',
    moduleId: 'm1',
    title: 'Coursework',
    dueAt: DateTime.utc(2026, 2, 1),
    priority: PriorityLevel.high,
    estimatedMinutes: 120,
    status: status,
    subtasks: subtasks,
    manualProgress: manualProgress,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );

  group('AssignmentProgressCalculator', () {
    test('weights subtasks by their estimated effort', () {
      final result = AssignmentProgressCalculator.calculate(
        assignment(
          subtasks: const [
            Subtask(
              id: 'short',
              title: 'Outline',
              estimatedMinutes: 30,
              isCompleted: true,
            ),
            Subtask(id: 'long', title: 'Write', estimatedMinutes: 90),
          ],
        ),
      );

      expect(result.fraction, 0.25);
      expect(result.percentage, 25);
      expect(result.completedSubtasks, 1);
    });

    test('uses equal weights when no effort estimates exist', () {
      final result = AssignmentProgressCalculator.calculate(
        assignment(
          subtasks: const [
            Subtask(id: '1', title: 'One', isCompleted: true),
            Subtask(id: '2', title: 'Two'),
          ],
        ),
      );
      expect(result.fraction, 0.5);
    });

    test(
      'uses manual progress without subtasks and completion overrides it',
      () {
        expect(
          AssignmentProgressCalculator.calculate(
            assignment(manualProgress: 0.42),
          ).fraction,
          0.42,
        );
        expect(
          AssignmentProgressCalculator.calculate(
            assignment(manualProgress: 0.42, status: WorkStatus.completed),
          ).fraction,
          1,
        );
      },
    );
  });

  group('FocusSessionCalculator', () {
    final start = DateTime.utc(2026, 1, 1, 9);

    test('calculates elapsed time from timestamps while backgrounded', () {
      final session = FocusSessionCalculator.start(
        id: 'f1',
        goal: 'Read chapter',
        targetMinutes: 45,
        at: start,
      );

      expect(
        FocusSessionCalculator.elapsed(
          session,
          at: start.add(const Duration(minutes: 23, seconds: 4)),
        ),
        const Duration(minutes: 23, seconds: 4),
      );
    });

    test('pause and resume exclude paused time and survive persistence', () {
      var session = FocusSessionCalculator.start(
        id: 'f1',
        goal: 'Read chapter',
        targetMinutes: 45,
        at: start,
      );
      session = FocusSessionCalculator.pause(
        session,
        at: start.add(const Duration(minutes: 10)),
      );
      expect(
        FocusSessionCalculator.elapsed(
          session,
          at: start.add(const Duration(minutes: 40)),
        ),
        const Duration(minutes: 10),
      );
      session = FocusSessionCalculator.resume(
        session,
        at: start.add(const Duration(minutes: 50)),
      );
      session = FocusSession.fromMap(session.toMap());
      session = FocusSessionCalculator.complete(
        session,
        at: start.add(const Duration(minutes: 75)),
      );

      expect(
        FocusSessionCalculator.elapsed(session, at: session.endedAt!),
        const Duration(minutes: 35),
      );
      expect(session.accumulatedPausedSeconds, 40 * 60);
      expect(session.state, FocusSessionState.completed);
      expect(session.interruptionCount, 1);
    });

    test('rejects invalid state transitions', () {
      final session = FocusSessionCalculator.start(
        id: 'f1',
        goal: 'Read chapter',
        targetMinutes: 45,
        at: start,
      );
      expect(
        () => FocusSessionCalculator.resume(session, at: start),
        throwsStateError,
      );
    });
  });
}
