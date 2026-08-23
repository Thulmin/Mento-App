// Stores focus sessions so an active timer survives pauses and app restarts.

import 'enums.dart';
import 'model_utils.dart';

/// Persisted focus timer state.
///
/// Accuracy never depends on timer ticks. [accumulatedActiveSeconds] stores
/// completed active segments while [lastResumedAt] anchors the current segment.
final class FocusSession {
  FocusSession({
    required this.id,
    required this.goal,
    required this.targetMinutes,
    required this.startedAt,
    required this.state,
    required this.accumulatedActiveSeconds,
    required this.accumulatedPausedSeconds,
    this.moduleId,
    this.topicId,
    this.lastResumedAt,
    this.pausedAt,
    this.endedAt,
    this.isBreak = false,
    this.interruptionCount = 0,
  }) {
    if (targetMinutes <= 0) {
      throw ArgumentError.value(targetMinutes, 'targetMinutes', 'Must be > 0.');
    }
    if (accumulatedActiveSeconds < 0 || accumulatedPausedSeconds < 0) {
      throw ArgumentError('Accumulated durations cannot be negative.');
    }
    if (state == FocusSessionState.running && lastResumedAt == null) {
      throw ArgumentError('A running session requires lastResumedAt.');
    }
    if (state == FocusSessionState.paused && pausedAt == null) {
      throw ArgumentError('A paused session requires pausedAt.');
    }
  }

  final String id;
  final String? moduleId;
  final String? topicId;
  final String goal;
  final int targetMinutes;
  final DateTime startedAt;
  final FocusSessionState state;
  final DateTime? lastResumedAt;
  final DateTime? pausedAt;
  final DateTime? endedAt;
  final int accumulatedActiveSeconds;
  final int accumulatedPausedSeconds;
  final bool isBreak;
  final int interruptionCount;

  factory FocusSession.fromMap(Map<String, Object?> map, {String? id}) =>
      FocusSession(
        id: id ?? ModelUtils.requiredString(map, 'id'),
        moduleId: ModelUtils.optionalString(map, 'moduleId'),
        topicId: ModelUtils.optionalString(map, 'topicId'),
        goal: ModelUtils.requiredString(map, 'goal'),
        targetMinutes: ModelUtils.integer(map, 'targetMinutes'),
        startedAt: ModelUtils.dateTime(map, 'startedAt'),
        state: ModelUtils.enumValue(
          map,
          'state',
          FocusSessionState.values,
          fallback: FocusSessionState.completed,
        ),
        lastResumedAt: ModelUtils.optionalDateTime(map, 'lastResumedAt'),
        pausedAt: ModelUtils.optionalDateTime(map, 'pausedAt'),
        endedAt: ModelUtils.optionalDateTime(map, 'endedAt'),
        accumulatedActiveSeconds: ModelUtils.integer(
          map,
          'accumulatedActiveSeconds',
          fallback: 0,
        ),
        accumulatedPausedSeconds: ModelUtils.integer(
          map,
          'accumulatedPausedSeconds',
          fallback: 0,
        ),
        isBreak: ModelUtils.boolean(map, 'isBreak'),
        interruptionCount: ModelUtils.integer(
          map,
          'interruptionCount',
          fallback: 0,
        ),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'moduleId': moduleId,
    'topicId': topicId,
    'goal': goal,
    'targetMinutes': targetMinutes,
    'startedAt': startedAt,
    'state': state.name,
    'lastResumedAt': lastResumedAt,
    'pausedAt': pausedAt,
    'endedAt': endedAt,
    'accumulatedActiveSeconds': accumulatedActiveSeconds,
    'accumulatedPausedSeconds': accumulatedPausedSeconds,
    'isBreak': isBreak,
    'interruptionCount': interruptionCount,
  };
}
