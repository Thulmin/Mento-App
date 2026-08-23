// Presents the timetable, deadlines, modules, search, filters, and edit actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/widgets/mento_controls.dart';
import '../../../core/widgets/mento_states.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../assignments/presentation/assignment_form.dart';
import '../../examinations/presentation/exam_form.dart';
import '../../modules/presentation/module_form.dart';
import '../../modules/presentation/modules_view.dart';
import '../../study_tasks/presentation/study_task_form.dart';
import '../../timetable/presentation/timetable_event_form.dart';
import '../application/academic_organizer_controller.dart';
import '../application/academic_organizer_providers.dart';
import 'organizer_data.dart';
import 'widgets/organizer_views.dart';

class AcademicOrganizerScreen extends ConsumerWidget {
  const AcademicOrganizerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(academicOrganizerControllerProvider, (previous, next) {
      final message = next.error?.toString() ?? next.notice;
      if (message == null || message == previous?.notice) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });

    final modules = ref.watch(academicModulesProvider);
    final topics = ref.watch(academicTopicsProvider);
    final events = ref.watch(academicTimetableProvider);
    final assignments = ref.watch(academicAssignmentsProvider);
    final exams = ref.watch(academicExamsProvider);
    final tasks = ref.watch(academicStudyTasksProvider);
    final online = ref.watch(connectivityProvider).value ?? true;
    final repository = ref.watch(studentRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const MentoScreenTitle(
          title: 'Academic organiser',
          semanticIdentifier: 'mento_screen_plan',
        ),
        actions: [
          if (repository.isDemo)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Chip(label: Text('Demo · memory only'))),
            ),
          IconButton(
            tooltip: 'Refresh academic data',
            onPressed: () => _refresh(ref),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('academic-quick-add'),
        onPressed:
            () => _showQuickAdd(
              context,
              modules.value ?? const [],
              topics.value ?? const [],
            ),
        icon: const Icon(Icons.add),
        label: const Text('Quick add'),
      ),
      body: Column(
        children: [
          MentoOfflineBanner(visible: !online),
          Expanded(
            child: _streamBody(
              context,
              ref,
              modules: modules,
              topics: topics,
              events: events,
              assignments: assignments,
              exams: exams,
              tasks: tasks,
            ),
          ),
        ],
      ),
    );
  }

  Widget _streamBody(
    BuildContext context,
    WidgetRef ref, {
    required AsyncValue<List<Module>> modules,
    required AsyncValue<List<Topic>> topics,
    required AsyncValue<List<TimetableEvent>> events,
    required AsyncValue<List<Assignment>> assignments,
    required AsyncValue<List<Exam>> exams,
    required AsyncValue<List<StudyTask>> tasks,
  }) {
    final values = <AsyncValue<Object>>[
      modules,
      topics,
      events,
      assignments,
      exams,
      tasks,
    ];
    final error = values.where((value) => value.hasError).firstOrNull?.error;
    if (error != null) {
      return MentoErrorState(
        title: 'Academic data could not be loaded',
        message: _friendlyError(error),
        onRetry: () => _refresh(ref),
      );
    }
    if (values.any((value) => value.isLoading && !value.hasValue)) {
      return const MentoPage(
        child: Column(
          children: [
            MentoLoadingSkeleton(height: 72),
            SizedBox(height: 16),
            MentoLoadingSkeleton(height: 150),
            SizedBox(height: 12),
            MentoLoadingSkeleton(height: 150),
          ],
        ),
      );
    }

    final data = AcademicOrganizerData(
      modules: modules.value ?? const [],
      topics: topics.value ?? const [],
      events: events.value ?? const [],
      assignments: assignments.value ?? const [],
      exams: exams.value ?? const [],
      tasks: tasks.value ?? const [],
    );
    return MentoPage(child: _OrganizerContent(data: data));
  }

  static void _refresh(WidgetRef ref) {
    ref.invalidate(academicModulesProvider);
    ref.invalidate(academicTopicsProvider);
    ref.invalidate(academicTimetableProvider);
    ref.invalidate(academicAssignmentsProvider);
    ref.invalidate(academicExamsProvider);
    ref.invalidate(academicStudyTasksProvider);
  }

  static String _friendlyError(Object error) {
    if (error is StudentRepositoryException) return error.message;
    return 'Saved data remains protected. Check your connection and retry.';
  }

  static Future<void> _showQuickAdd(
    BuildContext context,
    List<Module> modules,
    List<Topic> topics,
  ) async {
    final selection = await showModalBottomSheet<_AddKind>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (sheetContext) => ListView(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              const ListTile(
                title: Text('Quick add'),
                subtitle: Text('Choose what you want to organise.'),
              ),
              for (final kind in _AddKind.values)
                ListTile(
                  leading: Icon(kind.icon),
                  title: Text(kind.label),
                  onTap: () => Navigator.pop(sheetContext, kind),
                ),
              const SizedBox(height: 12),
            ],
          ),
    );
    if (selection == null || !context.mounted) return;
    if ((selection == _AddKind.assignment || selection == _AddKind.exam) &&
        modules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a module before creating this item.'),
        ),
      );
      await showModuleForm(context);
      return;
    }
    switch (selection) {
      case _AddKind.module:
        await showModuleForm(context);
      case _AddKind.event:
        await showTimetableEventForm(context, modules: modules);
      case _AddKind.assignment:
        await showAssignmentForm(context, modules: modules);
      case _AddKind.exam:
        await showExamForm(context, modules: modules, topics: topics);
      case _AddKind.task:
        await showStudyTaskForm(context, modules: modules, topics: topics);
    }
  }
}

class _OrganizerContent extends ConsumerWidget {
  const _OrganizerContent({required this.data});

  final AcademicOrganizerData data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(organizerFilterProvider);
    final viewSelector = _ViewSelector(filter: filter);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(data: data, filter: filter),
        const SizedBox(height: 14),
        if (filter.view != AcademicOrganizerView.modules) ...[
          _DateNavigator(filter: filter),
          const SizedBox(height: 12),
        ],
        _buildView(context, ref, filter),
        const SizedBox(height: 92),
      ],
    );
    if (context.windowClass == MentoWindowClass.expanded) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 178, child: viewSelector),
          const SizedBox(width: 20),
          Expanded(child: content),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [viewSelector, const SizedBox(height: 14), content],
    );
  }

  Widget _buildView(
    BuildContext context,
    WidgetRef ref,
    AcademicOrganizerFilter filter,
  ) {
    final selected = filter.selectedDate;
    final dayStart = DateTime(selected.year, selected.month, selected.day);
    return switch (filter.view) {
      AcademicOrganizerView.agenda => OrganizerTimelineView(
        data: data,
        filter: filter,
        start: dayStart.subtract(const Duration(days: 7)),
        end: dayStart.add(const Duration(days: 31)),
        onEdit: (item) => _edit(context, item),
        onDelete: (item) => _delete(context, ref, item),
        onToggleTask: (item) => _toggle(ref, item),
      ),
      AcademicOrganizerView.day => OrganizerTimelineView(
        data: data,
        filter: filter,
        start: dayStart,
        end: dayStart.add(const Duration(days: 1)),
        emptyTitle: 'This day is open',
        emptyMessage: 'No classes or deadlines match the current filters.',
        onEdit: (item) => _edit(context, item),
        onDelete: (item) => _delete(context, ref, item),
        onToggleTask: (item) => _toggle(ref, item),
      ),
      AcademicOrganizerView.week => OrganizerWeekView(
        data: data,
        filter: filter,
        onEdit: (item) => _edit(context, item),
        onDelete: (item) => _delete(context, ref, item),
        onToggleTask: (item) => _toggle(ref, item),
        onSelectDay: (day) {
          ref.read(organizerFilterProvider.notifier)
            ..selectDate(day)
            ..selectView(AcademicOrganizerView.day);
        },
      ),
      AcademicOrganizerView.month => OrganizerMonthView(
        data: data,
        filter: filter,
        onSelectDay: (day) {
          ref.read(organizerFilterProvider.notifier)
            ..selectDate(day)
            ..selectView(AcademicOrganizerView.day);
        },
      ),
      AcademicOrganizerView.deadlines => OrganizerTimelineView(
        data: data,
        filter: filter,
        deadlinesOnly: true,
        start: DateTime.now().subtract(const Duration(days: 365)),
        end: DateTime.now().add(const Duration(days: 730)),
        emptyTitle: 'No matching deadlines',
        emptyMessage: 'Assignments, exams and study tasks will appear here.',
        onEdit: (item) => _edit(context, item),
        onDelete: (item) => _delete(context, ref, item),
        onToggleTask: (item) => _toggle(ref, item),
      ),
      AcademicOrganizerView.modules => ModulesView(data: data, filter: filter),
    };
  }

  Future<void> _edit(BuildContext context, OrganizerTimelineItem item) async {
    switch (item.entity) {
      case final TimetableEvent event:
        await showTimetableEventForm(
          context,
          modules: data.modules,
          event: event,
        );
      case final Assignment assignment:
        await showAssignmentForm(
          context,
          modules: data.modules,
          assignment: assignment,
        );
      case final Exam exam:
        await showExamForm(
          context,
          modules: data.modules,
          topics: data.topics,
          exam: exam,
        );
      case final StudyTask task:
        await showStudyTaskForm(
          context,
          modules: data.modules,
          topics: data.topics,
          task: task,
        );
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    OrganizerTimelineItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete item?'),
            content: Text('Delete “${item.title}”? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('confirm-academic-delete'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    final controller = ref.read(academicOrganizerControllerProvider.notifier);
    switch (item.entity) {
      case final TimetableEvent event:
        await controller.deleteEvent(event.id);
      case final Assignment assignment:
        await controller.deleteAssignment(assignment.id);
      case final Exam exam:
        await controller.deleteExam(exam.id);
      case final StudyTask task:
        await controller.deleteTask(task.id);
    }
  }

  Future<void> _toggle(WidgetRef ref, OrganizerTimelineItem item) async {
    if (item.entity case final StudyTask task) {
      await ref
          .read(academicOrganizerControllerProvider.notifier)
          .toggleTask(task);
    }
  }
}

class _ViewSelector extends ConsumerWidget {
  const _ViewSelector({required this.filter});

  final AcademicOrganizerFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: 8,
    runSpacing: 8,
    direction:
        context.windowClass == MentoWindowClass.expanded
            ? Axis.vertical
            : Axis.horizontal,
    children: [
      for (final view in AcademicOrganizerView.values)
        ChoiceChip(
          key: Key('organizer-view-${view.name}'),
          avatar: Icon(view.icon, size: 18),
          label: Text(view.label),
          selected: filter.view == view,
          onSelected:
              (_) =>
                  ref.read(organizerFilterProvider.notifier).selectView(view),
        ),
    ],
  );
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.data, required this.filter});

  final AcademicOrganizerData data;
  final AcademicOrganizerFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      final search = TextField(
        key: const Key('academic-search'),
        decoration: const InputDecoration(
          labelText: 'Search academic items',
          prefixIcon: Icon(Icons.search),
        ),
        onChanged: ref.read(organizerFilterProvider.notifier).search,
      );
      final controls =
          wide
              ? Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      isExpanded: true,
                      value: filter.moduleId,
                      decoration: const InputDecoration(
                        labelText: 'Module filter',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('All modules'),
                        ),
                        for (final module in data.modules)
                          DropdownMenuItem<String?>(
                            value: module.id,
                            child: Text(module.code),
                          ),
                      ],
                      onChanged:
                          ref
                              .read(organizerFilterProvider.notifier)
                              .selectModule,
                    ),
                  ),
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<OrganizerSort>(
                      isExpanded: true,
                      value: filter.sort,
                      decoration: const InputDecoration(labelText: 'Sort by'),
                      items: [
                        for (final sort in OrganizerSort.values)
                          DropdownMenuItem(
                            value: sort,
                            child: Text(sort.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          ref
                              .read(organizerFilterProvider.notifier)
                              .sortBy(value);
                        }
                      },
                    ),
                  ),
                  FilterChip(
                    label: const Text('Show completed'),
                    selected: filter.showCompleted,
                    onSelected:
                        ref
                            .read(organizerFilterProvider.notifier)
                            .showCompleted,
                  ),
                ],
              )
              : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          value: filter.moduleId,
                          decoration: const InputDecoration(
                            labelText: 'Module filter',
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All modules'),
                            ),
                            for (final module in data.modules)
                              DropdownMenuItem<String?>(
                                value: module.id,
                                child: Text(module.code),
                              ),
                          ],
                          onChanged:
                              ref
                                  .read(organizerFilterProvider.notifier)
                                  .selectModule,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<OrganizerSort>(
                          isExpanded: true,
                          value: filter.sort,
                          decoration: const InputDecoration(
                            labelText: 'Sort by',
                          ),
                          items: [
                            for (final sort in OrganizerSort.values)
                              DropdownMenuItem(
                                value: sort,
                                child: Text(sort.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              ref
                                  .read(organizerFilterProvider.notifier)
                                  .sortBy(value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('Show completed'),
                      selected: filter.showCompleted,
                      onSelected:
                          ref
                              .read(organizerFilterProvider.notifier)
                              .showCompleted,
                    ),
                  ),
                ],
              );
      return wide
          ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: search),
              const SizedBox(width: 12),
              Flexible(flex: 2, child: controls),
            ],
          )
          : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [search, const SizedBox(height: 18), controls],
          );
    },
  );
}

class _DateNavigator extends ConsumerWidget {
  const _DateNavigator({required this.filter});

  final AcademicOrganizerFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(organizerFilterProvider.notifier);
    final step =
        filter.view == AcademicOrganizerView.month
            ? const Duration(days: 31)
            : filter.view == AcademicOrganizerView.week
            ? const Duration(days: 7)
            : const Duration(days: 1);
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous period',
          onPressed:
              () => controller.selectDate(filter.selectedDate.subtract(step)),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            DateFormat('EEE, d MMMM yyyy').format(filter.selectedDate),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        TextButton(
          onPressed: () => controller.selectDate(DateTime.now()),
          child: const Text('Today'),
        ),
        IconButton(
          tooltip: 'Next period',
          onPressed: () => controller.selectDate(filter.selectedDate.add(step)),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

enum _AddKind { module, event, assignment, exam, task }

extension on _AddKind {
  String get label => switch (this) {
    _AddKind.module => 'Module',
    _AddKind.event => 'Timetable event',
    _AddKind.assignment => 'Assignment',
    _AddKind.exam => 'Examination',
    _AddKind.task => 'Study task',
  };

  IconData get icon => switch (this) {
    _AddKind.module => Icons.menu_book_outlined,
    _AddKind.event => Icons.event_outlined,
    _AddKind.assignment => Icons.assignment_outlined,
    _AddKind.exam => Icons.fact_check_outlined,
    _AddKind.task => Icons.task_alt_outlined,
  };
}

extension on AcademicOrganizerView {
  String get label => switch (this) {
    AcademicOrganizerView.agenda => 'Agenda',
    AcademicOrganizerView.day => 'Day',
    AcademicOrganizerView.week => 'Week',
    AcademicOrganizerView.month => 'Month',
    AcademicOrganizerView.deadlines => 'Deadlines',
    AcademicOrganizerView.modules => 'Modules',
  };

  IconData get icon => switch (this) {
    AcademicOrganizerView.agenda => Icons.view_agenda_outlined,
    AcademicOrganizerView.day => Icons.today_outlined,
    AcademicOrganizerView.week => Icons.view_week_outlined,
    AcademicOrganizerView.month => Icons.calendar_month_outlined,
    AcademicOrganizerView.deadlines => Icons.flag_outlined,
    AcademicOrganizerView.modules => Icons.menu_book_outlined,
  };
}

extension on OrganizerSort {
  String get label => switch (this) {
    OrganizerSort.date => 'Date',
    OrganizerSort.priority => 'Priority',
    OrganizerSort.title => 'Title',
  };
}
