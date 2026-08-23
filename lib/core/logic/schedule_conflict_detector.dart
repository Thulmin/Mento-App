// Expands repeating events and finds timetable overlaps within a date range.

import '../../data/models/timetable_event.dart';

final class ScheduleOccurrence {
  const ScheduleOccurrence({
    required this.eventId,
    required this.title,
    required this.startAt,
    required this.endAt,
  });

  final String eventId;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
}

final class ScheduleConflict {
  const ScheduleConflict({
    required this.firstEventId,
    required this.secondEventId,
    required this.overlapStart,
    required this.overlapEnd,
  });

  final String firstEventId;
  final String secondEventId;
  final DateTime overlapStart;
  final DateTime overlapEnd;

  Duration get overlapDuration => overlapEnd.difference(overlapStart);
}

abstract final class ScheduleConflictDetector {
  /// Uses half-open intervals: an event ending exactly when another starts is
  /// not a conflict. A positive [buffer] requires free time around both events.
  static bool intervalsOverlap(
    DateTime firstStart,
    DateTime firstEnd,
    DateTime secondStart,
    DateTime secondEnd, {
    Duration buffer = Duration.zero,
  }) {
    if (!firstEnd.isAfter(firstStart) || !secondEnd.isAfter(secondStart)) {
      throw ArgumentError('Schedule intervals must have a positive duration.');
    }
    if (buffer.isNegative) {
      throw ArgumentError.value(buffer, 'buffer', 'Cannot be negative.');
    }
    return firstStart.isBefore(secondEnd.add(buffer)) &&
        firstEnd.isAfter(secondStart.subtract(buffer));
  }

  static bool eventOverlaps(
    TimetableEvent first,
    TimetableEvent second, {
    Duration buffer = Duration.zero,
  }) => intervalsOverlap(
    first.startAt,
    first.endAt,
    second.startAt,
    second.endAt,
    buffer: buffer,
  );

  static List<ScheduleConflict> findConflicts(
    Iterable<TimetableEvent> events, {
    DateTime? rangeStart,
    DateTime? rangeEnd,
    Duration buffer = Duration.zero,
  }) {
    final list = events.toList();
    if (list.length < 2) return const [];
    final start =
        rangeStart ??
        list
            .map((event) => event.startAt)
            .reduce((first, second) => first.isBefore(second) ? first : second);
    final end =
        rangeEnd ??
        list
            .map((event) => event.endAt)
            .reduce((first, second) => first.isAfter(second) ? first : second);
    if (!end.isAfter(start)) throw ArgumentError('Invalid detection range.');

    final occurrences =
        list
            .expand(
              (event) =>
                  occurrencesBetween(event, rangeStart: start, rangeEnd: end),
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    final conflicts = <ScheduleConflict>[];
    for (var i = 0; i < occurrences.length; i++) {
      final first = occurrences[i];
      for (var j = i + 1; j < occurrences.length; j++) {
        final second = occurrences[j];
        if (!second.startAt.isBefore(first.endAt.add(buffer))) break;
        if (first.eventId == second.eventId) continue;
        if (!intervalsOverlap(
          first.startAt,
          first.endAt,
          second.startAt,
          second.endAt,
          buffer: buffer,
        )) {
          continue;
        }
        final overlapStart =
            first.startAt.isAfter(second.startAt)
                ? first.startAt
                : second.startAt;
        final overlapEnd =
            first.endAt.isBefore(second.endAt) ? first.endAt : second.endAt;
        conflicts.add(
          ScheduleConflict(
            firstEventId: first.eventId,
            secondEventId: second.eventId,
            overlapStart: overlapStart,
            // With buffer-only conflicts there is no literal overlap. Retain a
            // zero-duration boundary while still returning the warning.
            overlapEnd:
                overlapEnd.isBefore(overlapStart) ? overlapStart : overlapEnd,
          ),
        );
      }
    }
    return List.unmodifiable(conflicts);
  }

  static List<ScheduleOccurrence> occurrencesBetween(
    TimetableEvent event, {
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    if (!rangeEnd.isAfter(rangeStart)) {
      throw ArgumentError('rangeEnd must be after rangeStart.');
    }
    if (event.recurrence.name == 'none') {
      return _within(event.startAt, event.endAt, rangeStart, rangeEnd)
          ? [
            ScheduleOccurrence(
              eventId: event.id,
              title: event.title,
              startAt: event.startAt,
              endAt: event.endAt,
            ),
          ]
          : const [];
    }

    final results = <ScheduleOccurrence>[];
    final lastAllowed = event.recurrenceUntil;
    final baseDate = _dateOnly(event.startAt);
    final searchStart = _dateOnly(
      rangeStart.isAfter(event.startAt) ? rangeStart : event.startAt,
    );
    final searchEnd = _dateOnly(rangeEnd);

    if (event.recurrence.name == 'monthly') {
      var monthOffset = 0;
      while (true) {
        final monthStart = DateTime(
          baseDate.year,
          baseDate.month + monthOffset,
          1,
          event.startAt.hour,
          event.startAt.minute,
          event.startAt.second,
          event.startAt.millisecond,
          event.startAt.microsecond,
        );
        final day = event.startAt.day.clamp(1, _daysInMonth(monthStart));
        final occurrenceStart = DateTime(
          monthStart.year,
          monthStart.month,
          day,
          event.startAt.hour,
          event.startAt.minute,
          event.startAt.second,
          event.startAt.millisecond,
          event.startAt.microsecond,
        );
        if (!occurrenceStart.isBefore(rangeEnd)) break;
        if (lastAllowed != null && occurrenceStart.isAfter(lastAllowed)) break;
        final occurrenceEnd = occurrenceStart.add(event.duration);
        if (_within(occurrenceStart, occurrenceEnd, rangeStart, rangeEnd)) {
          results.add(_occurrence(event, occurrenceStart, occurrenceEnd));
        }
        monthOffset++;
      }
      return List.unmodifiable(results);
    }

    var day = searchStart;
    while (!day.isAfter(searchEnd)) {
      final daysFromBase = day.difference(baseDate).inDays;
      if (daysFromBase >= 0 && _occursOnDay(event, day, daysFromBase)) {
        final occurrenceStart = DateTime(
          day.year,
          day.month,
          day.day,
          event.startAt.hour,
          event.startAt.minute,
          event.startAt.second,
          event.startAt.millisecond,
          event.startAt.microsecond,
        );
        if (lastAllowed == null || !occurrenceStart.isAfter(lastAllowed)) {
          final occurrenceEnd = occurrenceStart.add(event.duration);
          if (_within(occurrenceStart, occurrenceEnd, rangeStart, rangeEnd)) {
            results.add(_occurrence(event, occurrenceStart, occurrenceEnd));
          }
        }
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return List.unmodifiable(results);
  }

  static bool _occursOnDay(
    TimetableEvent event,
    DateTime day,
    int daysFromBase,
  ) {
    final frequency = event.recurrence.name;
    if (frequency == 'daily') {
      return event.recurringWeekdays.isEmpty ||
          event.recurringWeekdays.contains(day.weekday);
    }
    final selectedDays =
        event.recurringWeekdays.isEmpty
            ? {event.startAt.weekday}
            : event.recurringWeekdays;
    if (!selectedDays.contains(day.weekday)) return false;
    final week = daysFromBase ~/ 7;
    if (frequency == 'weekly') return true;
    if (frequency == 'fortnightly') return week.isEven;
    return false;
  }

  static ScheduleOccurrence _occurrence(
    TimetableEvent event,
    DateTime start,
    DateTime end,
  ) => ScheduleOccurrence(
    eventId: event.id,
    title: event.title,
    startAt: start,
    endAt: end,
  );

  static bool _within(
    DateTime start,
    DateTime end,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) => start.isBefore(rangeEnd) && end.isAfter(rangeStart);

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static int _daysInMonth(DateTime month) =>
      DateTime(month.year, month.month + 1, 0).day;
}
