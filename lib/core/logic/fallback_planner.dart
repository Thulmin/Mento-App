// Builds a useful study plan locally when online AI planning is unavailable.

import 'dart:math' as math;

import '../../data/models/enums.dart';
import '../../data/models/study_plan.dart';
import 'priority_scorer.dart';

final class AvailabilitySlot {
  AvailabilitySlot({required this.startAt, required this.endAt}) {
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError.value(endAt, 'endAt', 'Must be after startAt.');
    }
  }

  final DateTime startAt;
  final DateTime endAt;
}

final class BusyPeriod {
  BusyPeriod({required this.startAt, required this.endAt, this.reason}) {
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError.value(endAt, 'endAt', 'Must be after startAt.');
    }
  }

  final DateTime startAt;
  final DateTime endAt;
  final String? reason;
}

final class PlannerWorkItem {
  PlannerWorkItem({
    required this.id,
    required this.title,
    required this.deadline,
    required this.remainingMinutes,
    required this.priority,
    this.moduleId,
    this.topicId,
    this.recommendedMethod = 'Focused study',
    this.topicMastery = 0.5,
    this.wasMissed = false,
  }) {
    if (id.trim().isEmpty || title.trim().isEmpty) {
      throw ArgumentError('Planner item id and title cannot be empty.');
    }
    if (remainingMinutes < 0) {
      throw ArgumentError.value(
        remainingMinutes,
        'remainingMinutes',
        'Cannot be negative.',
      );
    }
  }

  final String id;
  final String title;
  final String? moduleId;
  final String? topicId;
  final DateTime deadline;
  final int remainingMinutes;
  final PriorityLevel priority;
  final String recommendedMethod;
  final double topicMastery;
  final bool wasMissed;
}

final class PlannerPreferences {
  const PlannerPreferences({
    this.preferredSessionMinutes = 50,
    this.minimumSessionMinutes = 20,
    this.breakMinutes = 10,
    this.maxDailyMinutes = 240,
  });

  final int preferredSessionMinutes;
  final int minimumSessionMinutes;
  final int breakMinutes;
  final int maxDailyMinutes;

  void validate() {
    if (preferredSessionMinutes <= 0 || minimumSessionMinutes <= 0) {
      throw ArgumentError('Session durations must be positive.');
    }
    if (minimumSessionMinutes > preferredSessionMinutes) {
      throw ArgumentError('Minimum session cannot exceed preferred session.');
    }
    if (breakMinutes < 0 || maxDailyMinutes <= 0) {
      throw ArgumentError('Break and daily limit values are invalid.');
    }
  }
}

/// Offline planner that is stable for the same inputs and explicit [now].
///
/// Work is ordered by urgency, importance and remaining effort. Blocks are
/// allocated only inside availability, never overlap commitments, stop at a
/// future deadline, reserve breaks, and respect the per-calendar-day limit.
abstract final class DeterministicFallbackPlanner {
  static StudyPlan generate({
    required String planId,
    required String userId,
    required DateTime now,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required Iterable<PlannerWorkItem> workItems,
    required Iterable<AvailabilitySlot> availability,
    Iterable<BusyPeriod> commitments = const [],
    PlannerPreferences preferences = const PlannerPreferences(),
  }) {
    preferences.validate();
    if (!rangeEnd.isAfter(rangeStart)) {
      throw ArgumentError('rangeEnd must be after rangeStart.');
    }
    final slots = _normaliseAvailability(
      availability,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    final reservations = commitments.toList();
    final scheduledMinutesByDay = <DateTime, int>{};
    final blocks = <PlanBlock>[];
    final unplanned = <String, int>{};
    final items = workItems.where((item) => item.remainingMinutes > 0).toList();

    items.sort((first, second) {
      final firstScore =
          PriorityScorer.calculate(
            deadline: first.deadline,
            priority: first.priority,
            remainingMinutes: first.remainingMinutes,
            now: now,
            topicMastery: first.topicMastery,
            wasMissed: first.wasMissed,
          ).total;
      final secondScore =
          PriorityScorer.calculate(
            deadline: second.deadline,
            priority: second.priority,
            remainingMinutes: second.remainingMinutes,
            now: now,
            topicMastery: second.topicMastery,
            wasMissed: second.wasMissed,
          ).total;
      final byScore = secondScore.compareTo(firstScore);
      if (byScore != 0) return byScore;
      final byDeadline = first.deadline.compareTo(second.deadline);
      if (byDeadline != 0) return byDeadline;
      return first.id.compareTo(second.id);
    });

    for (final item in items) {
      var remaining = item.remainingMinutes;
      var itemBlockIndex = 0;
      final cutoff = item.deadline.isAfter(now) ? item.deadline : rangeEnd;
      while (remaining > 0) {
        final candidate = _findCandidate(
          slots: slots,
          reservations: reservations,
          scheduledMinutesByDay: scheduledMinutesByDay,
          earliest: _latest(now, rangeStart),
          cutoff: _earliest(cutoff, rangeEnd),
          remainingMinutes: remaining,
          preferences: preferences,
        );
        if (candidate == null) break;

        final blockEnd = candidate.startAt.add(
          Duration(minutes: candidate.durationMinutes),
        );
        final block = PlanBlock(
          id:
              '${item.id}_${candidate.startAt.microsecondsSinceEpoch}_$itemBlockIndex',
          startAt: candidate.startAt,
          endAt: blockEnd,
          moduleId: item.moduleId,
          topicId: item.topicId,
          objective: item.title,
          recommendedMethod: item.recommendedMethod,
          breakMinutes: preferences.breakMinutes,
          priority: item.priority,
          reason: _reasonFor(item, now),
          source: PlanSource.deterministic,
          linkedTaskId: item.id,
        );
        blocks.add(block);
        final date = _dateOnly(candidate.startAt);
        scheduledMinutesByDay[date] =
            (scheduledMinutesByDay[date] ?? 0) + candidate.durationMinutes;
        reservations.add(
          BusyPeriod(
            startAt: candidate.startAt,
            endAt: blockEnd.add(Duration(minutes: preferences.breakMinutes)),
            reason: 'Study block and recovery break',
          ),
        );
        remaining -= candidate.durationMinutes;
        itemBlockIndex++;
      }
      if (remaining > 0) unplanned[item.id] = remaining;
    }

    blocks.sort((first, second) => first.startAt.compareTo(second.startAt));
    return StudyPlan(
      id: planId,
      userId: userId,
      generatedAt: now,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      source: PlanSource.deterministic,
      blocks: blocks,
      maxDailyMinutes: preferences.maxDailyMinutes,
      rationale:
          'Offline plan prioritised deadlines, importance, remaining effort, '
          'availability, existing commitments, breaks, and daily workload.',
      unplannedMinutes: unplanned,
    );
  }

  static _Candidate? _findCandidate({
    required List<AvailabilitySlot> slots,
    required List<BusyPeriod> reservations,
    required Map<DateTime, int> scheduledMinutesByDay,
    required DateTime earliest,
    required DateTime cutoff,
    required int remainingMinutes,
    required PlannerPreferences preferences,
  }) {
    if (!cutoff.isAfter(earliest)) return null;
    for (final slot in slots) {
      var usableStart = _latest(slot.startAt, earliest);
      final usableEnd = _earliest(slot.endAt, cutoff);
      if (!usableEnd.isAfter(usableStart)) continue;
      final conflicts =
          reservations
              .where(
                (period) =>
                    period.startAt.isBefore(usableEnd) &&
                    period.endAt.isAfter(usableStart),
              )
              .toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));

      for (final conflict in conflicts) {
        if (conflict.startAt.isAfter(usableStart)) {
          final result = _candidateWithin(
            usableStart,
            _earliest(conflict.startAt, usableEnd),
            remainingMinutes,
            scheduledMinutesByDay,
            preferences,
          );
          if (result != null) return result;
        }
        if (conflict.endAt.isAfter(usableStart)) {
          usableStart = conflict.endAt;
        }
        if (!usableEnd.isAfter(usableStart)) break;
      }
      if (usableEnd.isAfter(usableStart)) {
        final result = _candidateWithin(
          usableStart,
          usableEnd,
          remainingMinutes,
          scheduledMinutesByDay,
          preferences,
        );
        if (result != null) return result;
      }
    }
    return null;
  }

  static _Candidate? _candidateWithin(
    DateTime start,
    DateTime end,
    int remainingMinutes,
    Map<DateTime, int> scheduledMinutesByDay,
    PlannerPreferences preferences,
  ) {
    final availableMinutes = end.difference(start).inMinutes;
    final alreadyScheduled = scheduledMinutesByDay[_dateOnly(start)] ?? 0;
    final dailyRemaining = preferences.maxDailyMinutes - alreadyScheduled;
    final duration = math.min(
      math.min(preferences.preferredSessionMinutes, remainingMinutes),
      math.min(availableMinutes, dailyRemaining),
    );
    if (duration <= 0) return null;
    if (duration < preferences.minimumSessionMinutes &&
        duration < remainingMinutes) {
      return null;
    }
    return _Candidate(startAt: start, durationMinutes: duration);
  }

  static List<AvailabilitySlot> _normaliseAvailability(
    Iterable<AvailabilitySlot> raw, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final split = <AvailabilitySlot>[];
    for (final value in raw) {
      var start = _latest(value.startAt, rangeStart);
      final end = _earliest(value.endAt, rangeEnd);
      while (end.isAfter(start)) {
        final nextDay = DateTime(start.year, start.month, start.day + 1);
        final segmentEnd = _earliest(end, nextDay);
        split.add(AvailabilitySlot(startAt: start, endAt: segmentEnd));
        start = segmentEnd;
      }
    }
    split.sort((a, b) => a.startAt.compareTo(b.startAt));
    final merged = <AvailabilitySlot>[];
    for (final slot in split) {
      if (merged.isEmpty) {
        merged.add(slot);
        continue;
      }
      final previous = merged.last;
      if (_dateOnly(previous.startAt) == _dateOnly(slot.startAt) &&
          !slot.startAt.isAfter(previous.endAt)) {
        merged[merged.length - 1] = AvailabilitySlot(
          startAt: previous.startAt,
          endAt: _latest(previous.endAt, slot.endAt),
        );
      } else {
        merged.add(slot);
      }
    }
    return merged;
  }

  static String _reasonFor(PlannerWorkItem item, DateTime now) {
    final days = item.deadline.difference(now).inDays;
    if (days < 0) return 'Overdue work was placed at the earliest safe time.';
    if (days == 0) return 'Due today and requires prompt attention.';
    if (days <= 3) return 'Deadline is within ${days + 1} days.';
    if (item.priority == PriorityLevel.urgent ||
        item.priority == PriorityLevel.high) {
      return 'High-importance work scheduled ahead of lower-priority items.';
    }
    return 'Scheduled by deadline, workload, and available study time.';
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static DateTime _latest(DateTime first, DateTime second) =>
      first.isAfter(second) ? first : second;
  static DateTime _earliest(DateTime first, DateTime second) =>
      first.isBefore(second) ? first : second;
}

final class _Candidate {
  const _Candidate({required this.startAt, required this.durationMinutes});

  final DateTime startAt;
  final int durationMinutes;
}
