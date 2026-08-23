import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mento/app/theme/app_theme.dart';
import 'package:mento/core/services/connectivity_service.dart';
import 'package:mento/data/models/models.dart';
import 'package:mento/data/repositories/repositories.dart';
import 'package:mento/features/academic_organizer/application/academic_organizer_controller.dart';
import 'package:mento/features/academic_organizer/presentation/academic_organizer_screen.dart';
import 'package:mento/features/academic_organizer/presentation/widgets/organizer_item_tile.dart';

void main() {
  late DemoStudentRepository repository;

  setUp(() {
    final now = DateTime.now();
    repository = DemoStudentRepository(
      referenceDate: DateTime(now.year, now.month, now.day),
    );
  });

  tearDown(() => repository.dispose());

  Future<void> pumpOrganizer(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          studentRepositoryProvider.overrideWithValue(repository),
          organizerReminderSchedulerProvider.overrideWithValue(
            const _NoopReminderScheduler(),
          ),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp(
          theme: MentoTheme.light,
          home: const AcademicOrganizerScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('renders deterministic demo agenda and all organizer views', (
    tester,
  ) async {
    await pumpOrganizer(tester);

    expect(find.text('Academic organiser'), findsOneWidget);
    expect(find.text('Demo · memory only'), findsOneWidget);
    expect(find.byKey(const Key('organizer-view-agenda')), findsOneWidget);
    expect(find.byKey(const Key('organizer-view-day')), findsOneWidget);
    expect(find.byKey(const Key('organizer-view-week')), findsOneWidget);
    expect(find.byKey(const Key('organizer-view-month')), findsOneWidget);
    expect(find.byKey(const Key('organizer-view-deadlines')), findsOneWidget);
    expect(find.byKey(const Key('organizer-view-modules')), findsOneWidget);

    await tester.tap(find.byKey(const Key('organizer-view-deadlines')));
    await tester.pump();
    expect(find.text('Mento architecture report'), findsOneWidget);
    expect(find.text('Applied AI final examination'), findsOneWidget);

    await tester.tap(find.byKey(const Key('organizer-view-modules')));
    await tester.pump();
    expect(find.text('Mobile Application Engineering'), findsOneWidget);
    expect(find.text('Applied Artificial Intelligence'), findsOneWidget);
    expect(find.text('Data Systems'), findsOneWidget);
    expect(find.text('Human-centred Design'), findsOneWidget);
  });

  testWidgets('quick add validates and persists a module in memory', (
    tester,
  ) async {
    await pumpOrganizer(tester);

    await tester.tap(find.byKey(const Key('academic-quick-add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Module').last);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('module-name-field')),
      'Research Methods',
    );
    await tester.enterText(
      find.byKey(const Key('module-code-field')),
      'RES 500',
    );
    final save = find.byKey(const Key('organizer-form-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('organizer-view-modules')));
    await tester.pump();
    expect(find.text('Research Methods'), findsOneWidget);
    expect(find.text('RES 500'), findsOneWidget);
  });

  testWidgets('study task checkbox updates the streamed demo repository', (
    tester,
  ) async {
    await pumpOrganizer(tester);
    await tester.tap(find.byKey(const Key('organizer-view-deadlines')));
    await tester.pump();

    final tile = find.ancestor(
      of: find.text('Draft threat model'),
      matching: find.byType(OrganizerItemTile),
    );
    final checkbox = find.descendant(of: tile, matching: find.byType(Checkbox));
    expect(checkbox, findsOneWidget);
    expect(tester.widget<Checkbox>(checkbox).value, isFalse);

    await tester.tap(checkbox);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final tasks = await repository.watchStudyTasks().first;
    expect(
      tasks.singleWhere((task) => task.id == 'demo-task-security').isCompleted,
      isTrue,
    );
  });

  testWidgets('expanded layout and module search remain usable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1180, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpOrganizer(tester);

    await tester.tap(find.byKey(const Key('organizer-view-modules')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('academic-search')),
      'Artificial',
    );
    await tester.pump();

    expect(find.text('Applied Artificial Intelligence'), findsOneWidget);
    expect(find.text('Human-centred Design'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

final class _NoopReminderScheduler implements OrganizerReminderScheduler {
  const _NoopReminderScheduler();

  @override
  Future<void> cancelAssignment(String id) async {}
  @override
  Future<void> cancelEvent(String id) async {}
  @override
  Future<void> cancelExam(String id) async {}
  @override
  Future<void> cancelTask(String id) async {}
  @override
  Future<void> syncAssignment(Assignment assignment) async {}
  @override
  Future<void> syncEvent(TimetableEvent event) async {}
  @override
  Future<void> syncExam(Exam exam) async {}
  @override
  Future<void> syncTask(StudyTask task) async {}
}
