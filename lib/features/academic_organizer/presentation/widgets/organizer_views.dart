// Builds the organiser's agenda, calendar, deadline, and module-specific views.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/mento_card.dart';
import '../../../../core/widgets/mento_states.dart';
import '../../application/academic_organizer_providers.dart';
import '../organizer_data.dart';
import 'organizer_item_tile.dart';

typedef OrganizerItemCallback = void Function(OrganizerTimelineItem item);

class OrganizerTimelineView extends StatelessWidget {
  const OrganizerTimelineView({
    required this.data,
    required this.filter,
    required this.start,
    required this.end,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleTask,
    this.deadlinesOnly = false,
    this.emptyTitle = 'Nothing scheduled',
    this.emptyMessage = 'Use Quick add to create an academic item.',
    super.key,
  });

  final AcademicOrganizerData data;
  final AcademicOrganizerFilter filter;
  final DateTime start;
  final DateTime end;
  final OrganizerItemCallback onEdit;
  final OrganizerItemCallback onDelete;
  final OrganizerItemCallback onToggleTask;
  final bool deadlinesOnly;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final items = data.timeline(
      start,
      end,
      filter,
      deadlinesOnly: deadlinesOnly,
    );
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: MentoEmptyState(
          title: emptyTitle,
          message: emptyMessage,
          icon:
              deadlinesOnly
                  ? Icons.assignment_turned_in_outlined
                  : Icons.event_available,
        ),
      );
    }
    DateTime? previousDay;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items) ...[
          if (previousDay == null || !_sameDay(previousDay!, item.when))
            Builder(
              builder: (context) {
                previousDay = item.when;
                return Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(
                    DateFormat('EEEE, d MMMM').format(item.when),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OrganizerItemTile(
              item: item,
              module: data.module(item.moduleId),
              onEdit: () => onEdit(item),
              onDelete: () => onDelete(item),
              onToggleTask:
                  item.kind == OrganizerItemKind.task
                      ? () => onToggleTask(item)
                      : null,
            ),
          ),
        ],
      ],
    );
  }
}

class OrganizerWeekView extends StatelessWidget {
  const OrganizerWeekView({
    required this.data,
    required this.filter,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleTask,
    required this.onSelectDay,
    super.key,
  });

  final AcademicOrganizerData data;
  final AcademicOrganizerFilter filter;
  final OrganizerItemCallback onEdit;
  final OrganizerItemCallback onDelete;
  final OrganizerItemCallback onToggleTask;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final weekStart = filter.selectedDate.subtract(
      Duration(days: filter.selectedDate.weekday - DateTime.monday),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 680
                ? 2
                : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var offset = 0; offset < 7; offset++)
              SizedBox(
                width: width,
                child: _DayCard(
                  day: weekStart.add(Duration(days: offset)),
                  data: data,
                  filter: filter,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onToggleTask: onToggleTask,
                  onSelect: onSelectDay,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.data,
    required this.filter,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleTask,
    required this.onSelect,
  });

  final DateTime day;
  final AcademicOrganizerData data;
  final AcademicOrganizerFilter filter;
  final OrganizerItemCallback onEdit;
  final OrganizerItemCallback onDelete;
  final OrganizerItemCallback onToggleTask;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = data.timeline(day, day.add(const Duration(days: 1)), filter);
    return MentoCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            onPressed: () => onSelect(day),
            child: Text(DateFormat('EEE d MMM').format(day)),
          ),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Open day', textAlign: TextAlign.center),
            )
          else
            for (final item in items.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: OrganizerItemTile(
                  item: item,
                  module: data.module(item.moduleId),
                  compact: true,
                  onEdit: () => onEdit(item),
                  onDelete: () => onDelete(item),
                  onToggleTask:
                      item.kind == OrganizerItemKind.task
                          ? () => onToggleTask(item)
                          : null,
                ),
              ),
          if (items.length > 5)
            TextButton(
              onPressed: () => onSelect(day),
              child: Text('${items.length - 5} more'),
            ),
        ],
      ),
    );
  }
}

class OrganizerMonthView extends StatelessWidget {
  const OrganizerMonthView({
    required this.data,
    required this.filter,
    required this.onSelectDay,
    super.key,
  });

  final AcademicOrganizerData data;
  final AcademicOrganizerFilter filter;
  final ValueChanged<DateTime> onSelectDay;

  @override
  Widget build(BuildContext context) {
    final month = DateTime(filter.selectedDate.year, filter.selectedDate.month);
    final counts = data.monthCounts(month, filter);
    final firstWeekdayOffset = month.weekday - DateTime.monday;
    final days = DateTime(month.year, month.month + 1, 0).day;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          DateFormat('MMMM yyyy').format(month),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.9,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: firstWeekdayOffset + days,
          itemBuilder: (context, index) {
            if (index < firstWeekdayOffset) return const SizedBox.shrink();
            final dayNumber = index - firstWeekdayOffset + 1;
            final day = DateTime(month.year, month.month, dayNumber);
            final count = counts[day] ?? 0;
            final selected = _sameDay(day, filter.selectedDate);
            return Semantics(
              label:
                  '$dayNumber ${DateFormat('MMMM').format(month)}, $count items',
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelectDay(day),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color:
                        selected
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        Text('$dayNumber'),
                        if (count > 0) ...[
                          const Spacer(),
                          CircleAvatar(
                            radius: 10,
                            child: Text(
                              '$count',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
