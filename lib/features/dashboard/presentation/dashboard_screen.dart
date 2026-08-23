// Presents today's agenda, priorities, progress, and shortcuts to study tools.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../core/config/app_config.dart';
import '../../../core/logic/logic.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_controls.dart';
import '../../../core/widgets/mento_states.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../authentication/application/auth_providers.dart';
import '../../profile/application/profile_settings_controller.dart';
import '../application/dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final profile = ref.watch(profileSettingsProvider);
    final events = ref.watch(dashboardEventsProvider);
    final assignments = ref.watch(dashboardAssignmentsProvider);
    final exams = ref.watch(dashboardExamsProvider);
    final tasks = ref.watch(dashboardTasksProvider);
    final plans = ref.watch(dashboardPlansProvider);
    final habits = ref.watch(dashboardHabitsProvider);
    final logs = ref.watch(dashboardHabitLogsProvider);
    final focus = ref.watch(dashboardFocusProvider);
    final values = [
      events,
      assignments,
      exams,
      tasks,
      plans,
      habits,
      logs,
      focus,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          identifier: 'mento_screen_today',
          child: const Text('Today'),
        ),
        actions: [
          MentoIconButton(
            icon: Icons.map_outlined,
            tooltip: 'Study locations',
            semanticIdentifier: 'mento_open_study_locations',
            onPressed: () => context.push('/map'),
          ),
          MentoIconButton(
            icon: Icons.auto_awesome_outlined,
            tooltip: 'Mento assistant',
            semanticIdentifier: 'mento_open_ai_assistant',
            onPressed: () => context.push('/assistant'),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/plan'),
        icon: const Icon(Icons.add),
        label: const Text('Quick add'),
      ),
      body:
          values.any((value) => value.isLoading && !value.hasValue)
              ? const MentoPage(
                child: Column(
                  children: [
                    MentoLoadingSkeleton(height: 160),
                    SizedBox(height: 14),
                    MentoLoadingSkeleton(height: 240),
                  ],
                ),
              )
              : values.any((value) => value.hasError)
              ? MentoErrorState(
                title: 'Today could not be refreshed',
                message:
                    'Your last-known data remains protected. Retry when the connection recovers.',
                onRetry: () => _refresh(ref),
              )
              : _DashboardContent(
                name:
                    (profile.value?.preferredName ?? session.displayName)
                        .trim()
                        .split(' ')
                        .first,
                repository: ref.watch(studentRepositoryProvider),
                events: events.value ?? const [],
                assignments: assignments.value ?? const [],
                exams: exams.value ?? const [],
                tasks: tasks.value ?? const [],
                plans: plans.value ?? const [],
                habits: habits.value ?? const [],
                habitLogs: logs.value ?? const [],
                focusSessions: focus.value ?? const [],
              ),
    );
  }

  static void _refresh(WidgetRef ref) {
    ref.invalidate(dashboardEventsProvider);
    ref.invalidate(dashboardAssignmentsProvider);
    ref.invalidate(dashboardExamsProvider);
    ref.invalidate(dashboardTasksProvider);
    ref.invalidate(dashboardPlansProvider);
    ref.invalidate(dashboardHabitsProvider);
    ref.invalidate(dashboardHabitLogsProvider);
    ref.invalidate(dashboardFocusProvider);
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.name,
    required this.repository,
    required this.events,
    required this.assignments,
    required this.exams,
    required this.tasks,
    required this.plans,
    required this.habits,
    required this.habitLogs,
    required this.focusSessions,
  });

  final String name;
  final StudentRepository repository;
  final List<TimetableEvent> events;
  final List<Assignment> assignments;
  final List<Exam> exams;
  final List<StudyTask> tasks;
  final List<StudyPlan> plans;
  final List<Habit> habits;
  final List<HabitLog> habitLogs;
  final List<FocusSession> focusSessions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final incompleteTasks = tasks.where((item) => !item.isCompleted).toList();
    final todayTaskProgress = calculateTodayTaskProgress(tasks, asOf: now);
    final totalToday = todayTaskProgress.total;
    final completedToday = todayTaskProgress.completed;
    final progress = todayTaskProgress.value;
    final nextEvent =
        events.where((item) => item.endAt.isAfter(now)).firstOrNull;
    final deadline = _nextDeadline(now);
    final recommended = _recommendedTask(now, incompleteTasks);
    final todayBlocks =
        plans
            .expand((plan) => plan.blocks)
            .where(
              (block) =>
                  _sameDay(block.startAt, now) &&
                  block.status != PlanBlockStatus.rejected,
            )
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final completedHabitIds =
        habitLogs
            .where((log) => _sameDay(log.date, now) && log.isCompleted)
            .map((log) => log.habitId)
            .toSet();
    final activityDates = <DateTime>[
      ...tasks.map((item) => item.completedAt).whereType<DateTime>(),
      ...habitLogs.where((item) => item.isCompleted).map((item) => item.date),
      ...focusSessions.map((item) => item.endedAt).whereType<DateTime>(),
    ];
    final streak = StreakCalculator.current(activityDates, asOf: now);
    return MentoPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Good ${_dayPart(now)}, $name',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 5),
                    Text(DateFormat('EEEE, d MMMM').format(now)),
                  ],
                ),
              ),
              if (repository.isDemo)
                const MentoBadge(
                  label: 'Demo · memory only',
                  icon: Icons.science_outlined,
                ),
            ],
          ),
          const SizedBox(height: 22),
          MentoCard(
            highlighted: true,
            child: Row(
              children: [
                MentoProgressRing(
                  value: progress,
                  label: 'Today task progress',
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _progressHeadline(totalToday, completedToday),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 5),
                      Text(
                        totalToday == 0
                            ? 'Your schedule is open. Add one useful task or begin a focus block.'
                            : '$completedToday of $totalToday tasks due today completed.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          MentoResponsiveGrid(
            compactColumns: 1,
            mediumColumns: 2,
            expandedColumns: 3,
            children: [
              _InfoCard(
                icon: Icons.event_outlined,
                title: 'Next event',
                primary: nextEvent?.title ?? 'No upcoming event',
                secondary:
                    nextEvent == null
                        ? 'Add your timetable in Plan.'
                        : '${DateFormat('EEE HH:mm').format(nextEvent.startAt)}${nextEvent.location == null ? '' : ' · ${nextEvent.location}'}',
              ),
              _InfoCard(
                icon: Icons.flag_outlined,
                title: 'Upcoming deadline',
                primary: deadline?.$1 ?? 'No active deadline',
                secondary:
                    deadline == null
                        ? 'Deadlines will be prioritised here.'
                        : DateFormat('EEE d MMM, HH:mm').format(deadline.$2),
              ),
              _InfoCard(
                icon: Icons.local_fire_department_outlined,
                title: 'Current streak',
                primary: '$streak day${streak == 1 ? '' : 's'}',
                secondary:
                    'Rest is never punished; earned progress stays earned.',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const MentoSectionHeader(
            title: 'Next best action',
            subtitle:
                'Calculated from urgency, priority, remaining effort and available activity',
          ),
          const SizedBox(height: 12),
          if (recommended == null)
            MentoEmptyState(
              title:
                  tasks.isNotEmpty
                      ? 'Everything active is complete'
                      : 'Your day is open',
              message:
                  tasks.isNotEmpty
                      ? 'Take the win, review tomorrow, or choose a restorative break.'
                      : 'Add a task or deadline to receive a grounded recommendation.',
              icon:
                  tasks.isNotEmpty
                      ? Icons.celebration_outlined
                      : Icons.auto_awesome_outlined,
              actionLabel: 'Open plan',
              onAction: () => context.go('/plan'),
            )
          else
            MentoCard(
              highlighted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    recommended.$1.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(recommended.$2),
                  const SizedBox(height: 14),
                  MentoButton(
                    label: 'Start focus session',
                    icon: Icons.play_arrow,
                    expand: false,
                    onPressed: () => context.go('/focus'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          const MentoSectionHeader(title: 'Today’s plan'),
          const SizedBox(height: 10),
          if (todayBlocks.isEmpty)
            MentoCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'No accepted study blocks today. ${AppConfig.hasWorker ? 'Generate or build a plan when useful.' : 'The deterministic planner remains available without AI.'}',
                  ),
                  const SizedBox(height: 12),
                  MentoButton(
                    label: 'Build a study plan',
                    semanticIdentifier: 'mento_open_ai_planner',
                    icon: Icons.auto_awesome_outlined,
                    expand: false,
                    onPressed: () => context.push('/planner'),
                  ),
                ],
              ),
            )
          else
            for (final block in todayBlocks.take(6))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MentoCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      DateFormat('HH:mm').format(block.startAt),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    title: Text(block.objective),
                    subtitle: Text(
                      '${block.recommendedMethod} · ${block.breakMinutes} min break',
                    ),
                    trailing: MentoBadge(
                      label:
                          block.source == PlanSource.artificialIntelligence
                              ? 'AI'
                              : 'Offline',
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MentoCard(
                onTap: () => context.push('/wellbeing'),
                semanticLabel:
                    'Habits: ${completedHabitIds.length} of ${habits.length} complete today',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.spa_outlined),
                  title: const Text('Supportive habits'),
                  subtitle: Text(
                    '${completedHabitIds.length} of ${habits.length} checked off today',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
              ),
              const SizedBox(height: 16),
              MentoCard(
                onTap: () => context.push('/assistant'),
                semanticLabel: 'Open Mento AI assistant',
                child: const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.auto_awesome_outlined),
                  title: Text('Smart summary'),
                  subtitle: Text(
                    'Ask for a balanced routine, deadline explanation or replanning help.',
                  ),
                  trailing: Icon(Icons.chevron_right),
                ),
              ),
            ],
          ),
          const SizedBox(height: 90),
        ],
      ),
    );
  }

  (String, DateTime)? _nextDeadline(DateTime now) {
    final items = <(String, DateTime)>[
      ...assignments
          .where((item) => item.status != WorkStatus.completed)
          .map((item) => (item.title, item.dueAt)),
      ...exams.map((item) => (item.title, item.startAt)),
      ...tasks
          .where((item) => !item.isCompleted)
          .map((item) => (item.title, item.dueAt)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    return items.where((item) => item.$2.isAfter(now)).firstOrNull;
  }

  (StudyTask, String)? _recommendedTask(
    DateTime now,
    List<StudyTask> candidates,
  ) {
    if (candidates.isEmpty) return null;
    final scored = [
      for (final task in candidates)
        (
          task,
          PriorityScorer.calculate(
            deadline: task.dueAt,
            priority: task.priority,
            remainingMinutes: task.estimatedMinutes,
            now: now,
            wasMissed:
                task.needsRescheduling || task.status == WorkStatus.missed,
          ),
        ),
    ]..sort((a, b) => b.$2.total.compareTo(a.$2.total));
    final item = scored.first;
    final days = item.$1.dueAt.difference(now).inDays;
    final reason =
        days < 0
            ? 'This is overdue, so it is prioritised at the earliest safe opportunity.'
            : days <= 2
            ? 'The deadline is close and the task is ${item.$1.priority.name} priority.'
            : 'This currently has the strongest balance of priority, workload and deadline proximity.';
    return (item.$1, reason);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.primary,
    required this.secondary,
  });
  final IconData icon;
  final String title;
  final String primary;
  final String secondary;

  @override
  Widget build(BuildContext context) => MentoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 5),
        Text(primary, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(secondary, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

String _dayPart(DateTime now) =>
    now.hour < 12
        ? 'morning'
        : now.hour < 18
        ? 'afternoon'
        : 'evening';
String _progressHeadline(int total, int completed) {
  if (total == 0) return 'A calm start is still progress';
  if (completed == total) return 'Today’s essentials are complete';
  if (completed == 0) return 'Choose one clear next step';
  return 'You are moving steadily';
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

final class TodayTaskProgress {
  const TodayTaskProgress({required this.total, required this.completed});

  final int total;
  final int completed;

  double get value => total == 0 ? 0 : completed / total;
}

TodayTaskProgress calculateTodayTaskProgress(
  Iterable<StudyTask> tasks, {
  required DateTime asOf,
}) {
  var total = 0;
  var completed = 0;
  for (final task in tasks) {
    if (!_sameDay(task.dueAt, asOf)) continue;
    total++;
    if (task.isCompleted) completed++;
  }
  return TodayTaskProgress(total: total, completed: completed);
}
