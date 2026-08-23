// Represents a standalone study task and its scheduling information.

import 'enums.dart';
import 'model_utils.dart';

final class StudyTask {
  const StudyTask({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.estimatedMinutes,
    required this.priority,
    required this.status,
    this.moduleId,
    this.topicId,
    this.plannedStartAt,
    this.isAiGenerated = false,
    this.needsRescheduling = false,
    this.completedAt,
    this.notes,
  });

  final String id;
  final String title;
  final String? moduleId;
  final String? topicId;
  final DateTime dueAt;
  final int estimatedMinutes;
  final PriorityLevel priority;
  final WorkStatus status;
  final DateTime? plannedStartAt;
  final bool isAiGenerated;
  final bool needsRescheduling;
  final DateTime? completedAt;
  final String? notes;

  bool get isCompleted => status == WorkStatus.completed;

  factory StudyTask.fromMap(Map<String, Object?> map, {String? id}) =>
      StudyTask(
        id: id ?? ModelUtils.requiredString(map, 'id'),
        title: ModelUtils.requiredString(map, 'title'),
        moduleId: ModelUtils.optionalString(map, 'moduleId'),
        topicId: ModelUtils.optionalString(map, 'topicId'),
        dueAt: ModelUtils.dateTime(map, 'dueAt'),
        estimatedMinutes: ModelUtils.integer(
          map,
          'estimatedMinutes',
          fallback: 0,
        ),
        priority: ModelUtils.enumValue(
          map,
          'priority',
          PriorityLevel.values,
          fallback: PriorityLevel.medium,
        ),
        status: ModelUtils.enumValue(
          map,
          'status',
          WorkStatus.values,
          fallback: WorkStatus.notStarted,
        ),
        plannedStartAt: ModelUtils.optionalDateTime(map, 'plannedStartAt'),
        isAiGenerated: ModelUtils.boolean(map, 'isAiGenerated'),
        needsRescheduling: ModelUtils.boolean(map, 'needsRescheduling'),
        completedAt: ModelUtils.optionalDateTime(map, 'completedAt'),
        notes: ModelUtils.optionalString(map, 'notes'),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'moduleId': moduleId,
    'topicId': topicId,
    'dueAt': dueAt,
    'estimatedMinutes': estimatedMinutes,
    'priority': priority.name,
    'status': status.name,
    'plannedStartAt': plannedStartAt,
    'isAiGenerated': isAiGenerated,
    'needsRescheduling': needsRescheduling,
    'completedAt': completedAt,
    'notes': notes,
  };

  StudyTask copyWith({
    WorkStatus? status,
    DateTime? plannedStartAt,
    bool? needsRescheduling,
    DateTime? completedAt,
  }) => StudyTask(
    id: id,
    title: title,
    moduleId: moduleId,
    topicId: topicId,
    dueAt: dueAt,
    estimatedMinutes: estimatedMinutes,
    priority: priority,
    status: status ?? this.status,
    plannedStartAt: plannedStartAt ?? this.plannedStartAt,
    isAiGenerated: isAiGenerated,
    needsRescheduling: needsRescheduling ?? this.needsRescheduling,
    completedAt: completedAt ?? this.completedAt,
    notes: notes,
  );
}
