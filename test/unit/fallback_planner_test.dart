import 'package:flutter_test/flutter_test.dart';
import 'package:mento/core/logic/logic.dart';
import 'package:mento/data/models/models.dart';

void main() {
  final now = DateTime(2026, 1, 5, 8);
  final rangeEnd = DateTime(2026, 1, 7);

  StudyPlan generate() => DeterministicFallbackPlanner.generate(
    planId: 'fallback-plan',
    userId: 'user-1',
    now: now,
    rangeStart: now,
    rangeEnd: rangeEnd,
    workItems: [
      PlannerWorkItem(
        id: 'urgent',
        title: 'Finish report',
        moduleId: 'm1',
        deadline: DateTime(2026, 1, 5, 17),
        remainingMinutes: 90,
        priority: PriorityLevel.urgent,
      ),
      PlannerWorkItem(
        id: 'later',
        title: 'Read chapter',
        moduleId: 'm2',
        deadline: DateTime(2026, 1, 9),
        remainingMinutes: 120,
        priority: PriorityLevel.low,
      ),
    ],
    availability: [
      AvailabilitySlot(
        startAt: DateTime(2026, 1, 5, 9),
        endAt: DateTime(2026, 1, 5, 12),
      ),
      AvailabilitySlot(
        startAt: DateTime(2026, 1, 6, 9),
        endAt: DateTime(2026, 1, 6, 12),
      ),
    ],
    commitments: [
      BusyPeriod(
        startAt: DateTime(2026, 1, 5, 10),
        endAt: DateTime(2026, 1, 5, 11),
        reason: 'Lecture',
      ),
    ],
    preferences: const PlannerPreferences(
      preferredSessionMinutes: 50,
      minimumSessionMinutes: 20,
      breakMinutes: 10,
      maxDailyMinutes: 100,
    ),
  );

  test('prioritises deadlines and respects commitments and breaks', () {
    final plan = generate();

    expect(plan.blocks.first.linkedTaskId, 'urgent');
    expect(
      plan.blocks
          .where((block) => block.linkedTaskId == 'urgent')
          .fold<int>(0, (sum, block) => sum + block.duration.inMinutes),
      90,
    );
    for (final block in plan.blocks) {
      expect(
        block.startAt.isBefore(DateTime(2026, 1, 5, 10)) &&
            block.endAt.isAfter(DateTime(2026, 1, 5, 10)),
        isFalse,
      );
      expect(block.source, PlanSource.deterministic);
      expect(block.breakMinutes, 10);
    }
    final ordered = [...plan.blocks]
      ..sort((first, second) => first.startAt.compareTo(second.startAt));
    for (var index = 1; index < ordered.length; index++) {
      expect(
        ordered[index].startAt.difference(ordered[index - 1].endAt),
        greaterThanOrEqualTo(const Duration(minutes: 10)),
      );
    }
  });

  test('enforces maximum daily workload and reports unscheduled effort', () {
    final plan = generate();
    final daily = <DateTime, int>{};
    for (final block in plan.blocks) {
      final day = DateTime(
        block.startAt.year,
        block.startAt.month,
        block.startAt.day,
      );
      daily[day] = (daily[day] ?? 0) + block.duration.inMinutes;
    }

    expect(daily.values.every((minutes) => minutes <= 100), isTrue);
    expect(plan.unplannedMinutes['later'], 20);
  });

  test('is deterministic for identical inputs', () {
    final first = generate();
    final second = generate();

    expect(
      first.blocks.map((block) => block.id),
      orderedEquals(second.blocks.map((block) => block.id)),
    );
    expect(first.unplannedMinutes, second.unplannedMinutes);
  });
}
