// Builds a small, relevant academic snapshot for an assistant request.

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

final class AssistantContextSnapshot {
  const AssistantContextSnapshot({required this.data});

  final Map<String, Object?> data;
}

final class AssistantContextBuilder {
  const AssistantContextBuilder();

  Future<AssistantContextSnapshot> build(StudentRepository repository) async {
    final now = DateTime.now();
    final values = await Future.wait<Object>([
      _firstOrEmpty(repository.watchModules(limit: 40)),
      _firstOrEmpty(repository.watchTopics(limit: 120)),
      _firstOrEmpty(
        repository.watchAssignments(
          dueFrom: now.subtract(const Duration(days: 90)),
          dueBefore: now.add(const Duration(days: 365)),
          limit: 40,
        ),
      ),
      _firstOrEmpty(
        repository.watchExams(
          from: now.subtract(const Duration(days: 30)),
          before: now.add(const Duration(days: 365)),
          limit: 30,
        ),
      ),
      _firstOrEmpty(
        repository.watchStudyTasks(
          dueFrom: now.subtract(const Duration(days: 90)),
          dueBefore: now.add(const Duration(days: 365)),
          limit: 60,
        ),
      ),
      _firstOrEmpty(
        repository.watchTimetableEvents(
          rangeStart: now.subtract(const Duration(days: 7)),
          rangeEnd: now.add(const Duration(days: 90)),
          limit: 80,
        ),
      ),
      _firstOrEmpty(repository.watchHabits(limit: 30)),
      _firstOrEmpty(repository.watchFocusSessions(limit: 100)),
    ]);

    final modules = values[0] as List<Module>;
    final topics = values[1] as List<Topic>;
    final assignments = values[2] as List<Assignment>;
    final examinations = values[3] as List<Exam>;
    final tasks = values[4] as List<StudyTask>;
    final events = values[5] as List<TimetableEvent>;
    final habits = values[6] as List<Habit>;
    final focusSessions = values[7] as List<FocusSession>;

    final weekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - DateTime.monday));
    final weeklyFocusMinutes = focusSessions
        .where(
          (session) =>
              session.state == FocusSessionState.completed &&
              !session.startedAt.isBefore(weekStart),
        )
        .fold<int>(
          0,
          (total, session) => total + session.accumulatedActiveSeconds ~/ 60,
        );

    return AssistantContextSnapshot(
      data: {
        'now': now.toUtc().toIso8601String(),
        'modules': [
          for (final module in modules)
            {
              'id': module.id,
              'name': module.name,
              'code': module.code,
              'semester': module.semester,
            },
        ],
        'topics': [
          for (final topic in topics)
            {
              'id': topic.id,
              'moduleId': topic.moduleId,
              'name': topic.name,
              'mastery': topic.mastery,
            },
        ],
        'assignments': [
          for (final assignment in assignments)
            {
              'id': assignment.id,
              'moduleId': assignment.moduleId,
              'title': assignment.title,
              'dueAt': assignment.dueAt.toUtc().toIso8601String(),
              'priority': assignment.priority.name,
              'status': assignment.status.name,
              'progress': assignment.manualProgress,
              'estimatedMinutes': assignment.estimatedMinutes,
            },
        ],
        'examinations': [
          for (final exam in examinations)
            {
              'id': exam.id,
              'moduleId': exam.moduleId,
              'title': exam.title,
              'startAt': exam.startAt.toUtc().toIso8601String(),
              'endAt': exam.endAt.toUtc().toIso8601String(),
              'importance': exam.importance.name,
              'preparationProgress': exam.preparationProgress,
            },
        ],
        'tasks': [
          for (final task in tasks)
            {
              'id': task.id,
              'title': task.title,
              'moduleId': task.moduleId,
              'topicId': task.topicId,
              'dueAt': task.dueAt.toUtc().toIso8601String(),
              'priority': task.priority.name,
              'estimatedMinutes': task.estimatedMinutes,
              'status': task.status.name,
            },
        ],
        'timetableEvents': [
          for (final event in events)
            {
              'id': event.id,
              'title': event.title,
              'moduleId': event.moduleId,
              'type': event.type.name,
              'startAt': event.startAt.toUtc().toIso8601String(),
              'endAt': event.endAt.toUtc().toIso8601String(),
              'recurrence': event.recurrence.name,
            },
        ],
        'habits': [
          for (final habit in habits)
            {
              'id': habit.id,
              'name': habit.name,
              'category': habit.category.name,
              'frequency': habit.frequency.name,
              'weeklyTarget': habit.weeklyTarget,
              'isArchived': habit.isArchived,
            },
        ],
        'weeklyFocusMinutes': weeklyFocusMinutes,
      },
    );
  }

  Future<List<T>> _firstOrEmpty<T>(Stream<List<T>> stream) async {
    try {
      return await stream.first.timeout(const Duration(seconds: 8));
    } catch (_) {
      return const [];
    }
  }
}
