// Turns raw academic records into sorted and filtered organiser view data.

import '../../../core/logic/logic.dart';
import '../../../data/models/models.dart';
import '../application/academic_organizer_providers.dart';

enum OrganizerItemKind { event, assignment, exam, task }

final class OrganizerTimelineItem {
  const OrganizerTimelineItem({
    required this.kind,
    required this.id,
    required this.title,
    required this.when,
    required this.moduleId,
    required this.priorityWeight,
    required this.isCompleted,
    required this.entity,
    this.end,
    this.subtitle,
  });

  final OrganizerItemKind kind;
  final String id;
  final String title;
  final DateTime when;
  final DateTime? end;
  final String? moduleId;
  final int priorityWeight;
  final bool isCompleted;
  final Object entity;
  final String? subtitle;
}

final class AcademicOrganizerData {
  const AcademicOrganizerData({
    required this.modules,
    required this.topics,
    required this.events,
    required this.assignments,
    required this.exams,
    required this.tasks,
  });

  final List<Module> modules;
  final List<Topic> topics;
  final List<TimetableEvent> events;
  final List<Assignment> assignments;
  final List<Exam> exams;
  final List<StudyTask> tasks;

  Module? module(String? id) {
    if (id == null) return null;
    for (final value in modules) {
      if (value.id == id) return value;
    }
    return null;
  }

  List<Topic> topicsFor(String moduleId) =>
      topics.where((topic) => topic.moduleId == moduleId).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<OrganizerTimelineItem> timeline(
    DateTime start,
    DateTime end,
    AcademicOrganizerFilter filter, {
    bool deadlinesOnly = false,
  }) {
    final items = <OrganizerTimelineItem>[];
    if (!deadlinesOnly) {
      for (final event in events) {
        final occurrences = ScheduleConflictDetector.occurrencesBetween(
          event,
          rangeStart: start,
          rangeEnd: end,
        );
        for (final occurrence in occurrences) {
          items.add(
            OrganizerTimelineItem(
              kind: OrganizerItemKind.event,
              id: '${event.id}@${occurrence.startAt.millisecondsSinceEpoch}',
              title: event.title,
              when: occurrence.startAt,
              end: occurrence.endAt,
              moduleId: event.moduleId,
              priorityWeight: 0,
              isCompleted: false,
              entity: event,
              subtitle: event.location,
            ),
          );
        }
      }
    }
    for (final assignment in assignments) {
      if (_inRange(assignment.dueAt, start, end)) {
        items.add(
          OrganizerTimelineItem(
            kind: OrganizerItemKind.assignment,
            id: assignment.id,
            title: assignment.title,
            when: assignment.dueAt,
            moduleId: assignment.moduleId,
            priorityWeight: assignment.priority.weight,
            isCompleted: assignment.status == WorkStatus.completed,
            entity: assignment,
            subtitle: 'Assignment deadline',
          ),
        );
      }
    }
    for (final exam in exams) {
      if (_inRange(exam.startAt, start, end)) {
        items.add(
          OrganizerTimelineItem(
            kind: OrganizerItemKind.exam,
            id: exam.id,
            title: exam.title,
            when: exam.startAt,
            end: exam.endAt,
            moduleId: exam.moduleId,
            priorityWeight: exam.importance.weight,
            isCompleted: exam.endAt.isBefore(DateTime.now()),
            entity: exam,
            subtitle: exam.venue,
          ),
        );
      }
    }
    for (final task in tasks) {
      if (_inRange(task.dueAt, start, end)) {
        items.add(
          OrganizerTimelineItem(
            kind: OrganizerItemKind.task,
            id: task.id,
            title: task.title,
            when: task.dueAt,
            moduleId: task.moduleId,
            priorityWeight: task.priority.weight,
            isCompleted: task.isCompleted,
            entity: task,
            subtitle: '${task.estimatedMinutes} minute study task',
          ),
        );
      }
    }

    final query = filter.search.toLowerCase();
    final filtered =
        items.where((item) {
          if (filter.moduleId != null && item.moduleId != filter.moduleId) {
            return false;
          }
          if (!filter.showCompleted && item.isCompleted) return false;
          if (query.isEmpty) return true;
          final linkedModule = module(item.moduleId);
          return item.title.toLowerCase().contains(query) ||
              (item.subtitle?.toLowerCase().contains(query) ?? false) ||
              (linkedModule?.name.toLowerCase().contains(query) ?? false) ||
              (linkedModule?.code.toLowerCase().contains(query) ?? false);
        }).toList();

    switch (filter.sort) {
      case OrganizerSort.date:
        filtered.sort((a, b) => a.when.compareTo(b.when));
      case OrganizerSort.priority:
        filtered.sort((a, b) {
          final priority = b.priorityWeight.compareTo(a.priorityWeight);
          return priority == 0 ? a.when.compareTo(b.when) : priority;
        });
      case OrganizerSort.title:
        filtered.sort((a, b) => a.title.compareTo(b.title));
    }
    return List.unmodifiable(filtered);
  }

  Map<DateTime, int> monthCounts(
    DateTime month,
    AcademicOrganizerFilter filter,
  ) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final counts = <DateTime, int>{};
    for (final item in timeline(start, end, filter)) {
      final day = DateTime(item.when.year, item.when.month, item.when.day);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return counts;
  }

  static bool _inRange(DateTime value, DateTime start, DateTime end) =>
      !value.isBefore(start) && value.isBefore(end);
}
