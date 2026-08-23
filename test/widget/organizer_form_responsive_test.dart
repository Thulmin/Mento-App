import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mento/data/models/models.dart';
import 'package:mento/features/assignments/presentation/assignment_form.dart';
import 'package:mento/features/examinations/presentation/exam_form.dart';
import 'package:mento/features/study_tasks/presentation/study_task_form.dart';
import 'package:mento/features/timetable/presentation/timetable_event_form.dart';

void main() {
  final now = DateTime(2026, 7, 18);
  final module = Module(
    id: 'module-long',
    name:
        'Engineering Mobile Applications with an intentionally long module name',
    code: 'MOBILE-APPLICATION-ENGINEERING-601',
    semester: 'Semester 2',
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpNarrowForm(
    WidgetTester tester,
    Widget child,
    String title,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.8)),
                child: child!,
              ),
          home: Scaffold(body: child),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(title), findsOneWidget);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'study task form does not overflow on a narrow large-text phone',
    (tester) async {
      await pumpNarrowForm(
        tester,
        StudyTaskForm(
          modules: [module],
          topics: const [],
          task: StudyTask(
            id: 'task',
            title: 'Review',
            moduleId: module.id,
            dueAt: now,
            estimatedMinutes: 50,
            priority: PriorityLevel.medium,
            status: WorkStatus.notStarted,
          ),
        ),
        'Edit study task',
      );
    },
  );

  testWidgets(
    'assignment form does not overflow on a narrow large-text phone',
    (tester) async {
      await pumpNarrowForm(
        tester,
        AssignmentForm(modules: [module]),
        'Add assignment',
      );
    },
  );

  testWidgets('exam form does not overflow on a narrow large-text phone', (
    tester,
  ) async {
    await pumpNarrowForm(
      tester,
      ExamForm(modules: [module], topics: const []),
      'Add examination',
    );
  });

  testWidgets('timetable form does not overflow on a narrow large-text phone', (
    tester,
  ) async {
    await pumpNarrowForm(
      tester,
      TimetableEventForm(
        modules: [module],
        event: TimetableEvent(
          id: 'event',
          title: 'Lecture',
          moduleId: module.id,
          type: EventType.lecture,
          startAt: now,
          endAt: now.add(const Duration(hours: 1)),
        ),
      ),
      'Edit timetable event',
    );
  });
}
