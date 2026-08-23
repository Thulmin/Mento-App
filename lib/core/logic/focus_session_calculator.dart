// Applies the focus timer's state changes using timestamps instead of UI ticks.

import '../../data/models/enums.dart';
import '../../data/models/focus_session.dart';

abstract final class FocusSessionCalculator {
  static FocusSession start({
    required String id,
    required String goal,
    required int targetMinutes,
    required DateTime at,
    String? moduleId,
    String? topicId,
    bool isBreak = false,
  }) => FocusSession(
    id: id,
    moduleId: moduleId,
    topicId: topicId,
    goal: goal,
    targetMinutes: targetMinutes,
    startedAt: at,
    state: FocusSessionState.running,
    lastResumedAt: at,
    accumulatedActiveSeconds: 0,
    accumulatedPausedSeconds: 0,
    isBreak: isBreak,
  );

  static Duration elapsed(FocusSession session, {required DateTime at}) {
    var seconds = session.accumulatedActiveSeconds;
    if (session.state == FocusSessionState.running) {
      final anchor = session.lastResumedAt!;
      if (at.isBefore(anchor)) {
        throw ArgumentError.value(at, 'at', 'Cannot precede last resume time.');
      }
      seconds += at.difference(anchor).inSeconds;
    }
    return Duration(seconds: seconds);
  }

  static Duration remaining(FocusSession session, {required DateTime at}) {
    final difference =
        Duration(minutes: session.targetMinutes) - elapsed(session, at: at);
    return difference.isNegative ? Duration.zero : difference;
  }

  static bool targetReached(FocusSession session, {required DateTime at}) =>
      elapsed(session, at: at) >= Duration(minutes: session.targetMinutes);

  static FocusSession pause(FocusSession session, {required DateTime at}) {
    if (session.state != FocusSessionState.running) {
      throw StateError('Only a running focus session can be paused.');
    }
    final active = elapsed(session, at: at).inSeconds;
    return FocusSession(
      id: session.id,
      moduleId: session.moduleId,
      topicId: session.topicId,
      goal: session.goal,
      targetMinutes: session.targetMinutes,
      startedAt: session.startedAt,
      state: FocusSessionState.paused,
      pausedAt: at,
      accumulatedActiveSeconds: active,
      accumulatedPausedSeconds: session.accumulatedPausedSeconds,
      isBreak: session.isBreak,
      interruptionCount: session.interruptionCount + 1,
    );
  }

  static FocusSession resume(FocusSession session, {required DateTime at}) {
    if (session.state != FocusSessionState.paused) {
      throw StateError('Only a paused focus session can be resumed.');
    }
    if (at.isBefore(session.pausedAt!)) {
      throw ArgumentError.value(at, 'at', 'Cannot precede pause time.');
    }
    return FocusSession(
      id: session.id,
      moduleId: session.moduleId,
      topicId: session.topicId,
      goal: session.goal,
      targetMinutes: session.targetMinutes,
      startedAt: session.startedAt,
      state: FocusSessionState.running,
      lastResumedAt: at,
      accumulatedActiveSeconds: session.accumulatedActiveSeconds,
      accumulatedPausedSeconds:
          session.accumulatedPausedSeconds +
          at.difference(session.pausedAt!).inSeconds,
      isBreak: session.isBreak,
      interruptionCount: session.interruptionCount,
    );
  }

  static FocusSession complete(FocusSession session, {required DateTime at}) =>
      _finish(session, at: at, state: FocusSessionState.completed);

  static FocusSession cancel(FocusSession session, {required DateTime at}) =>
      _finish(session, at: at, state: FocusSessionState.cancelled);

  static FocusSession _finish(
    FocusSession session, {
    required DateTime at,
    required FocusSessionState state,
  }) {
    if (session.state == FocusSessionState.completed ||
        session.state == FocusSessionState.cancelled) {
      throw StateError('Focus session has already ended.');
    }
    final activeSeconds = elapsed(session, at: at).inSeconds;
    var pausedSeconds = session.accumulatedPausedSeconds;
    if (session.state == FocusSessionState.paused) {
      if (at.isBefore(session.pausedAt!)) {
        throw ArgumentError.value(at, 'at', 'Cannot precede pause time.');
      }
      pausedSeconds += at.difference(session.pausedAt!).inSeconds;
    }
    return FocusSession(
      id: session.id,
      moduleId: session.moduleId,
      topicId: session.topicId,
      goal: session.goal,
      targetMinutes: session.targetMinutes,
      startedAt: session.startedAt,
      state: state,
      endedAt: at,
      accumulatedActiveSeconds: activeSeconds,
      accumulatedPausedSeconds: pausedSeconds,
      isBreak: session.isBreak,
      interruptionCount: session.interruptionCount,
    );
  }
}
