// Presents habit tracking and optional, non-clinical wellness check-ins.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../app/theme/mento_colors.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_controls.dart';
import '../../../core/widgets/mento_states.dart';
import '../../../data/models/models.dart';
import '../../profile/application/profile_settings_controller.dart';
import '../application/habit_providers.dart';

class HabitsWellnessScreen extends ConsumerWidget {
  const HabitsWellnessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wellnessEnabled =
        ref.watch(profileSettingsProvider).value?.wellnessEnabled ?? true;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Habits & wellbeing'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Habits'),
              Tab(text: 'Check-in'),
              Tab(text: 'Trends'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HabitsTab(wellnessEnabled: wellnessEnabled),
            wellnessEnabled ? const _CheckInTab() : const _WellnessDisabled(),
            wellnessEnabled ? const _TrendsTab() : const _WellnessDisabled(),
          ],
        ),
      ),
    );
  }
}

class _HabitsTab extends ConsumerWidget {
  const _HabitsTab({required this.wellnessEnabled});
  final bool wellnessEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(habitsProvider);
    final logs =
        ref.watch(currentHabitLogsProvider).value ?? const <HabitLog>[];
    final action = ref.watch(habitActionProvider);
    ref.listen(habitActionProvider, (_, next) {
      if (next case AsyncError()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'That habit change could not be saved. Please retry.',
            ),
          ),
        );
      }
    });
    return habits.when(
      loading: () => const MentoPage(child: MentoLoadingSkeleton(height: 280)),
      error:
          (_, __) => MentoErrorState(
            title: 'Habits are unavailable',
            message:
                'Saved habit data will return when the connection recovers.',
            onRetry: () => ref.invalidate(habitsProvider),
          ),
      data:
          (items) => MentoPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MentoCard(
                  highlighted: true,
                  child: Row(
                    children: [
                      Icon(
                        Icons.spa_outlined,
                        color: context.mentoColors.success,
                        size: 34,
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Text(
                          'Rest days count. Check off what genuinely helped today; a missed habit is information, not failure.',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Today',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    MentoButton(
                      label: 'Add habit',
                      icon: Icons.add,
                      expand: false,
                      loading: action.isLoading,
                      onPressed: () => _addHabit(context, ref),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  MentoEmptyState(
                    title: 'Choose one supportive habit',
                    message:
                        'Start small with water, movement, reading, breaks or a custom routine.',
                    icon: Icons.eco_outlined,
                    actionLabel: 'Browse templates',
                    onAction: () => _addHabit(context, ref),
                  )
                else
                  for (final habit in items) ...[
                    _HabitTile(
                      habit: habit,
                      log: _todayLog(habit, logs),
                      disabled: action.isLoading,
                      onToggle:
                          () => ref
                              .read(habitActionProvider.notifier)
                              .toggleToday(habit, _todayLog(habit, logs)),
                      onDelete: () => _confirmDeleteHabit(context, ref, habit),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
          ),
    );
  }

  HabitLog? _todayLog(Habit habit, List<HabitLog> logs) {
    final now = DateTime.now();
    for (final log in logs) {
      if (log.habitId == habit.id &&
          log.date.year == now.year &&
          log.date.month == now.month &&
          log.date.day == now.day) {
        return log;
      }
    }
    return null;
  }

  Future<void> _addHabit(BuildContext context, WidgetRef ref) async {
    final name = TextEditingController();
    var category = HabitCategory.hydration;
    var weeklyTarget = 7;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      20 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Add a gentle habit',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final template in const [
                              ('Hydration check', HabitCategory.hydration),
                              ('Movement break', HabitCategory.movement),
                              ('Read away from screens', HabitCategory.reading),
                              ('Sleep wind-down', HabitCategory.sleep),
                            ])
                              ActionChip(
                                label: Text(template.$1),
                                onPressed:
                                    () => setModalState(() {
                                      name.text = template.$1;
                                      category = template.$2;
                                    }),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        MentoTextField(label: 'Habit name', controller: name),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<HabitCategory>(
                          value: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                          items: [
                            for (final value in HabitCategory.values)
                              DropdownMenuItem(
                                value: value,
                                child: Text(_label(value.name)),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => category = value);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          value: weeklyTarget,
                          decoration: const InputDecoration(
                            labelText: 'Weekly target',
                          ),
                          items: [
                            for (var value = 1; value <= 7; value++)
                              DropdownMenuItem(
                                value: value,
                                child: Text(
                                  '$value day${value == 1 ? '' : 's'} per week',
                                ),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => weeklyTarget = value);
                            }
                          },
                        ),
                        const SizedBox(height: 18),
                        MentoButton(
                          label: 'Save habit',
                          onPressed:
                              () => Navigator.pop(
                                context,
                                name.text.trim().isNotEmpty,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    if (saved == true) {
      await ref
          .read(habitActionProvider.notifier)
          .addHabit(
            name: name.text,
            category: category,
            frequency:
                weeklyTarget == 7
                    ? HabitFrequency.daily
                    : HabitFrequency.timesPerWeek,
            weeklyTarget: weeklyTarget,
          );
    }
    name.dispose();
  }

  Future<void> _confirmDeleteHabit(
    BuildContext context,
    WidgetRef ref,
    Habit habit,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Delete ${habit.name}?'),
            content: const Text(
              'This also deletes its completion logs. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref.read(habitActionProvider.notifier).deleteHabit(habit);
    }
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({
    required this.habit,
    required this.log,
    required this.disabled,
    required this.onToggle,
    required this.onDelete,
  });
  final Habit habit;
  final HabitLog? log;
  final bool disabled;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => MentoCard(
    highlighted: log != null,
    child: Row(
      children: [
        Checkbox(
          value: log != null,
          onChanged: disabled ? null : (_) => onToggle(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(habit.name, style: Theme.of(context).textTheme.titleMedium),
              Text(
                '${_label(habit.category.name)} · ${habit.weeklyTarget}× weekly target',
              ),
            ],
          ),
        ),
        MentoIconButton(
          icon: Icons.delete_outline,
          tooltip: 'Delete ${habit.name}',
          onPressed: disabled ? null : onDelete,
        ),
      ],
    ),
  );
}

class _CheckInTab extends ConsumerStatefulWidget {
  const _CheckInTab();

  @override
  ConsumerState<_CheckInTab> createState() => _CheckInTabState();
}

class _CheckInTabState extends ConsumerState<_CheckInTab> {
  int _mood = 3;
  int _energy = 3;
  double _sleep = 7;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MentoPage(
    child: MentoCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A quick, non-clinical check-in',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'This supports workload choices only. It is not a diagnosis or health assessment.',
          ),
          const SizedBox(height: 20),
          _Scale(
            label: 'Mood',
            value: _mood,
            low: 'Low',
            high: 'Positive',
            onChanged: (value) => setState(() => _mood = value),
          ),
          _Scale(
            label: 'Energy',
            value: _energy,
            low: 'Drained',
            high: 'Energised',
            onChanged: (value) => setState(() => _energy = value),
          ),
          Text('Sleep routine: ${_sleep.toStringAsFixed(1)} hours'),
          Slider(
            value: _sleep,
            min: 0,
            max: 12,
            divisions: 24,
            label: '${_sleep.toStringAsFixed(1)} hours',
            onChanged: (value) => setState(() => _sleep = value),
          ),
          MentoTextField(
            label: 'Optional note',
            controller: _note,
            maxLines: 3,
          ),
          const SizedBox(height: 18),
          MentoButton(
            label: 'Save check-in',
            onPressed: () async {
              final success = await ref
                  .read(habitActionProvider.notifier)
                  .addCheckIn(
                    mood: _mood,
                    energy: _energy,
                    sleepHours: _sleep,
                    note: _note.text,
                  );
              if (success && context.mounted) {
                _note.clear();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Check-in saved privately.')),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

class _Scale extends StatelessWidget {
  const _Scale({
    required this.label,
    required this.value,
    required this.low,
    required this.high,
    required this.onChanged,
  });
  final String label;
  final int value;
  final String low;
  final String high;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label: $value of 5',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      Slider(
        value: value.toDouble(),
        min: 1,
        max: 5,
        divisions: 4,
        label: '$value',
        onChanged: (value) => onChanged(value.round()),
      ),
      Row(children: [Text(low), const Spacer(), Text(high)]),
      const SizedBox(height: 18),
    ],
  );
}

class _TrendsTab extends ConsumerWidget {
  const _TrendsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkIns = ref.watch(wellnessCheckInsProvider);
    final logs =
        ref.watch(currentHabitLogsProvider).value ?? const <HabitLog>[];
    return checkIns.when(
      loading: () => const MentoPage(child: MentoLoadingSkeleton(height: 260)),
      error:
          (_, __) => const MentoErrorState(
            title: 'Trends are unavailable',
            message: 'Try again when your saved check-ins can be loaded.',
          ),
      data: (items) {
        final recent =
            items
                .where(
                  (item) => item.recordedAt.isAfter(
                    DateTime.now().subtract(const Duration(days: 7)),
                  ),
                )
                .toList();
        final mood =
            recent.isEmpty
                ? null
                : recent.fold<int>(0, (sum, item) => sum + item.mood) /
                    recent.length;
        final energy =
            recent.isEmpty
                ? null
                : recent.fold<int>(0, (sum, item) => sum + item.energy) /
                    recent.length;
        return MentoPage(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Last 7 days',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 14),
              MentoResponsiveGrid(
                compactColumns: 2,
                mediumColumns: 3,
                expandedColumns: 3,
                children: [
                  MentoStatCard(
                    label: 'Average mood',
                    value: mood == null ? '—' : '${mood.toStringAsFixed(1)}/5',
                    icon: Icons.sentiment_satisfied_alt_outlined,
                  ),
                  MentoStatCard(
                    label: 'Average energy',
                    value:
                        energy == null ? '—' : '${energy.toStringAsFixed(1)}/5',
                    icon: Icons.battery_charging_full_outlined,
                  ),
                  MentoStatCard(
                    label: 'Habit check-offs',
                    value:
                        '${logs.where((log) => log.date.isAfter(DateTime.now().subtract(const Duration(days: 7)))).length}',
                    icon: Icons.eco_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              MentoCard(
                child: Text(
                  recent.isEmpty
                      ? 'No trend yet. One optional check-in is enough to begin; skipping is always okay.'
                      : 'Text summary: your recent mood average is ${mood!.toStringAsFixed(1)} and energy average is ${energy!.toStringAsFixed(1)} on a five-point organisational scale.',
                ),
              ),
              const SizedBox(height: 18),
              for (final item in items.take(12))
                ListTile(
                  title: Text(
                    '${DateFormat('EEE d MMM').format(item.recordedAt)} · Mood ${item.mood}/5 · Energy ${item.energy}/5',
                  ),
                  subtitle: item.note == null ? null : Text(item.note!),
                  trailing: MentoIconButton(
                    icon: Icons.delete_outline,
                    tooltip:
                        'Delete check-in from ${DateFormat('d MMM').format(item.recordedAt)}',
                    onPressed:
                        () => ref
                            .read(habitActionProvider.notifier)
                            .deleteCheckIn(item.id),
                  ),
                ),
              if (items.isNotEmpty)
                MentoButton(
                  label: 'Delete all wellness records',
                  variant: MentoButtonVariant.text,
                  onPressed: () => _deleteAll(context, ref, items),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteAll(
    BuildContext context,
    WidgetRef ref,
    List<WellnessCheckIn> items,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete all wellness records?'),
            content: const Text(
              'This permanently removes all mood, energy, sleep and note check-ins.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete all'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref.read(habitActionProvider.notifier).deleteAllCheckIns(items);
    }
  }
}

class _WellnessDisabled extends StatelessWidget {
  const _WellnessDisabled();

  @override
  Widget build(BuildContext context) => const MentoEmptyState(
    title: 'Wellness tracking is off',
    message:
        'Enable it in Profile only if check-ins would feel useful. Academic planning continues without it.',
    icon: Icons.visibility_off_outlined,
  );
}

String _label(String value) => value
    .replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)!.toLowerCase()}',
    )
    .replaceFirstMapped(RegExp('^.'), (match) => match.group(0)!.toUpperCase());
