// Restores and controls the active focus session and its completion reminder.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logic/logic.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

class FocusTimerState {
  const FocusTimerState({
    this.active,
    this.history = const [],
    this.now,
    this.loading = true,
    this.saving = false,
    this.error,
  });

  final FocusSession? active;
  final List<FocusSession> history;
  final DateTime? now;
  final bool loading;
  final bool saving;
  final String? error;

  Duration get elapsed =>
      active == null
          ? Duration.zero
          : FocusSessionCalculator.elapsed(active!, at: now ?? DateTime.now());

  Duration get remaining =>
      active == null
          ? Duration.zero
          : FocusSessionCalculator.remaining(
            active!,
            at: now ?? DateTime.now(),
          );

  double get progress {
    if (active == null) return 0;
    return (elapsed.inSeconds / (active!.targetMinutes * 60)).clamp(0, 1);
  }

  FocusTimerState copyWith({
    FocusSession? active,
    bool clearActive = false,
    List<FocusSession>? history,
    DateTime? now,
    bool? loading,
    bool? saving,
    String? error,
    bool clearError = false,
  }) => FocusTimerState(
    active: clearActive ? null : active ?? this.active,
    history: history ?? this.history,
    now: now ?? this.now,
    loading: loading ?? this.loading,
    saving: saving ?? this.saving,
    error: clearError ? null : error ?? this.error,
  );
}

final focusTimerProvider =
    NotifierProvider<FocusTimerController, FocusTimerState>(
      FocusTimerController.new,
    );

class FocusTimerController extends Notifier<FocusTimerState> {
  static const _uuid = Uuid();
  StreamSubscription<List<FocusSession>>? _subscription;
  Timer? _ticker;
  bool _autoCompleting = false;

  @override
  FocusTimerState build() {
    final repository = ref.watch(studentRepositoryProvider);
    ref.onDispose(() {
      _subscription?.cancel();
      _ticker?.cancel();
    });
    _subscription = repository
        .watchFocusSessions(limit: 100)
        .listen(
          (sessions) {
            final active = sessions.cast<FocusSession?>().firstWhere(
              (session) =>
                  session?.state == FocusSessionState.running ||
                  session?.state == FocusSessionState.paused,
              orElse: () => null,
            );
            state = state.copyWith(
              active: active,
              clearActive: active == null,
              history:
                  sessions
                      .where(
                        (session) =>
                            session.state == FocusSessionState.completed ||
                            session.state == FocusSessionState.cancelled,
                      )
                      .toList(),
              now: DateTime.now(),
              loading: false,
            );
            _syncTicker();
          },
          onError: (Object error) {
            state = state.copyWith(
              loading: false,
              error:
                  'Focus history could not be loaded. Check your connection.',
            );
          },
        );
    return FocusTimerState(now: DateTime.now());
  }

  Future<void> start({
    required int minutes,
    required String goal,
    String? moduleId,
    bool isBreak = false,
  }) async {
    if (state.active != null || state.saving) return;
    final now = DateTime.now();
    final session = FocusSessionCalculator.start(
      id: _uuid.v4(),
      goal:
          goal.trim().isEmpty
              ? (isBreak ? 'Recovery break' : 'Focused study')
              : goal.trim(),
      targetMinutes: minutes,
      at: now,
      moduleId: moduleId,
      isBreak: isBreak,
    );
    await _save(session, optimistic: true);
    await NotificationService.instance.schedule(
      entityId: session.id,
      category: ReminderCategory.focus,
      title: isBreak ? 'Break complete' : 'Focus session complete',
      body:
          isBreak
              ? 'Return gently when you are ready.'
              : 'Nice work. Take a deliberate break before the next task.',
      scheduledFor: now.add(Duration(minutes: minutes)),
      payload: '/focus',
      quietStartHour: 24,
      quietEndHour: 0,
    );
  }

  Future<void> pause() async {
    final active = state.active;
    if (active == null || active.state != FocusSessionState.running) return;
    final paused = FocusSessionCalculator.pause(active, at: DateTime.now());
    await NotificationService.instance.cancel(
      ReminderCategory.focus,
      active.id,
    );
    await _save(paused, optimistic: true);
  }

  Future<void> resume() async {
    final active = state.active;
    if (active == null || active.state != FocusSessionState.paused) return;
    final now = DateTime.now();
    final resumed = FocusSessionCalculator.resume(active, at: now);
    await _save(resumed, optimistic: true);
    await NotificationService.instance.schedule(
      entityId: resumed.id,
      category: ReminderCategory.focus,
      title: resumed.isBreak ? 'Break complete' : 'Focus session complete',
      body:
          resumed.isBreak
              ? 'Return gently when you are ready.'
              : 'Your planned focus block is complete.',
      scheduledFor: now.add(FocusSessionCalculator.remaining(resumed, at: now)),
      payload: '/focus',
      quietStartHour: 24,
      quietEndHour: 0,
    );
  }

  Future<void> complete() async {
    final active = state.active;
    if (active == null || state.saving) return;
    final completed = FocusSessionCalculator.complete(
      active,
      at: DateTime.now(),
    );
    await NotificationService.instance.cancel(
      ReminderCategory.focus,
      active.id,
    );
    await _save(completed, optimistic: true, clearActive: true);
  }

  Future<void> stop() async {
    final active = state.active;
    if (active == null || state.saving) return;
    final cancelled = FocusSessionCalculator.cancel(active, at: DateTime.now());
    await NotificationService.instance.cancel(
      ReminderCategory.focus,
      active.id,
    );
    await _save(cancelled, optimistic: true, clearActive: true);
  }

  Future<void> _save(
    FocusSession session, {
    required bool optimistic,
    bool clearActive = false,
  }) async {
    final previous = state;
    if (optimistic) {
      state = state.copyWith(
        active: session,
        clearActive: clearActive,
        now: DateTime.now(),
        saving: true,
        clearError: true,
      );
    }
    try {
      await ref.read(studentRepositoryProvider).saveFocusSession(session);
      state = state.copyWith(saving: false);
    } catch (_) {
      state = previous.copyWith(
        saving: false,
        error: 'The focus session could not be saved. Please retry.',
      );
    }
  }

  void _syncTicker() {
    final running = state.active?.state == FocusSessionState.running;
    if (!running) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    // This ticker refreshes the display only. Elapsed time is calculated from
    // timestamps, so delayed frames do not lose study time.
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final active = state.active;
      if (active == null || active.state != FocusSessionState.running) return;
      final now = DateTime.now();
      state = state.copyWith(now: now);
      if (!_autoCompleting &&
          FocusSessionCalculator.targetReached(active, at: now)) {
        _autoCompleting = true;
        complete().whenComplete(() => _autoCompleting = false);
      }
    });
  }
}

final focusModulesProvider = StreamProvider<List<Module>>(
  (ref) => ref.watch(studentRepositoryProvider).watchModules(),
);
