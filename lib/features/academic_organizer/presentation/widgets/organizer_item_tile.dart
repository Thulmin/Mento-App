// Renders reusable academic item rows with matching status and action controls.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/logic/logic.dart';
import '../../../../core/widgets/mento_card.dart';
import '../../../../data/models/models.dart';
import '../organizer_data.dart';

class OrganizerItemTile extends StatelessWidget {
  const OrganizerItemTile({
    required this.item,
    required this.module,
    required this.onEdit,
    required this.onDelete,
    this.onToggleTask,
    this.compact = false,
    super.key,
  });

  final OrganizerTimelineItem item;
  final Module? module;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleTask;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = _moduleColor(module, Theme.of(context).colorScheme.primary);
    return MentoCard(
      padding: EdgeInsets.all(compact ? 12 : 16),
      semanticLabel:
          '${_kindLabel(item.kind)}: ${item.title}, ${DateFormat('EEE d MMM HH:mm').format(item.when)}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.kind == OrganizerItemKind.task && onToggleTask != null)
            Semantics(
              label:
                  item.isCompleted
                      ? 'Mark task incomplete'
                      : 'Mark task complete',
              child: Checkbox(
                value: item.isCompleted,
                onChanged: (_) => onToggleTask!(),
              ),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(_kindIcon(item.kind), color: accent),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration:
                            item.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                      ),
                    ),
                    if (module != null)
                      Text(
                        module!.code,
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _timeLabel(item),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    item.subtitle!,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (item.entity case final Assignment assignment) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value:
                        AssignmentProgressCalculator.calculate(
                          assignment,
                        ).fraction,
                    semanticsLabel: 'Assignment progress',
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<_ItemAction>(
            tooltip: 'Actions for ${item.title}',
            onSelected: (action) {
              if (action == _ItemAction.edit) onEdit();
              if (action == _ItemAction.delete) onDelete();
            },
            itemBuilder:
                (_) => const [
                  PopupMenuItem(value: _ItemAction.edit, child: Text('Edit')),
                  PopupMenuItem(
                    value: _ItemAction.delete,
                    child: Text('Delete'),
                  ),
                ],
          ),
        ],
      ),
    );
  }
}

enum _ItemAction { edit, delete }

String _timeLabel(OrganizerTimelineItem item) {
  final start = DateFormat('EEE, d MMM · HH:mm').format(item.when);
  final end = item.end;
  return end == null ? start : '$start–${DateFormat('HH:mm').format(end)}';
}

String _kindLabel(OrganizerItemKind kind) => switch (kind) {
  OrganizerItemKind.event => 'Timetable event',
  OrganizerItemKind.assignment => 'Assignment',
  OrganizerItemKind.exam => 'Examination',
  OrganizerItemKind.task => 'Study task',
};

IconData _kindIcon(OrganizerItemKind kind) => switch (kind) {
  OrganizerItemKind.event => Icons.event_outlined,
  OrganizerItemKind.assignment => Icons.assignment_outlined,
  OrganizerItemKind.exam => Icons.fact_check_outlined,
  OrganizerItemKind.task => Icons.task_alt_outlined,
};

Color _moduleColor(Module? module, Color fallback) {
  final raw = module?.colorHex.replaceFirst('#', '');
  final value = raw == null ? null : int.tryParse(raw, radix: 16);
  return value == null ? fallback : Color(0xFF000000 | value);
}
