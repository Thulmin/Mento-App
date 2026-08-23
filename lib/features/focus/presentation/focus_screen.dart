// Presents focus setup, the active timestamp-based timer, and session history.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_controls.dart';
import '../../../core/widgets/mento_states.dart';
import '../../../data/models/models.dart';
import '../application/focus_timer_controller.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  final _goal = TextEditingController();
  int _minutes = 25;
  String? _moduleId;

  @override
  void dispose() {
    _goal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(focusTimerProvider);
    final modules = ref.watch(focusModulesProvider).value ?? const <Module>[];
    final completed =
        timer.history
            .where((item) => item.state == FocusSessionState.completed)
            .toList();
    final now = DateTime.now();
    final todayMinutes = completed
        .where((item) => _sameDay(item.startedAt, now))
        .fold<int>(0, (sum, item) => sum + item.accumulatedActiveSeconds ~/ 60);
    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final weekMinutes = completed
        .where((item) => !item.startedAt.isBefore(weekStart))
        .fold<int>(0, (sum, item) => sum + item.accumulatedActiveSeconds ~/ 60);

    return Scaffold(
      appBar: AppBar(
        title: const MentoScreenTitle(
          title: 'Focus',
          semanticIdentifier: 'mento_screen_focus',
        ),
      ),
      body: MentoPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (timer.error != null) ...[
              Text(
                timer.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 12),
            ],
            if (timer.loading)
              const MentoLoadingSkeleton(height: 360)
            else if (timer.active case final active?)
              _ActiveTimer(
                session: active,
                remaining: timer.remaining,
                progress: timer.progress,
                saving: timer.saving,
              )
            else
              _StartPanel(
                goal: _goal,
                minutes: _minutes,
                moduleId: _moduleId,
                modules: modules,
                onMinutes: (value) => setState(() => _minutes = value),
                onModule: (value) => setState(() => _moduleId = value),
                onStart:
                    () => ref
                        .read(focusTimerProvider.notifier)
                        .start(
                          minutes: _minutes,
                          goal: _goal.text,
                          moduleId: _moduleId,
                        ),
              ),
            const SizedBox(height: 20),
            MentoResponsiveGrid(
              compactColumns: 2,
              mediumColumns: 3,
              expandedColumns: 3,
              children: [
                MentoStatCard(
                  label: 'Today',
                  value: '$todayMinutes min',
                  icon: Icons.today_outlined,
                ),
                MentoStatCard(
                  label: 'This week',
                  value: '$weekMinutes min',
                  icon: Icons.date_range_outlined,
                ),
                MentoStatCard(
                  label: 'Completion',
                  value:
                      timer.history.isEmpty
                          ? '0%'
                          : '${(completed.length / timer.history.length * 100).round()}%',
                  icon: Icons.check_circle_outline,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const MentoSectionHeader(
              title: 'Recent sessions',
              subtitle:
                  'Elapsed time is calculated from persisted timestamps, including after interruptions.',
            ),
            const SizedBox(height: 12),
            if (timer.history.isEmpty)
              const MentoEmptyState(
                title: 'No focus history yet',
                message: 'Complete a session to start a private focus record.',
                icon: Icons.timer_outlined,
              )
            else
              for (final session in timer.history.take(12))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: MentoCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        session.state == FocusSessionState.completed
                            ? Icons.check_circle_outline
                            : Icons.stop_circle_outlined,
                      ),
                      title: Text(session.goal),
                      subtitle: Text(
                        '${DateFormat('EEE d MMM, HH:mm').format(session.startedAt)} · ${session.accumulatedActiveSeconds ~/ 60} focused min · ${session.interruptionCount} interruption(s)',
                      ),
                      trailing:
                          session.isBreak
                              ? const MentoBadge(label: 'Break')
                              : null,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

class _StartPanel extends StatelessWidget {
  const _StartPanel({
    required this.goal,
    required this.minutes,
    required this.moduleId,
    required this.modules,
    required this.onMinutes,
    required this.onModule,
    required this.onStart,
  });

  final TextEditingController goal;
  final int minutes;
  final String? moduleId;
  final List<Module> modules;
  final ValueChanged<int> onMinutes;
  final ValueChanged<String?> onModule;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return MentoCard(
      highlighted: true,
      padding: EdgeInsets.all(context.isCompact ? 18 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Protect one block of attention',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a clear goal. The timer remains accurate when Mento is backgrounded.',
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final concise = constraints.maxWidth < 520;
              return SegmentedButton<int>(
                key: const Key('focus-duration-selector'),
                expandedInsets: EdgeInsets.zero,
                showSelectedIcon: !concise,
                segments:
                    concise
                        ? [
                          ButtonSegment(
                            value: 25,
                            label: Semantics(
                              label: 'Pomodoro, 25 minutes',
                              excludeSemantics: true,
                              child: Text('25m'),
                            ),
                          ),
                          ButtonSegment(
                            value: 50,
                            label: Semantics(
                              label: 'Deep work, 50 minutes',
                              excludeSemantics: true,
                              child: Text('50m'),
                            ),
                          ),
                          ButtonSegment(
                            value: 90,
                            label: Semantics(
                              label: 'Long session, 90 minutes',
                              excludeSemantics: true,
                              child: Text('90m'),
                            ),
                          ),
                        ]
                        : const [
                          ButtonSegment(
                            value: 25,
                            label: Text('Pomodoro'),
                            icon: Icon(Icons.bolt),
                          ),
                          ButtonSegment(
                            value: 50,
                            label: Text('Deep work'),
                            icon: Icon(Icons.psychology_outlined),
                          ),
                          ButtonSegment(
                            value: 90,
                            label: Text('Long'),
                            icon: Icon(Icons.landscape_outlined),
                          ),
                        ],
                selected: {minutes},
                onSelectionChanged: (values) => onMinutes(values.first),
              );
            },
          ),
          const SizedBox(height: 16),
          MentoTextField(
            label: 'Session goal',
            controller: goal,
            hint: 'Draft the threat model',
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: const Key('focus-module-dropdown'),
            isExpanded: true,
            value: moduleId,
            decoration: const InputDecoration(labelText: 'Module (optional)'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'No module',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final module in modules)
                DropdownMenuItem<String?>(
                  value: module.id,
                  child: Tooltip(
                    message: module.name,
                    child: Text(
                      module.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
            onChanged: onModule,
          ),
          const SizedBox(height: 18),
          MentoButton(
            label: 'Start $minutes-minute session',
            icon: Icons.play_arrow,
            variant: MentoButtonVariant.gradient,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

class _ActiveTimer extends ConsumerWidget {
  const _ActiveTimer({
    required this.session,
    required this.remaining,
    required this.progress,
    required this.saving,
  });
  final FocusSession session;
  final Duration remaining;
  final double progress;
  final bool saving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paused = session.state == FocusSessionState.paused;
    final minutes = remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return MentoCard(
      highlighted: true,
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          MentoBadge(
            label:
                session.isBreak
                    ? 'Recovery break'
                    : paused
                    ? 'Paused'
                    : 'Focusing',
            icon:
                session.isBreak
                    ? Icons.self_improvement
                    : Icons.center_focus_strong,
          ),
          const SizedBox(height: 20),
          SizedBox.square(
            dimension: 210,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(value: progress, strokeWidth: 12),
                Center(
                  child: Semantics(
                    liveRegion: true,
                    label:
                        '${remaining.inMinutes} minutes and ${remaining.inSeconds.remainder(60)} seconds remaining',
                    child: ExcludeSemantics(
                      child: Text(
                        '$minutes:$seconds',
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            session.goal,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 22),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              MentoButton(
                label: paused ? 'Resume' : 'Pause',
                icon: paused ? Icons.play_arrow : Icons.pause,
                expand: false,
                loading: saving,
                onPressed:
                    paused
                        ? () => ref.read(focusTimerProvider.notifier).resume()
                        : () => ref.read(focusTimerProvider.notifier).pause(),
              ),
              MentoButton(
                label: 'Complete',
                icon: Icons.check,
                expand: false,
                variant: MentoButtonVariant.outlined,
                onPressed:
                    saving
                        ? null
                        : () =>
                            ref.read(focusTimerProvider.notifier).complete(),
              ),
              MentoButton(
                label: 'Stop',
                icon: Icons.stop,
                expand: false,
                variant: MentoButtonVariant.text,
                onPressed:
                    saving
                        ? null
                        : () => ref.read(focusTimerProvider.notifier).stop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
