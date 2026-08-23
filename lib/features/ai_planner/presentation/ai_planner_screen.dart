// Lets students review, select, edit, accept, or reject generated plan blocks.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_controls.dart';
import '../../../core/widgets/mento_states.dart';
import '../../../data/models/models.dart';
import '../application/ai_planner_controller.dart';
import '../application/ai_planner_service.dart';

class AiPlannerScreen extends ConsumerWidget {
  const AiPlannerScreen({
    required this.input,
    required this.onAccept,
    super.key,
  });

  final StudyPlannerInput input;
  final Future<void> Function(StudyPlan plan) onAccept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(aiPlannerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          identifier: 'mento_screen_ai_planner',
          child: const Text('Smart study plan'),
        ),
        actions: [
          if (state.result != null)
            TextButton(
              onPressed:
                  state.generating
                      ? null
                      : () =>
                          ref.read(aiPlannerProvider.notifier).generate(input),
              child: const Text('Regenerate'),
            ),
        ],
      ),
      body: MentoPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MentoCard(
              highlighted: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'A proposal, never an overwrite',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Mento considers deadlines, workload, commitments, available time and breaks. Review and select every block before saving.',
                  ),
                  const SizedBox(height: 16),
                  if (state.generating) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                    MentoButton(
                      label: 'Cancel generation',
                      variant: MentoButtonVariant.outlined,
                      onPressed:
                          () => ref.read(aiPlannerProvider.notifier).cancel(),
                    ),
                  ] else
                    MentoButton(
                      label:
                          state.result == null
                              ? 'Generate plan'
                              : 'Generate another plan',
                      semanticIdentifier: 'mento_ai_generate_plan',
                      icon: Icons.auto_awesome,
                      variant: MentoButtonVariant.gradient,
                      onPressed:
                          () => ref
                              .read(aiPlannerProvider.notifier)
                              .generate(input),
                    ),
                ],
              ),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Semantics(
                identifier: 'mento_ai_planner_error',
                container: true,
                child: MentoErrorState(
                  title: 'Planning paused',
                  message: state.error!,
                ),
              ),
            ],
            if (state.result case final result?) ...[
              const SizedBox(height: 20),
              _ResultBanner(result: result),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '${state.selectedBlockIds.length} of ${result.plan.blocks.length} selected',
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        () => ref.read(aiPlannerProvider.notifier).selectAll(),
                    child: const Text('Select all'),
                  ),
                  TextButton(
                    onPressed:
                        () => ref.read(aiPlannerProvider.notifier).rejectAll(),
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final block in result.plan.blocks) ...[
                _PlanBlockCard(
                  block: block,
                  selected: state.selectedBlockIds.contains(block.id),
                  onSelected:
                      () => ref
                          .read(aiPlannerProvider.notifier)
                          .toggleBlock(block.id),
                  onEdit: () => _editBlock(context, ref, block),
                ),
                const SizedBox(height: 12),
              ],
              if (result.plan.unplannedMinutes.isNotEmpty)
                MentoCard(
                  child: Text(
                    'Not enough conflict-free time was available for ${result.plan.unplannedMinutes.length} item(s). Increase availability or reduce the date range workload.',
                  ),
                ),
              const SizedBox(height: 16),
              MentoButton(
                label: 'Accept selected blocks',
                icon: Icons.check_circle_outline,
                onPressed:
                    state.selectedBlockIds.isEmpty
                        ? null
                        : () async {
                          final plan =
                              ref
                                  .read(aiPlannerProvider.notifier)
                                  .acceptedSelection();
                          if (plan == null) return;
                          try {
                            await onAccept(plan);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Selected study blocks saved. Your timetable was not changed.',
                                  ),
                                ),
                              );
                              Navigator.maybePop(context);
                            }
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'The plan could not be saved. Review it and retry.',
                                  ),
                                ),
                              );
                            }
                          }
                        },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _editBlock(
    BuildContext context,
    WidgetRef ref,
    PlanBlock block,
  ) async {
    var start = block.startAt;
    var end = block.endAt;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setModalState) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Edit study block',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text('Starts'),
                          subtitle: Text(
                            DateFormat('EEE d MMM, HH:mm').format(start),
                          ),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(start),
                            );
                            if (time != null) {
                              setModalState(
                                () =>
                                    start = DateTime(
                                      start.year,
                                      start.month,
                                      start.day,
                                      time.hour,
                                      time.minute,
                                    ),
                              );
                            }
                          },
                        ),
                        ListTile(
                          title: const Text('Ends'),
                          subtitle: Text(
                            DateFormat('EEE d MMM, HH:mm').format(end),
                          ),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(end),
                            );
                            if (time != null) {
                              setModalState(
                                () =>
                                    end = DateTime(
                                      end.year,
                                      end.month,
                                      end.day,
                                      time.hour,
                                      time.minute,
                                    ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        MentoButton(
                          label: 'Apply edit',
                          onPressed:
                              end.isAfter(start)
                                  ? () => Navigator.pop(context, true)
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ),
          ),
    );
    if (saved == true) {
      ref
          .read(aiPlannerProvider.notifier)
          .updateBlock(block.id, startAt: start, endAt: end);
    }
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({required this.result});
  final PlanGenerationResult result;

  @override
  Widget build(BuildContext context) => Semantics(
    identifier: 'mento_ai_plan_result',
    container: true,
    child: MentoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            result.usedFallback
                ? Icons.offline_bolt_outlined
                : Icons.verified_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.usedFallback
                      ? 'Deterministic offline plan'
                      : 'Validated AI plan',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(result.message),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _PlanBlockCard extends StatelessWidget {
  const _PlanBlockCard({
    required this.block,
    required this.selected,
    required this.onSelected,
    required this.onEdit,
  });
  final PlanBlock block;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => MentoCard(
    highlighted: selected,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(value: selected, onChanged: (_) => onSelected()),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                block.objective,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('EEE d MMM · HH:mm–HH:mm')
                    .format(block.startAt)
                    .replaceFirst(
                      DateFormat('HH:mm').format(block.startAt),
                      '${DateFormat('HH:mm').format(block.startAt)}–${DateFormat('HH:mm').format(block.endAt)}',
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${block.recommendedMethod} · ${block.breakMinutes} min break',
              ),
              const SizedBox(height: 6),
              Text('Why: ${block.reason}'),
            ],
          ),
        ),
        MentoIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit ${block.objective}',
          onPressed: onEdit,
        ),
      ],
    ),
  );
}
