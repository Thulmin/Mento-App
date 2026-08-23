// Combines academic data streams into values the organiser screens can render.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

enum AcademicOrganizerView { agenda, day, week, month, deadlines, modules }

enum OrganizerSort { date, priority, title }

final class AcademicOrganizerFilter {
  const AcademicOrganizerFilter({
    this.view = AcademicOrganizerView.agenda,
    this.search = '',
    this.moduleId,
    this.showCompleted = false,
    this.sort = OrganizerSort.date,
    required this.selectedDate,
  });

  final AcademicOrganizerView view;
  final String search;
  final String? moduleId;
  final bool showCompleted;
  final OrganizerSort sort;
  final DateTime selectedDate;

  AcademicOrganizerFilter copyWith({
    AcademicOrganizerView? view,
    String? search,
    String? moduleId,
    bool clearModule = false,
    bool? showCompleted,
    OrganizerSort? sort,
    DateTime? selectedDate,
  }) => AcademicOrganizerFilter(
    view: view ?? this.view,
    search: search ?? this.search,
    moduleId: clearModule ? null : (moduleId ?? this.moduleId),
    showCompleted: showCompleted ?? this.showCompleted,
    sort: sort ?? this.sort,
    selectedDate: selectedDate ?? this.selectedDate,
  );
}

final organizerFilterProvider = NotifierProvider<
  AcademicOrganizerFilterController,
  AcademicOrganizerFilter
>(AcademicOrganizerFilterController.new);

class AcademicOrganizerFilterController
    extends Notifier<AcademicOrganizerFilter> {
  @override
  AcademicOrganizerFilter build() {
    final now = DateTime.now();
    return AcademicOrganizerFilter(
      selectedDate: DateTime(now.year, now.month, now.day),
    );
  }

  void selectView(AcademicOrganizerView value) =>
      state = state.copyWith(view: value);
  void search(String value) => state = state.copyWith(search: value.trim());
  void selectModule(String? value) =>
      state = state.copyWith(moduleId: value, clearModule: value == null);
  void showCompleted(bool value) =>
      state = state.copyWith(showCompleted: value);
  void sortBy(OrganizerSort value) => state = state.copyWith(sort: value);
  void selectDate(DateTime value) =>
      state = state.copyWith(
        selectedDate: DateTime(value.year, value.month, value.day),
      );
}

final academicModulesProvider = StreamProvider<List<Module>>(
  (ref) => ref.watch(studentRepositoryProvider).watchModules(),
);

final academicTopicsProvider = StreamProvider<List<Topic>>(
  (ref) => ref.watch(studentRepositoryProvider).watchTopics(),
);

final academicAssignmentsProvider = StreamProvider<List<Assignment>>(
  (ref) => ref
      .watch(studentRepositoryProvider)
      .watchAssignments(includeCompleted: true),
);

final academicExamsProvider = StreamProvider<List<Exam>>(
  (ref) => ref.watch(studentRepositoryProvider).watchExams(),
);

final academicStudyTasksProvider = StreamProvider<List<StudyTask>>(
  (ref) => ref
      .watch(studentRepositoryProvider)
      .watchStudyTasks(includeCompleted: true),
);

final academicTimetableProvider = StreamProvider<List<TimetableEvent>>((ref) {
  final selected = ref.watch(
    organizerFilterProvider.select((filter) => filter.selectedDate),
  );
  final start = DateTime(selected.year, selected.month - 1, 1);
  final end = DateTime(selected.year, selected.month + 2, 1);
  return ref
      .watch(studentRepositoryProvider)
      .watchTimetableEvents(rangeStart: start, rangeEnd: end);
});

String newOrganizerId(String prefix) => '$prefix-${const Uuid().v4()}';
