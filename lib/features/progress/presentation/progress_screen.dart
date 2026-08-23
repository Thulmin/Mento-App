// Presents points, streaks, focus totals, achievements, and topic mastery.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../app/theme/mento_colors.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_controls.dart';
import '../../../core/widgets/mento_states.dart';
import '../../../data/models/models.dart';
import '../application/progress_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(progressTasksProvider);
    final assignments = ref.watch(progressAssignmentsProvider);
    final focus = ref.watch(progressFocusProvider);
    final habits = ref.watch(progressHabitLogsProvider);
    final achievements = ref.watch(progressAchievementsProvider);
    final mastery = ref.watch(progressMasteryProvider);
    final modules = ref.watch(progressModulesProvider);
    final values = [
      tasks,
      assignments,
      focus,
      habits,
      achievements,
      mastery,
      modules,
    ];
    if (values.any((value) => value.isLoading)) {
      return Scaffold(
        appBar: AppBar(
          title: const MentoScreenTitle(
            title: 'Progress',
            semanticIdentifier: 'mento_screen_progress',
          ),
        ),
        body: const SafeArea(
          child: MentoPage(
            child: Column(
              children: [
                MentoLoadingSkeleton(height: 160),
                SizedBox(height: 16),
                MentoLoadingSkeleton(height: 300),
              ],
            ),
          ),
        ),
      );
    }
    if (values.any((value) => value.hasError)) {
      return Scaffold(
        appBar: AppBar(
          title: const MentoScreenTitle(
            title: 'Progress',
            semanticIdentifier: 'mento_screen_progress',
          ),
        ),
        body: MentoErrorState(
          title: 'Progress is temporarily unavailable',
          message:
              'Your activity remains saved. Retry when your connection recovers.',
          onRetry: () {
            ref.invalidate(progressTasksProvider);
            ref.invalidate(progressAssignmentsProvider);
            ref.invalidate(progressFocusProvider);
            ref.invalidate(progressHabitLogsProvider);
            ref.invalidate(progressAchievementsProvider);
            ref.invalidate(progressMasteryProvider);
          },
        ),
      );
    }
    final summary = calculateProgressSummary(
      tasks: tasks.value!,
      assignments: assignments.value!,
      focusSessions: focus.value!,
      habitLogs: habits.value!,
      mastery: mastery.value!,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(achievementSyncProvider.notifier)
          .sync(summary.badges, achievements.value!);
    });

    final focusByModule = <String, int>{};
    for (final session in focus.value!) {
      if (session.state == FocusSessionState.completed &&
          session.moduleId != null) {
        focusByModule[session.moduleId!] =
            (focusByModule[session.moduleId!] ?? 0) +
            session.accumulatedActiveSeconds ~/ 60;
      }
    }
    final moduleNames = {
      for (final module in modules.value!) module.id: module.name,
    };
    return Scaffold(
      appBar: AppBar(
        title: const MentoScreenTitle(
          title: 'Progress',
          semanticIdentifier: 'mento_screen_progress',
        ),
        actions: [
          MentoIconButton(
            icon: Icons.spa_outlined,
            tooltip: 'Habits and wellbeing',
            onPressed: () => context.push('/wellbeing'),
          ),
        ],
      ),
      body: MentoPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LevelCard(summary: summary),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = context.isCompact;
                final spacing = 12.0;
                if (isCompact) {
                  final cardWidth = (constraints.maxWidth - spacing) / 2;
                  return Column(
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: MentoStatCard(
                                label: 'Tasks done',
                                value: '${summary.completedTasks}',
                                icon: Icons.task_alt,
                              ),
                            ),
                            SizedBox(width: spacing),
                            SizedBox(
                              width: cardWidth,
                              child: MentoStatCard(
                                label: 'Focus this week',
                                value: '${summary.weekFocusMinutes} min',
                                icon: Icons.timer_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: spacing),
                      IntrinsicHeight(
                        child: Row(
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: MentoStatCard(
                                label: 'Current streak',
                                value: '${summary.currentStreak} days',
                                icon: Icons.local_fire_department_outlined,
                                supportingText:
                                    'Personal best ${summary.longestStreak}',
                              ),
                            ),
                            SizedBox(width: spacing),
                            SizedBox(
                              width: cardWidth,
                              child: MentoStatCard(
                                label: 'Mastered topics',
                                value: '${summary.masteredTopics}',
                                icon: Icons.school_outlined,
                                supportingText: 'Not a formal grade',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  final cardWidth = (constraints.maxWidth - spacing * 3) / 4;
                  return IntrinsicHeight(
                    child: Row(
                      children: [
                        SizedBox(
                          width: cardWidth,
                          child: MentoStatCard(
                            label: 'Tasks done',
                            value: '${summary.completedTasks}',
                            icon: Icons.task_alt,
                          ),
                        ),
                        SizedBox(width: spacing),
                        SizedBox(
                          width: cardWidth,
                          child: MentoStatCard(
                            label: 'Focus this week',
                            value: '${summary.weekFocusMinutes} min',
                            icon: Icons.timer_outlined,
                          ),
                        ),
                        SizedBox(width: spacing),
                        SizedBox(
                          width: cardWidth,
                          child: MentoStatCard(
                            label: 'Current streak',
                            value: '${summary.currentStreak} days',
                            icon: Icons.local_fire_department_outlined,
                            supportingText:
                                'Personal best ${summary.longestStreak}',
                          ),
                        ),
                        SizedBox(width: spacing),
                        SizedBox(
                          width: cardWidth,
                          child: MentoStatCard(
                            label: 'Mastered topics',
                            value: '${summary.masteredTopics}',
                            icon: Icons.school_outlined,
                            supportingText: 'Not a formal grade',
                          ),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            const MentoSectionHeader(
              title: 'Achievements',
              subtitle:
                  'Earned from real task, focus, habit and mastery activity',
            ),
            const SizedBox(height: 12),
            if (summary.badges.isEmpty)
              const MentoEmptyState(
                title: 'Your first milestone is close',
                message:
                    'Complete a task or focus session. Rest days never remove earned achievements.',
                icon: Icons.emoji_events_outlined,
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final badge in summary.badges)
                    MentoBadge(
                      label: _badgeLabel(badge),
                      icon: Icons.emoji_events_outlined,
                      color: context.mentoColors.warning,
                    ),
                ],
              ),
            const SizedBox(height: 24),
            const MentoSectionHeader(
              title: 'Focus by module',
              subtitle:
                  'Text summary is provided for accessible chart interpretation',
            ),
            const SizedBox(height: 12),
            MentoCard(
              child:
                  focusByModule.isEmpty
                      ? const Text('No module-linked focus sessions yet.')
                      : Column(
                        children: [
                          for (final entry in focusByModule.entries)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      moduleNames[entry.key] ??
                                          'Archived module',
                                    ),
                                  ),
                                  Text(
                                    '${entry.value} min',
                                    style:
                                        Theme.of(context).textTheme.labelLarge,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
            ),
            const SizedBox(height: 24),
            const MentoSectionHeader(
              title: 'Topic mastery',
              subtitle:
                  'Self-organisation evidence, never a formal academic grade',
            ),
            const SizedBox(height: 12),
            if (mastery.value!.isEmpty)
              const MentoEmptyState(
                title: 'No topic evidence yet',
                message:
                    'Add topics and record study activity to see transparent mastery indicators.',
                icon: Icons.auto_graph_outlined,
              )
            else
              for (final record in mastery.value!.take(20))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MentoCard(
                    child: Row(
                      children: [
                        MentoProgressRing(
                          value: record.mastery,
                          size: 64,
                          strokeWidth: 7,
                          label:
                              'Topic mastery ${_masteryLabel(record.mastery)}',
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _masteryLabel(record.mastery),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                '${moduleNames[record.moduleId] ?? 'Module'} · ${record.studyMinutes} study min · ${record.completedTasks} tasks',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 18),
            MentoButton(
              label: 'Open habits & wellbeing',
              icon: Icons.spa_outlined,
              variant: MentoButtonVariant.outlined,
              onPressed: () => context.push('/wellbeing'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.summary});
  final ProgressSummary summary;

  @override
  Widget build(BuildContext context) => MentoCard(
    highlighted: true,
    padding: const EdgeInsets.all(22),
    child: Row(
      children: [
        MentoProgressRing(
          value: summary.levelProgress,
          size: 92,
          label: 'Level ${summary.level} progress',
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Level ${summary.level}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(
                '${summary.points} points · ${summary.nextLevelAt - summary.points} to next level',
              ),
              const SizedBox(height: 8),
              const Text(
                'Points celebrate useful activity; they never penalise rest or missed days.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

String _masteryLabel(double value) {
  if (value >= 0.8) return 'Mastered';
  if (value >= 0.6) return 'Confident';
  if (value >= 0.4) return 'Practising';
  if (value > 0) return 'Learning';
  return 'Not started';
}

String _badgeLabel(AchievementType value) => switch (value) {
  AchievementType.firstTask => 'First step',
  AchievementType.firstFocusSession => 'Focused beginning',
  AchievementType.focusedHour => 'Deep work',
  AchievementType.focusedTenHours => 'Focus craft',
  AchievementType.threeDayStreak => 'Steady start',
  AchievementType.sevenDayStreak => 'Consistency builder',
  AchievementType.thirtyDayStreak => 'Sustainable month',
  AchievementType.assignmentCompleted => 'Deadline defender',
  AchievementType.topicMastered => 'Module mastery',
  AchievementType.habitBuilder => 'Balanced week',
};
