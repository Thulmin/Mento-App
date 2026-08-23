import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mento/app/theme/app_theme.dart';
import 'package:mento/core/services/connectivity_service.dart';
import 'package:mento/data/models/models.dart';
import 'package:mento/data/repositories/repositories.dart';
import 'package:mento/features/academic_organizer/application/academic_organizer_controller.dart';
import 'package:mento/features/academic_organizer/presentation/academic_organizer_screen.dart';
import 'package:mento/features/academic_organizer/presentation/widgets/organizer_item_tile.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('demo academic flow creates a module and completes a task', (
    tester,
  ) async {
    final now = DateTime.now();
    final repository = DemoStudentRepository(
      referenceDate: DateTime(now.year, now.month, now.day),
    );
    addTearDown(repository.dispose);

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
    await tester.pumpAndSettle();

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
    await tester.tap(save);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('organizer-view-modules')));
    await tester.pumpAndSettle();
    expect(find.text('Research Methods'), findsOneWidget);

    await tester.tap(find.byKey(const Key('organizer-view-deadlines')));
    await tester.pumpAndSettle();
    final taskTile = find.ancestor(
      of: find.text('Draft threat model'),
      matching: find.byType(OrganizerItemTile),
    );
    final checkbox = find.descendant(
      of: taskTile,
      matching: find.byType(Checkbox),
    );
    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    final tasks = await repository.watchStudyTasks().first;
    expect(
      tasks.singleWhere((task) => task.id == 'demo-task-security').isCompleted,
      isTrue,
    );
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
