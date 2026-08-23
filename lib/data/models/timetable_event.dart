// Represents one-off and repeating timetable events with optional locations.

import 'enums.dart';
import 'model_utils.dart';

final class TimetableEvent {
  TimetableEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.startAt,
    required this.endAt,
    this.moduleId,
    this.location,
    this.savedLocationId,
    this.latitude,
    this.longitude,
    this.reminderMinutesBefore,
    this.recurrence = RecurrenceFrequency.none,
    this.recurrenceUntil,
    Set<int> recurringWeekdays = const {},
    this.notes,
  }) : recurringWeekdays = Set.unmodifiable(recurringWeekdays) {
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError.value(endAt, 'endAt', 'Must be after startAt.');
    }
    if (recurringWeekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError.value(
        recurringWeekdays,
        'recurringWeekdays',
        'Weekdays must use DateTime.monday (1) through sunday (7).',
      );
    }
  }

  final String id;
  final String title;
  final String? moduleId;
  final EventType type;
  final DateTime startAt;
  final DateTime endAt;
  final String? location;
  final String? savedLocationId;
  final double? latitude;
  final double? longitude;
  final int? reminderMinutesBefore;
  final RecurrenceFrequency recurrence;
  final DateTime? recurrenceUntil;
  final Set<int> recurringWeekdays;
  final String? notes;

  Duration get duration => endAt.difference(startAt);

  factory TimetableEvent.fromMap(
    Map<String, Object?> map, {
    String? id,
  }) => TimetableEvent(
    id: id ?? ModelUtils.requiredString(map, 'id'),
    title: ModelUtils.requiredString(map, 'title'),
    moduleId: ModelUtils.optionalString(map, 'moduleId'),
    type: ModelUtils.enumValue(
      map,
      'type',
      EventType.values,
      fallback: EventType.other,
    ),
    startAt: ModelUtils.dateTime(map, 'startAt'),
    endAt: ModelUtils.dateTime(map, 'endAt'),
    location: ModelUtils.optionalString(map, 'location'),
    savedLocationId: ModelUtils.optionalString(map, 'savedLocationId'),
    latitude:
        map['latitude'] == null ? null : ModelUtils.decimal(map, 'latitude'),
    longitude:
        map['longitude'] == null ? null : ModelUtils.decimal(map, 'longitude'),
    reminderMinutesBefore:
        map['reminderMinutesBefore'] == null
            ? null
            : ModelUtils.integer(map, 'reminderMinutesBefore'),
    recurrence: ModelUtils.enumValue(
      map,
      'recurrence',
      RecurrenceFrequency.values,
      fallback: RecurrenceFrequency.none,
    ),
    recurrenceUntil: ModelUtils.optionalDateTime(map, 'recurrenceUntil'),
    recurringWeekdays:
        ModelUtils.list(map, 'recurringWeekdays').map((value) {
          if (value is! num) {
            throw const FormatException('Recurring weekdays must be integers.');
          }
          return value.toInt();
        }).toSet(),
    notes: ModelUtils.optionalString(map, 'notes'),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'moduleId': moduleId,
    'type': type.name,
    'startAt': startAt,
    'endAt': endAt,
    'location': location,
    'savedLocationId': savedLocationId,
    'latitude': latitude,
    'longitude': longitude,
    'reminderMinutesBefore': reminderMinutesBefore,
    'recurrence': recurrence.name,
    'recurrenceUntil': recurrenceUntil,
    'recurringWeekdays': recurringWeekdays.toList()..sort(),
    'notes': notes,
  };

  TimetableEvent occurrence({
    required String occurrenceId,
    required DateTime start,
  }) => TimetableEvent(
    id: occurrenceId,
    title: title,
    moduleId: moduleId,
    type: type,
    startAt: start,
    endAt: start.add(duration),
    location: location,
    savedLocationId: savedLocationId,
    latitude: latitude,
    longitude: longitude,
    reminderMinutesBefore: reminderMinutesBefore,
    notes: notes,
  );
}
