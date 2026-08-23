import 'package:flutter_test/flutter_test.dart';
import 'package:mento/data/models/models.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 1, 12);

  test('Module and Topic round-trip through Firestore-friendly maps', () {
    final module = Module(
      id: 'm1',
      name: 'Mobile Application Development',
      code: 'CMP7003',
      lecturer: 'Dr Lecturer',
      semester: 'Semester 2',
      createdAt: createdAt,
      updatedAt: createdAt,
      topics: [
        Topic(
          id: 't1',
          moduleId: 'm1',
          name: 'State management',
          mastery: 0.65,
          updatedAt: createdAt,
        ),
      ],
    );

    final restored = Module.fromMap(module.toMap());

    expect(restored.code, 'CMP7003');
    expect(restored.topics.single.name, 'State management');
    expect(restored.topics.single.mastery, 0.65);
    expect(restored.createdAt, createdAt);
  });

  test('academic organiser models round-trip nested values and enums', () {
    final event = TimetableEvent(
      id: 'event-1',
      title: 'Laboratory',
      moduleId: 'm1',
      type: EventType.laboratory,
      startAt: DateTime.utc(2026, 1, 5, 9),
      endAt: DateTime.utc(2026, 1, 5, 11),
      recurrence: RecurrenceFrequency.weekly,
      recurringWeekdays: {DateTime.monday},
    );
    final assignment = Assignment(
      id: 'assignment-1',
      moduleId: 'm1',
      title: 'Prototype',
      dueAt: DateTime.utc(2026, 2, 1),
      priority: PriorityLevel.high,
      estimatedMinutes: 300,
      status: WorkStatus.inProgress,
      subtasks: const [Subtask(id: 's1', title: 'Wireframe', order: 1)],
      attachments: [
        AttachmentMetadata(
          id: 'file-1',
          fileName: 'brief.pdf',
          contentType: 'application/pdf',
          sizeBytes: 500,
          objectKey: 'users/u1/brief.pdf',
          createdAt: createdAt,
        ),
      ],
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final exam = Exam(
      id: 'exam-1',
      moduleId: 'm1',
      title: 'Final examination',
      startAt: DateTime.utc(2026, 3, 1, 9),
      endAt: DateTime.utc(2026, 3, 1, 11),
      importance: PriorityLevel.urgent,
      syllabusTopicIds: const ['t1'],
      preparationProgress: 0.4,
    );
    final task = StudyTask(
      id: 'task-1',
      title: 'Practise questions',
      moduleId: 'm1',
      dueAt: DateTime.utc(2026, 2, 20),
      estimatedMinutes: 60,
      priority: PriorityLevel.high,
      status: WorkStatus.notStarted,
      isAiGenerated: true,
    );

    expect(TimetableEvent.fromMap(event.toMap()).type, EventType.laboratory);
    expect(TimetableEvent.fromMap(event.toMap()).recurringWeekdays, {
      DateTime.monday,
    });
    expect(Assignment.fromMap(assignment.toMap()).subtasks.single.id, 's1');
    expect(
      Assignment.fromMap(assignment.toMap()).attachments.single.objectKey,
      'users/u1/brief.pdf',
    );
    expect(Exam.fromMap(exam.toMap()).preparationProgress, 0.4);
    expect(StudyTask.fromMap(task.toMap()).isAiGenerated, isTrue);
  });

  test('study plans preserve source, status, and unplanned workload', () {
    final plan = StudyPlan(
      id: 'p1',
      userId: 'u1',
      generatedAt: createdAt,
      rangeStart: createdAt,
      rangeEnd: createdAt.add(const Duration(days: 7)),
      source: PlanSource.deterministic,
      maxDailyMinutes: 180,
      unplannedMinutes: const {'task-2': 25},
      blocks: [
        PlanBlock(
          id: 'b1',
          startAt: createdAt.add(const Duration(hours: 1)),
          endAt: createdAt.add(const Duration(hours: 2)),
          moduleId: 'm1',
          objective: 'Review notes',
          recommendedMethod: 'Active recall',
          priority: PriorityLevel.medium,
          reason: 'Upcoming assessment',
          source: PlanSource.deterministic,
          status: PlanBlockStatus.accepted,
        ),
      ],
    );

    final restored = StudyPlan.fromMap(plan.toMap());

    expect(restored.blocks.single.status, PlanBlockStatus.accepted);
    expect(restored.unplannedMinutes['task-2'], 25);
  });

  test('habit and wellness models round-trip non-clinical records', () {
    final habit = Habit(
      id: 'h1',
      name: 'Drink water',
      category: HabitCategory.hydration,
      frequency: HabitFrequency.selectedDays,
      weekdays: {1, 3, 5},
      weeklyTarget: 3,
      reminderTimes: const ['09:00'],
      createdAt: createdAt,
    );
    final log = HabitLog(
      id: 'hl1',
      habitId: 'h1',
      date: createdAt,
      loggedAt: createdAt,
    );
    final checkIn = WellnessCheckIn(
      id: 'w1',
      recordedAt: createdAt,
      mood: 4,
      energy: 3,
      sleepHours: 7.5,
    );

    expect(Habit.fromMap(habit.toMap()).weekdays, {1, 3, 5});
    expect(HabitLog.fromMap(log.toMap()).isCompleted, isTrue);
    expect(WellnessCheckIn.fromMap(checkIn.toMap()).sleepHours, 7.5);
  });

  test('profile, preferences, location, and achievement round-trip', () {
    final profile = UserProfile(
      id: 'u1',
      email: 'student@example.edu',
      preferredName: 'Student',
      institution: 'University',
      photoUrl: 'https://example.test/profile.jpg',
      photoSource: 'custom',
      customPhotoPath: 'users/u1/profile/avatar',
      programme: 'Computing',
      academicYear: 4,
      semester: 'Semester 2',
      moduleIds: const ['m1'],
      studyGoals: const ['Finish dissertation'],
      preferences: UserPreferences(
        preferredSessionMinutes: 45,
        theme: ThemePreference.dark,
      ),
      createdAt: createdAt,
      updatedAt: createdAt,
    );
    final location = SavedLocation(
      id: 'l1',
      name: 'Library',
      latitude: 6.9271,
      longitude: 79.8612,
      type: SavedLocationType.library,
      createdAt: createdAt,
    );
    final achievement = Achievement(
      id: 'ach1',
      type: AchievementType.focusedHour,
      title: 'Focused hour',
      description: 'Complete one hour of focus.',
      threshold: 60,
      pointsReward: 20,
      iconName: 'timer',
      progress: 0.75,
    );

    expect(
      UserProfile.fromMap(profile.toMap()).preferences.theme,
      ThemePreference.dark,
    );
    expect(
      UserProfile.fromMap(profile.toMap()).customPhotoPath,
      'users/u1/profile/avatar',
    );
    expect(
      SavedLocation.fromMap(location.toMap()).type,
      SavedLocationType.library,
    );
    expect(Achievement.fromMap(achievement.toMap()).progress, 0.75);
  });

  test(
    'date decoding accepts ISO text, epoch millis, and timestamp-like maps',
    () {
      final base = {
        'id': 'task',
        'title': 'Task',
        'estimatedMinutes': 30,
        'priority': 'medium',
        'status': 'notStarted',
      };
      final fromText = StudyTask.fromMap({
        ...base,
        'dueAt': '2026-01-01T00:00:00Z',
      });
      final fromEpoch = StudyTask.fromMap({...base, 'dueAt': 1767225600000});
      final fromTimestampMap = StudyTask.fromMap({
        ...base,
        'dueAt': {'seconds': 1767225600, 'nanoseconds': 0},
      });

      expect(fromText.dueAt, DateTime.utc(2026, 1, 1));
      expect(fromEpoch.dueAt, DateTime.utc(2026, 1, 1));
      expect(fromTimestampMap.dueAt, DateTime.utc(2026, 1, 1));
    },
  );
}
