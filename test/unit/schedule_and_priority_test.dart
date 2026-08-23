import 'package:flutter_test/flutter_test.dart';
import 'package:mento/core/logic/logic.dart';
import 'package:mento/data/models/models.dart';

void main() {
  group('ScheduleConflictDetector', () {
    TimetableEvent event(
      String id,
      DateTime start,
      DateTime end, {
      RecurrenceFrequency recurrence = RecurrenceFrequency.none,
      Set<int> weekdays = const {},
    }) => TimetableEvent(
      id: id,
      title: id,
      type: EventType.lecture,
      startAt: start,
      endAt: end,
      recurrence: recurrence,
      recurringWeekdays: weekdays,
    );

    test('uses half-open intervals and optional buffers', () {
      final first = event(
        'a',
        DateTime(2026, 1, 5, 9),
        DateTime(2026, 1, 5, 10),
      );
      final adjacent = event(
        'b',
        DateTime(2026, 1, 5, 10),
        DateTime(2026, 1, 5, 11),
      );

      expect(ScheduleConflictDetector.eventOverlaps(first, adjacent), isFalse);
      expect(
        ScheduleConflictDetector.eventOverlaps(
          first,
          adjacent,
          buffer: const Duration(minutes: 5),
        ),
        isTrue,
      );
    });

    test('detects an occurrence of a recurring event', () {
      final weekly = event(
        'weekly',
        DateTime(2026, 1, 5, 9),
        DateTime(2026, 1, 5, 10),
        recurrence: RecurrenceFrequency.weekly,
        weekdays: {DateTime.monday},
      );
      final oneOff = event(
        'oneOff',
        DateTime(2026, 1, 12, 9, 30),
        DateTime(2026, 1, 12, 10, 30),
      );

      final conflicts = ScheduleConflictDetector.findConflicts(
        [weekly, oneOff],
        rangeStart: DateTime(2026, 1, 11),
        rangeEnd: DateTime(2026, 1, 13),
      );

      expect(conflicts, hasLength(1));
      expect(conflicts.single.overlapDuration, const Duration(minutes: 30));
      expect(
        {conflicts.single.firstEventId, conflicts.single.secondEventId},
        {'weekly', 'oneOff'},
      );
    });
  });

  group('PriorityScorer', () {
    final now = DateTime.utc(2026, 1, 1, 9);

    test('scores urgent near-term work above low-priority distant work', () {
      final urgent = PriorityScorer.calculate(
        deadline: now.add(const Duration(hours: 12)),
        priority: PriorityLevel.urgent,
        remainingMinutes: 240,
        now: now,
      );
      final distant = PriorityScorer.calculate(
        deadline: now.add(const Duration(days: 60)),
        priority: PriorityLevel.low,
        remainingMinutes: 30,
        now: now,
      );

      expect(urgent.total, greaterThan(distant.total));
      expect(urgent.total, inInclusiveRange(0, 100));
    });

    test('adds explicit recovery and overdue signals', () {
      final normal = PriorityScorer.calculate(
        deadline: now.subtract(const Duration(days: 1)),
        priority: PriorityLevel.medium,
        remainingMinutes: 60,
        now: now,
      );
      final missed = PriorityScorer.calculate(
        deadline: now.subtract(const Duration(days: 1)),
        priority: PriorityLevel.medium,
        remainingMinutes: 60,
        now: now,
        wasMissed: true,
      );

      expect(normal.overdueBonus, greaterThan(0));
      expect(missed.total, greaterThan(normal.total));
    });
  });
}
