// Defines assignments, their subtasks, deadlines, and completion state.

import 'enums.dart';
import 'model_utils.dart';

final class Subtask {
  const Subtask({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.estimatedMinutes = 0,
    this.completedAt,
    this.order = 0,
  });

  final String id;
  final String title;
  final bool isCompleted;
  final int estimatedMinutes;
  final DateTime? completedAt;
  final int order;

  factory Subtask.fromMap(Map<String, Object?> map, {String? id}) => Subtask(
    id: id ?? ModelUtils.requiredString(map, 'id'),
    title: ModelUtils.requiredString(map, 'title'),
    isCompleted: ModelUtils.boolean(map, 'isCompleted'),
    estimatedMinutes: ModelUtils.integer(map, 'estimatedMinutes', fallback: 0),
    completedAt: ModelUtils.optionalDateTime(map, 'completedAt'),
    order: ModelUtils.integer(map, 'order', fallback: 0),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'isCompleted': isCompleted,
    'estimatedMinutes': estimatedMinutes,
    'completedAt': completedAt,
    'order': order,
  };

  Subtask copyWith({bool? isCompleted, DateTime? completedAt}) => Subtask(
    id: id,
    title: title,
    isCompleted: isCompleted ?? this.isCompleted,
    estimatedMinutes: estimatedMinutes,
    completedAt: completedAt ?? this.completedAt,
    order: order,
  );
}

final class AttachmentMetadata {
  const AttachmentMetadata({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.objectKey,
    required this.createdAt,
  });

  final String id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String objectKey;
  final DateTime createdAt;

  factory AttachmentMetadata.fromMap(Map<String, Object?> map) =>
      AttachmentMetadata(
        id: ModelUtils.requiredString(map, 'id'),
        fileName: ModelUtils.requiredString(map, 'fileName'),
        contentType: ModelUtils.requiredString(map, 'contentType'),
        sizeBytes: ModelUtils.integer(map, 'sizeBytes'),
        objectKey: ModelUtils.requiredString(map, 'objectKey'),
        createdAt: ModelUtils.dateTime(map, 'createdAt'),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'fileName': fileName,
    'contentType': contentType,
    'sizeBytes': sizeBytes,
    'objectKey': objectKey,
    'createdAt': createdAt,
  };
}

final class Assignment {
  Assignment({
    required this.id,
    required this.moduleId,
    required this.title,
    required this.dueAt,
    required this.priority,
    required this.estimatedMinutes,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    List<Subtask> subtasks = const [],
    double manualProgress = 0,
    this.reminderAt,
    List<AttachmentMetadata> attachments = const [],
  }) : subtasks = List.unmodifiable(subtasks),
       manualProgress = ModelUtils.clampUnit(manualProgress),
       attachments = List.unmodifiable(attachments);

  final String id;
  final String moduleId;
  final String title;
  final String? description;
  final DateTime dueAt;
  final PriorityLevel priority;
  final int estimatedMinutes;
  final WorkStatus status;
  final List<Subtask> subtasks;
  final double manualProgress;
  final DateTime? reminderAt;
  final List<AttachmentMetadata> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Assignment.fromMap(
    Map<String, Object?> map, {
    String? id,
  }) => Assignment(
    id: id ?? ModelUtils.requiredString(map, 'id'),
    moduleId: ModelUtils.requiredString(map, 'moduleId'),
    title: ModelUtils.requiredString(map, 'title'),
    description: ModelUtils.optionalString(map, 'description'),
    dueAt: ModelUtils.dateTime(map, 'dueAt'),
    priority: ModelUtils.enumValue(
      map,
      'priority',
      PriorityLevel.values,
      fallback: PriorityLevel.medium,
    ),
    estimatedMinutes: ModelUtils.integer(map, 'estimatedMinutes', fallback: 0),
    status: ModelUtils.enumValue(
      map,
      'status',
      WorkStatus.values,
      fallback: WorkStatus.notStarted,
    ),
    subtasks:
        ModelUtils.list(map, 'subtasks')
            .map(
              (value) => Subtask.fromMap(
                ModelUtils.objectMap(value, field: 'subtasks'),
              ),
            )
            .toList(),
    manualProgress: ModelUtils.decimal(map, 'manualProgress', fallback: 0),
    reminderAt: ModelUtils.optionalDateTime(map, 'reminderAt'),
    attachments:
        ModelUtils.list(map, 'attachments')
            .map(
              (value) => AttachmentMetadata.fromMap(
                ModelUtils.objectMap(value, field: 'attachments'),
              ),
            )
            .toList(),
    createdAt: ModelUtils.dateTime(
      map,
      'createdAt',
      fallback: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
    updatedAt: ModelUtils.dateTime(
      map,
      'updatedAt',
      fallback: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    ),
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'moduleId': moduleId,
    'title': title,
    'description': description,
    'dueAt': dueAt,
    'priority': priority.name,
    'estimatedMinutes': estimatedMinutes,
    'status': status.name,
    'subtasks': subtasks.map((subtask) => subtask.toMap()).toList(),
    'manualProgress': manualProgress,
    'reminderAt': reminderAt,
    'attachments': attachments.map((item) => item.toMap()).toList(),
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  Assignment copyWith({
    String? title,
    String? description,
    DateTime? dueAt,
    PriorityLevel? priority,
    int? estimatedMinutes,
    WorkStatus? status,
    List<Subtask>? subtasks,
    double? manualProgress,
    DateTime? reminderAt,
    List<AttachmentMetadata>? attachments,
    DateTime? updatedAt,
  }) => Assignment(
    id: id,
    moduleId: moduleId,
    title: title ?? this.title,
    description: description ?? this.description,
    dueAt: dueAt ?? this.dueAt,
    priority: priority ?? this.priority,
    estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    status: status ?? this.status,
    subtasks: subtasks ?? this.subtasks,
    manualProgress: manualProgress ?? this.manualProgress,
    reminderAt: reminderAt ?? this.reminderAt,
    attachments: attachments ?? this.attachments,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
