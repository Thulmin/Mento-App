// Collects planning context and opens the planner with live academic data.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../../core/logic/logic.dart';
import '../../../core/widgets/mento_states.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../dashboard/application/dashboard_providers.dart';
import '../../profile/application/profile_settings_controller.dart';
import '../application/ai_planner_service.dart';
import 'ai_planner_screen.dart';

final plannerTimezoneProvider = FutureProvider<String>((ref) async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    return 'UTC';
  }
});

class PlannerEntryScreen extends ConsumerWidget {
  const PlannerEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timezone = ref.watch(plannerTimezoneProvider);
    final tasks = ref.watch(dashboardTasksProvider);
    final assignments = ref.watch(dashboardAssignmentsProvider);
    final exams = ref.watch(dashboardExamsProvider);
    final events = ref.watch(dashboardEventsProvider);
    final modules = ref.watch(dashboardModulesProvider);
    final settings = ref.watch(profileSettingsProvider);
    final repository = ref.watch(studentRepositoryProvider);
    final values = [tasks, assignments, exams, events, modules];
    if (timezone.isLoading ||
        settings.isLoading ||
        values.any((item) => item.isLoading)) {
      return const Scaffold(
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }
    if (timezone.hasError ||
        settings.hasError ||
        values.any((item) => item.hasError)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Smart study plan')),
        body: MentoErrorState(
          title: 'Planning context is unavailable',
          message:
              'Your records remain saved. Retry after the current data finishes syncing.',
          onRetry: () {
            ref.invalidate(plannerTimezoneProvider);
            ref.invalidate(dashboardTasksProvider);
            ref.invalidate(dashboardAssignmentsProvider);
            ref.invalidate(dashboardExamsProvider);
            ref.invalidate(dashboardEventsProvider);
            ref.invalidate(dashboardModulesProvider);
          },
        ),
      );
    }
    final now = DateTime.now();
    final rangeEnd = DateTime(now.year, now.month, now.day + 7, 23, 59);
    final work =
        <PlannerWorkItem>[
          for (final task in tasks.value!.where((item) => !item.isCompleted))
            PlannerWorkItem(
              id: task.id,
              title: task.title,
              moduleId: task.moduleId,
              topicId: task.topicId,
              deadline: task.dueAt,
              remainingMinutes: task.estimatedMinutes,
              priority: task.priority,
              wasMissed:
                  task.needsRescheduling || task.status == WorkStatus.missed,
            ),
          for (final assignment in assignments.value!.where(
            (item) => item.status != WorkStatus.completed,
          ))
            PlannerWorkItem(
              id: assignment.id,
              title: assignment.title,
              moduleId: assignment.moduleId,
              deadline: assignment.dueAt,
              remainingMinutes:
                  (assignment.estimatedMinutes *
                          (1 -
                              AssignmentProgressCalculator.calculate(
                                assignment,
                              ).fraction))
                      .round(),
              priority: assignment.priority,
              recommendedMethod: 'Active production and review',
            ),
          for (final exam in exams.value!.where(
            (item) => item.startAt.isAfter(now),
          ))
            PlannerWorkItem(
              id: exam.id,
              title: 'Prepare for ${exam.title}',
              moduleId: exam.moduleId,
              deadline: exam.startAt,
              remainingMinutes: (300 * (1 - exam.preparationProgress)).round(),
              priority: exam.importance,
              recommendedMethod: 'Active recall and timed practice',
            ),
        ].where((item) => item.remainingMinutes > 0).toList();
    if (work.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Smart study plan')),
        body: const MentoEmptyState(
          title: 'Nothing active needs planning',
          message:
              'Add a study task, assignment or future exam first. Completed work is never re-added automatically.',
          icon: Icons.event_available_outlined,
        ),
      );
    }
    final availability = <AvailabilitySlot>[];
    for (var index = 0; index < 7; index++) {
      final day = DateTime(now.year, now.month, now.day + index);
      final weekend =
          day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;
      var start = DateTime(day.year, day.month, day.day, weekend ? 9 : 18);
      final end = DateTime(day.year, day.month, day.day, weekend ? 17 : 22);
      if (start.isBefore(now)) start = now.add(const Duration(minutes: 5));
      if (end.difference(start).inMinutes >= 20) {
        availability.add(AvailabilitySlot(startAt: start, endAt: end));
      }
    }
    final preference = settings.value!;
    final input = StudyPlannerInput(
      userId: repository.ownerId,
      now: now,
      rangeStart: now,
      rangeEnd: rangeEnd,
      timeZone: timezone.value!,
      workItems: work,
      availability: availability,
      commitments: [
        for (final event in events.value!)
          BusyPeriod(
            startAt: event.startAt,
            endAt: event.endAt,
            reason: event.title,
          ),
      ],
      preferences: PlannerPreferences(
        preferredSessionMinutes: preference.studySessionMinutes.clamp(20, 90),
        minimumSessionMinutes: 20,
        breakMinutes: preference.breakMinutes.clamp(5, 30),
        maxDailyMinutes: 240,
      ),
      moduleNames: {
        for (final module in modules.value!) module.id: module.name,
      },
      missedTaskIds:
          tasks.value!
              .where(
                (item) =>
                    item.needsRescheduling || item.status == WorkStatus.missed,
              )
              .map((item) => item.id)
              .toList(),
    );
    return AiPlannerScreen(input: input, onAccept: repository.saveStudyPlan);
  }
}
