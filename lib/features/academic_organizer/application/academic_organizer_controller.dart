// Coordinates organiser create, update, delete, and completion actions.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logic/logic.dart';
import '../../../core/services/notification_service.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

final class OrganizerActionState {
  const OrganizerActionState({this.isLoading = false, this.error, this.notice});

  final bool isLoading;
  final Object? error;
  final String? notice;
}

abstract interface class OrganizerReminderScheduler {
  Future<void> syncEvent(TimetableEvent event);
  Future<void> syncAssignment(Assignment assignment);
  Future<void> syncExam(Exam exam);
  Future<void> syncTask(StudyTask task);
  Future<void> cancelEvent(String id);
  Future<void> cancelAssignment(String id);
  Future<void> cancelExam(String id);
  Future<void> cancelTask(String id);
}

final organizerReminderSchedulerProvider = Provider<OrganizerReminderScheduler>(
  (ref) => NotificationOrganizerReminderScheduler(NotificationService.instance),
);

final class NotificationOrganizerReminderScheduler
    implements OrganizerReminderScheduler {
  const NotificationOrganizerReminderScheduler(this._notifications);

  final NotificationService _notifications;

  @override
  Future<void> syncEvent(TimetableEvent event) async {
    await cancelEvent(event.id);
    final lead = event.reminderMinutesBefore;
    if (lead == null) return;
    await _notifications.schedule(
      entityId: event.id,
      category: ReminderCategory.classes,
      title: event.title,
      body:
          event.location == null
              ? 'Starts in $lead minutes'
              : 'Starts in $lead minutes · ${event.location}',
      scheduledFor: event.startAt.subtract(Duration(minutes: lead)),
      payload: '/plan?event=${event.id}',
    );
  }

  @override
  Future<void> syncAssignment(Assignment assignment) async {
    await cancelAssignment(assignment.id);
    final reminder = assignment.reminderAt;
    if (reminder == null || assignment.status == WorkStatus.completed) return;
    await _notifications.schedule(
      entityId: assignment.id,
      category: ReminderCategory.assignments,
      title: assignment.title,
      body: 'Review progress before the assignment deadline.',
      scheduledFor: reminder,
      payload: '/plan?assignment=${assignment.id}',
    );
  }

  @override
  Future<void> syncExam(Exam exam) async {
    await cancelExam(exam.id);
    final reminder = exam.reminderAt;
    if (reminder == null) return;
    await _notifications.schedule(
      entityId: exam.id,
      category: ReminderCategory.examinations,
      title: exam.title,
      body:
          exam.venue == null
              ? 'Examination preparation reminder'
              : 'Preparation reminder · ${exam.venue}',
      scheduledFor: reminder,
      payload: '/plan?exam=${exam.id}',
    );
  }

  @override
  Future<void> syncTask(StudyTask task) async {
    await cancelTask(task.id);
    final reminder = task.plannedStartAt;
    if (reminder == null || task.isCompleted) return;
    await _notifications.schedule(
      entityId: task.id,
      category: ReminderCategory.studySessions,
      title: task.title,
      body: 'Your planned study block is ready to begin.',
      scheduledFor: reminder,
      payload: '/plan?task=${task.id}',
    );
  }

  @override
  Future<void> cancelEvent(String id) =>
      _notifications.cancel(ReminderCategory.classes, id);
  @override
  Future<void> cancelAssignment(String id) =>
      _notifications.cancel(ReminderCategory.assignments, id);
  @override
  Future<void> cancelExam(String id) =>
      _notifications.cancel(ReminderCategory.examinations, id);
  @override
  Future<void> cancelTask(String id) =>
      _notifications.cancel(ReminderCategory.studySessions, id);
}

final academicOrganizerControllerProvider =
    NotifierProvider<AcademicOrganizerController, OrganizerActionState>(
      AcademicOrganizerController.new,
    );

class AcademicOrganizerController extends Notifier<OrganizerActionState> {
  @override
  OrganizerActionState build() => const OrganizerActionState();

  List<TimetableEvent> findEventConflicts(
    TimetableEvent candidate,
    Iterable<TimetableEvent> existing,
  ) {
    final others = existing.where((event) => event.id != candidate.id).toList();
    if (others.isEmpty) return const [];
    final rangeStart = candidate.startAt.subtract(const Duration(days: 1));
    final rangeEnd =
        candidate.recurrenceUntil?.add(const Duration(days: 1)) ??
        candidate.endAt.add(const Duration(days: 90));
    final conflicts = ScheduleConflictDetector.findConflicts(
      [candidate, ...others],
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
    );
    final ids = <String>{};
    for (final conflict in conflicts) {
      if (conflict.firstEventId == candidate.id) {
        ids.add(conflict.secondEventId);
      }
      if (conflict.secondEventId == candidate.id) {
        ids.add(conflict.firstEventId);
      }
    }
    return List.unmodifiable(others.where((event) => ids.contains(event.id)));
  }

  Future<bool> saveModule(Module module) =>
      _run(() => ref.read(studentRepositoryProvider).saveModule(module));
  Future<bool> saveTopic(Topic topic) =>
      _run(() => ref.read(studentRepositoryProvider).saveTopic(topic));

  Future<bool> saveEvent(TimetableEvent event) => _run(
    () => ref.read(studentRepositoryProvider).saveTimetableEvent(event),
    reminder:
        () => ref.read(organizerReminderSchedulerProvider).syncEvent(event),
  );

  Future<bool> saveAssignment(Assignment assignment) => _run(
    () => ref.read(studentRepositoryProvider).saveAssignment(assignment),
    reminder:
        () => ref
            .read(organizerReminderSchedulerProvider)
            .syncAssignment(assignment),
  );

  Future<bool> saveExam(Exam exam) => _run(
    () => ref.read(studentRepositoryProvider).saveExam(exam),
    reminder: () => ref.read(organizerReminderSchedulerProvider).syncExam(exam),
  );

  Future<bool> saveTask(StudyTask task) => _run(
    () => ref.read(studentRepositoryProvider).saveStudyTask(task),
    reminder: () => ref.read(organizerReminderSchedulerProvider).syncTask(task),
  );

  Future<bool> toggleTask(StudyTask task) => _run(
    () => ref
        .read(studentRepositoryProvider)
        .setStudyTaskCompleted(task.id, completed: !task.isCompleted),
    reminder: () async {
      final scheduler = ref.read(organizerReminderSchedulerProvider);
      if (!task.isCompleted) {
        await scheduler.cancelTask(task.id);
      } else {
        await scheduler.syncTask(task);
      }
    },
  );

  Future<bool> deleteModule(String id, {bool cascade = false}) => _run(
    () =>
        ref.read(studentRepositoryProvider).deleteModule(id, cascade: cascade),
  );
  Future<bool> deleteTopic(String id) =>
      _run(() => ref.read(studentRepositoryProvider).deleteTopic(id));
  Future<bool> deleteEvent(String id) => _run(
    () => ref.read(studentRepositoryProvider).deleteTimetableEvent(id),
    reminder:
        () => ref.read(organizerReminderSchedulerProvider).cancelEvent(id),
  );
  Future<bool> deleteAssignment(String id) => _run(
    () => ref.read(studentRepositoryProvider).deleteAssignment(id),
    reminder:
        () => ref.read(organizerReminderSchedulerProvider).cancelAssignment(id),
  );
  Future<bool> deleteExam(String id) => _run(
    () => ref.read(studentRepositoryProvider).deleteExam(id),
    reminder: () => ref.read(organizerReminderSchedulerProvider).cancelExam(id),
  );
  Future<bool> deleteTask(String id) => _run(
    () => ref.read(studentRepositoryProvider).deleteStudyTask(id),
    reminder: () => ref.read(organizerReminderSchedulerProvider).cancelTask(id),
  );

  Future<bool> _run(
    Future<void> Function() operation, {
    Future<void> Function()? reminder,
  }) async {
    if (state.isLoading) return false;
    state = const OrganizerActionState(isLoading: true);
    try {
      await operation();
      if (reminder != null) {
        try {
          await reminder();
        } catch (_) {
          state = const OrganizerActionState(
            notice:
                'Saved successfully, but the local reminder could not be updated.',
          );
          return true;
        }
      }
      state = const OrganizerActionState(notice: 'Saved successfully.');
      return true;
    } catch (error) {
      state = OrganizerActionState(error: error);
      return false;
    }
  }
}
