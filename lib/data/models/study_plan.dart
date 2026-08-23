// Defines proposed study plans, individual time blocks, and their status.

import 'enums.dart';
import 'model_utils.dart';

final class PlanBlock {
  PlanBlock({
    required this.id,
    required this.startAt,
    required this.endAt,
    required this.objective,
    required this.recommendedMethod,
    required this.priority,
    required this.reason,
    required this.source,
    this.moduleId,
    this.topicId,
    this.linkedTaskId,
    this.breakMinutes = 0,
    this.status = PlanBlockStatus.proposed,
  }) {
    if (!endAt.isAfter(startAt)) {
      throw ArgumentError.value(endAt, 'endAt', 'Must be after startAt.');
    }
    if (breakMinutes < 0) {
      throw ArgumentError.value(
        breakMinutes,
        'breakMinutes',
        'Cannot be negative.',
      );
    }
  }

  final String id;
  final DateTime startAt;
  final DateTime endAt;
  final String? moduleId;
  final String? topicId;
  final String objective;
  final String recommendedMethod;
  final int breakMinutes;
  final PriorityLevel priority;
  final String reason;
  final PlanSource source;
  final String? linkedTaskId;
  final PlanBlockStatus status;

  Duration get duration => endAt.difference(startAt);
  DateTime get date => DateTime(startAt.year, startAt.month, startAt.day);

  factory PlanBlock.fromMap(Map<String, Object?> map, {String? id}) =>
      PlanBlock(
        id: id ?? ModelUtils.requiredString(map, 'id'),
        startAt: ModelUtils.dateTime(map, 'startAt'),
        endAt: ModelUtils.dateTime(map, 'endAt'),
        moduleId: ModelUtils.optionalString(map, 'moduleId'),
        topicId: ModelUtils.optionalString(map, 'topicId'),
        objective: ModelUtils.requiredString(map, 'objective'),
        recommendedMethod: ModelUtils.requiredString(map, 'recommendedMethod'),
        breakMinutes: ModelUtils.integer(map, 'breakMinutes', fallback: 0),
        priority: ModelUtils.enumValue(
          map,
          'priority',
          PriorityLevel.values,
          fallback: PriorityLevel.medium,
        ),
        reason: ModelUtils.requiredString(map, 'reason'),
        source: ModelUtils.enumValue(
          map,
          'source',
          PlanSource.values,
          fallback: PlanSource.user,
        ),
        linkedTaskId: ModelUtils.optionalString(map, 'linkedTaskId'),
        status: ModelUtils.enumValue(
          map,
          'status',
          PlanBlockStatus.values,
          fallback: PlanBlockStatus.proposed,
        ),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'startAt': startAt,
    'endAt': endAt,
    'moduleId': moduleId,
    'topicId': topicId,
    'objective': objective,
    'recommendedMethod': recommendedMethod,
    'breakMinutes': breakMinutes,
    'priority': priority.name,
    'reason': reason,
    'source': source.name,
    'linkedTaskId': linkedTaskId,
    'status': status.name,
  };

  PlanBlock copyWith({
    DateTime? startAt,
    DateTime? endAt,
    int? breakMinutes,
    PlanBlockStatus? status,
  }) => PlanBlock(
    id: id,
    startAt: startAt ?? this.startAt,
    endAt: endAt ?? this.endAt,
    moduleId: moduleId,
    topicId: topicId,
    objective: objective,
    recommendedMethod: recommendedMethod,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    priority: priority,
    reason: reason,
    source: source,
    linkedTaskId: linkedTaskId,
    status: status ?? this.status,
  );
}

final class StudyPlan {
  StudyPlan({
    required this.id,
    required this.userId,
    required this.generatedAt,
    required this.rangeStart,
    required this.rangeEnd,
    required this.source,
    required this.maxDailyMinutes,
    List<PlanBlock> blocks = const [],
    this.isAccepted = false,
    this.rationale,
    Map<String, int> unplannedMinutes = const {},
    this.schemaVersion = 1,
  }) : blocks = List.unmodifiable(blocks),
       unplannedMinutes = Map.unmodifiable(unplannedMinutes) {
    if (!rangeEnd.isAfter(rangeStart)) {
      throw ArgumentError.value(
        rangeEnd,
        'rangeEnd',
        'Must be after rangeStart.',
      );
    }
  }

  final String id;
  final String userId;
  final DateTime generatedAt;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final PlanSource source;
  final List<PlanBlock> blocks;
  final int maxDailyMinutes;
  final bool isAccepted;
  final String? rationale;
  final Map<String, int> unplannedMinutes;
  final int schemaVersion;

  factory StudyPlan.fromMap(Map<String, Object?> map, {String? id}) {
    final rawUnplanned = map['unplannedMinutes'];
    final unplanned =
        rawUnplanned == null
            ? <String, int>{}
            : ModelUtils.objectMap(rawUnplanned, field: 'unplannedMinutes').map(
              (key, value) {
                if (value is! num) {
                  throw const FormatException(
                    'Unplanned minute values must be numbers.',
                  );
                }
                return MapEntry(key, value.toInt());
              },
            );
    return StudyPlan(
      id: id ?? ModelUtils.requiredString(map, 'id'),
      userId: ModelUtils.requiredString(map, 'userId'),
      generatedAt: ModelUtils.dateTime(map, 'generatedAt'),
      rangeStart: ModelUtils.dateTime(map, 'rangeStart'),
      rangeEnd: ModelUtils.dateTime(map, 'rangeEnd'),
      source: ModelUtils.enumValue(
        map,
        'source',
        PlanSource.values,
        fallback: PlanSource.user,
      ),
      blocks:
          ModelUtils.list(map, 'blocks')
              .map(
                (value) => PlanBlock.fromMap(
                  ModelUtils.objectMap(value, field: 'blocks'),
                ),
              )
              .toList(),
      maxDailyMinutes: ModelUtils.integer(
        map,
        'maxDailyMinutes',
        fallback: 240,
      ),
      isAccepted: ModelUtils.boolean(map, 'isAccepted'),
      rationale: ModelUtils.optionalString(map, 'rationale'),
      unplannedMinutes: unplanned,
      schemaVersion: ModelUtils.integer(map, 'schemaVersion', fallback: 1),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'userId': userId,
    'generatedAt': generatedAt,
    'rangeStart': rangeStart,
    'rangeEnd': rangeEnd,
    'source': source.name,
    'blocks': blocks.map((block) => block.toMap()).toList(),
    'maxDailyMinutes': maxDailyMinutes,
    'isAccepted': isAccepted,
    'rationale': rationale,
    'unplannedMinutes': unplannedMinutes,
    'schemaVersion': schemaVersion,
  };
}
