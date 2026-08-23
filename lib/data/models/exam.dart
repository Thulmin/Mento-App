// Represents an examination and the topics included in its preparation.

import 'enums.dart';
import 'model_utils.dart';

final class Exam {
  Exam({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.startAt,
    required this.endAt,
    required this.importance,
    this.venue,
    List<String> syllabusTopicIds = const [],
    double preparationProgress = 0,
    this.reminderAt,
    this.notes,
  }) : syllabusTopicIds = List.unmodifiable(syllabusTopicIds),
       preparationProgress = ModelUtils.clampUnit(preparationProgress) {
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError.value(endAt, 'endAt', 'Must be after startAt.');
    }
  }

  final String id;
  final String moduleId;
  final String title;
  final DateTime startAt;
  final DateTime endAt;
  final String? venue;
  final List<String> syllabusTopicIds;
  final PriorityLevel importance;
  final double preparationProgress;
  final DateTime? reminderAt;
  final String? notes;

  factory Exam.fromMap(Map<String, Object?> map, {String? id}) => Exam(
    id: id ?? ModelUtils.requiredString(map, 'id'),
    moduleId: ModelUtils.requiredString(map, 'moduleId'),
    title: ModelUtils.requiredString(map, 'title'),
    startAt: ModelUtils.dateTime(map, 'startAt'),
    endAt: ModelUtils.dateTime(map, 'endAt'),
    venue: ModelUtils.optionalString(map, 'venue'),
    syllabusTopicIds: ModelUtils.stringList(map, 'syllabusTopicIds'),
    importance: ModelUtils.enumValue(
      map,
      'importance',
      PriorityLevel.values,
      fallback: PriorityLevel.high,
    ),
    preparationProgress: ModelUtils.decimal(
      map,
      'preparationProgress',
      fallback: 0,
    ),
    reminderAt: ModelUtils.optionalDateTime(map, 'reminderAt'),
    notes: ModelUtils.optionalString(map, 'notes'),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'moduleId': moduleId,
    'title': title,
    'startAt': startAt,
    'endAt': endAt,
    'venue': venue,
    'syllabusTopicIds': syllabusTopicIds,
    'importance': importance.name,
    'preparationProgress': preparationProgress,
    'reminderAt': reminderAt,
    'notes': notes,
  };
}
