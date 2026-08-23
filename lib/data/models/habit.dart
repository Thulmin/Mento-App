// Defines habits, daily logs, wellness check-ins, and saved study locations.

import 'enums.dart';
import 'model_utils.dart';

final class Habit {
  Habit({
    required this.id,
    required this.name,
    required this.category,
    required this.frequency,
    required this.createdAt,
    Set<int> weekdays = const {},
    this.weeklyTarget = 7,
    List<String> reminderTimes = const [],
    this.isArchived = false,
    this.notes,
  }) : weekdays = Set.unmodifiable(weekdays),
       reminderTimes = List.unmodifiable(reminderTimes) {
    if (weeklyTarget < 1 || weeklyTarget > 7) {
      throw ArgumentError.value(
        weeklyTarget,
        'weeklyTarget',
        'Must be 1 to 7.',
      );
    }
    if (weekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError.value(weekdays, 'weekdays', 'Must be 1 through 7.');
    }
  }

  final String id;
  final String name;
  final HabitCategory category;
  final HabitFrequency frequency;
  final Set<int> weekdays;
  final int weeklyTarget;
  final List<String> reminderTimes;
  final bool isArchived;
  final String? notes;
  final DateTime createdAt;

  factory Habit.fromMap(Map<String, Object?> map, {String? id}) => Habit(
    id: id ?? ModelUtils.requiredString(map, 'id'),
    name: ModelUtils.requiredString(map, 'name'),
    category: ModelUtils.enumValue(
      map,
      'category',
      HabitCategory.values,
      fallback: HabitCategory.custom,
    ),
    frequency: ModelUtils.enumValue(
      map,
      'frequency',
      HabitFrequency.values,
      fallback: HabitFrequency.daily,
    ),
    weekdays:
        ModelUtils.list(map, 'weekdays').map((value) {
          if (value is! num) {
            throw const FormatException('Habit weekdays must be integers.');
          }
          return value.toInt();
        }).toSet(),
    weeklyTarget: ModelUtils.integer(map, 'weeklyTarget', fallback: 7),
    reminderTimes: ModelUtils.stringList(map, 'reminderTimes'),
    isArchived: ModelUtils.boolean(map, 'isArchived'),
    notes: ModelUtils.optionalString(map, 'notes'),
    createdAt: ModelUtils.dateTime(map, 'createdAt'),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'category': category.name,
    'frequency': frequency.name,
    'weekdays': weekdays.toList()..sort(),
    'weeklyTarget': weeklyTarget,
    'reminderTimes': reminderTimes,
    'isArchived': isArchived,
    'notes': notes,
    'createdAt': createdAt,
  };
}

final class HabitLog {
  const HabitLog({
    required this.id,
    required this.habitId,
    required this.date,
    required this.loggedAt,
    this.isCompleted = true,
    this.value,
    this.note,
  });

  final String id;
  final String habitId;
  final DateTime date;
  final DateTime loggedAt;
  final bool isCompleted;
  final double? value;
  final String? note;

  factory HabitLog.fromMap(Map<String, Object?> map, {String? id}) => HabitLog(
    id: id ?? ModelUtils.requiredString(map, 'id'),
    habitId: ModelUtils.requiredString(map, 'habitId'),
    date: ModelUtils.dateTime(map, 'date'),
    loggedAt: ModelUtils.dateTime(map, 'loggedAt'),
    isCompleted: ModelUtils.boolean(map, 'isCompleted', fallback: true),
    value: map['value'] == null ? null : ModelUtils.decimal(map, 'value'),
    note: ModelUtils.optionalString(map, 'note'),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'habitId': habitId,
    'date': date,
    'loggedAt': loggedAt,
    'isCompleted': isCompleted,
    'value': value,
    'note': note,
  };
}

final class WellnessCheckIn {
  WellnessCheckIn({
    required this.id,
    required this.recordedAt,
    required this.mood,
    required this.energy,
    this.sleepHours,
    this.note,
  }) {
    if (mood < 1 || mood > 5 || energy < 1 || energy > 5) {
      throw ArgumentError(
        'Mood and energy must use the non-clinical 1–5 scale.',
      );
    }
    if (sleepHours != null && (sleepHours! < 0 || sleepHours! > 24)) {
      throw ArgumentError.value(sleepHours, 'sleepHours', 'Must be 0 to 24.');
    }
  }

  final String id;
  final DateTime recordedAt;
  final int mood;
  final int energy;
  final double? sleepHours;
  final String? note;

  factory WellnessCheckIn.fromMap(Map<String, Object?> map, {String? id}) =>
      WellnessCheckIn(
        id: id ?? ModelUtils.requiredString(map, 'id'),
        recordedAt: ModelUtils.dateTime(map, 'recordedAt'),
        mood: ModelUtils.integer(map, 'mood'),
        energy: ModelUtils.integer(map, 'energy'),
        sleepHours:
            map['sleepHours'] == null
                ? null
                : ModelUtils.decimal(map, 'sleepHours'),
        note: ModelUtils.optionalString(map, 'note'),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'recordedAt': recordedAt,
    'mood': mood,
    'energy': energy,
    'sleepHours': sleepHours,
    'note': note,
  };
}
