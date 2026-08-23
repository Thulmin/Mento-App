// Provides habit data and commands for logs and optional wellness check-ins.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

final habitsProvider = StreamProvider<List<Habit>>(
  (ref) => ref.watch(studentRepositoryProvider).watchHabits(),
);

final currentHabitLogsProvider = StreamProvider<List<HabitLog>>((ref) {
  final now = DateTime.now();
  final from = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(const Duration(days: 35));
  return ref
      .watch(studentRepositoryProvider)
      .watchHabitLogs(from: from, before: now.add(const Duration(days: 1)));
});

final wellnessCheckInsProvider = StreamProvider<List<WellnessCheckIn>>(
  (ref) => ref.watch(studentRepositoryProvider).watchWellnessCheckIns(),
);

final habitActionProvider =
    NotifierProvider<HabitActionController, AsyncValue<void>>(
      HabitActionController.new,
    );

class HabitActionController extends Notifier<AsyncValue<void>> {
  static const _uuid = Uuid();

  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> _run(
    Future<void> Function(StudentRepository repository) action,
  ) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      await action(ref.read(studentRepositoryProvider));
      state = const AsyncData(null);
      return true;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      return false;
    }
  }

  Future<bool> addHabit({
    required String name,
    HabitCategory category = HabitCategory.custom,
    HabitFrequency frequency = HabitFrequency.daily,
    int weeklyTarget = 7,
  }) => _run(
    (repository) => repository.saveHabit(
      Habit(
        id: _uuid.v4(),
        name: name.trim(),
        category: category,
        frequency: frequency,
        weeklyTarget: weeklyTarget,
        createdAt: DateTime.now(),
      ),
    ),
  );

  Future<bool> toggleToday(Habit habit, HabitLog? existing) => _run((
    repository,
  ) async {
    if (existing != null) {
      await repository.deleteHabitLog(existing.id);
      return;
    }
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day);
    await repository.saveHabitLog(
      HabitLog(
        id:
            '${habit.id}_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}',
        habitId: habit.id,
        date: date,
        loggedAt: now,
      ),
    );
  });

  Future<bool> deleteHabit(Habit habit) =>
      _run((repository) => repository.deleteHabit(habit.id));

  Future<bool> addCheckIn({
    required int mood,
    required int energy,
    double? sleepHours,
    String? note,
  }) => _run(
    (repository) => repository.saveWellnessCheckIn(
      WellnessCheckIn(
        id: _uuid.v4(),
        recordedAt: DateTime.now(),
        mood: mood,
        energy: energy,
        sleepHours: sleepHours,
        note: note?.trim().isEmpty == true ? null : note?.trim(),
      ),
    ),
  );

  Future<bool> deleteCheckIn(String id) =>
      _run((repository) => repository.deleteWellnessCheckIn(id));

  Future<bool> deleteAllCheckIns(Iterable<WellnessCheckIn> items) =>
      _run((repository) async {
        for (final item in items) {
          await repository.deleteWellnessCheckIn(item.id);
        }
      });
}
