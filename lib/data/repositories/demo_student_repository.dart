// Supplies repeatable in-memory student data for demos and offline exploration.

import 'dart:async';

import '../models/models.dart';
import 'student_repository.dart';

/// Deterministic, memory-only showcase data. Nothing in this repository can
/// write to Firebase. IDs and content are fixed; dates are anchored to the
/// start of the week containing [referenceDate].
final class DemoStudentRepository implements StudentRepository {
  DemoStudentRepository({
    DateTime? referenceDate,
    this.ownerId = 'demo-student',
  }) : seedAnchor = _dateOnly(referenceDate ?? DateTime.now()) {
    if (ownerId.trim().isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Cannot be empty.');
    }
    _seed();
  }

  final DateTime seedAnchor;
  @override
  final String ownerId;
  final StreamController<void> _changes = StreamController.broadcast(
    sync: true,
  );
  var _idCounter = 1000;

  final Map<String, Module> _modules = {};
  final Map<String, Topic> _topics = {};
  final Map<String, TimetableEvent> _events = {};
  final Map<String, Assignment> _assignments = {};
  final Map<String, Exam> _exams = {};
  final Map<String, StudyTask> _tasks = {};
  final Map<String, StudyPlan> _plans = {};
  final Map<String, FocusSession> _focusSessions = {};
  final Map<String, Habit> _habits = {};
  final Map<String, HabitLog> _habitLogs = {};
  final Map<String, WellnessCheckIn> _wellness = {};
  final Map<String, Achievement> _achievements = {};
  final Map<String, TopicMasteryRecord> _mastery = {};
  final Map<String, SavedLocation> _locations = {};
  final Map<String, AiConversation> _aiConversations = {};

  @override
  bool get isDemo => true;

  @override
  String get dataOriginLabel =>
      'Demo data — stored in memory only and never written to Firebase';

  String createId(String prefix) => '$prefix-${_idCounter++}';

  void dispose() => _changes.close();

  @override
  Stream<List<Module>> watchModules({int limit = 100}) => _stream(() {
    final modules =
        _modules.values.map((module) {
            final topics =
                _topics.values
                    .where((topic) => topic.moduleId == module.id)
                    .toList()
                  ..sort((a, b) => a.name.compareTo(b.name));
            return module.copyWith(topics: topics);
          }).toList()
          ..sort((a, b) => a.code.compareTo(b.code));
    return _take(modules, limit);
  });

  @override
  Stream<List<Topic>> watchTopics({String? moduleId, int limit = 250}) =>
      _stream(() {
        final topics =
            _topics.values
                .where(
                  (topic) => moduleId == null || topic.moduleId == moduleId,
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        return _take(topics, limit);
      });

  @override
  Future<void> saveModule(Module module) async {
    _requireId(module.id);
    _modules[module.id] = module;
    for (final topic in module.topics) {
      _topics[topic.id] = topic;
    }
    _notify();
  }

  @override
  Future<void> deleteModule(String moduleId, {bool cascade = false}) async {
    final linked =
        _topics.values.any((item) => item.moduleId == moduleId) ||
        _events.values.any((item) => item.moduleId == moduleId) ||
        _assignments.values.any((item) => item.moduleId == moduleId) ||
        _exams.values.any((item) => item.moduleId == moduleId) ||
        _tasks.values.any((item) => item.moduleId == moduleId);
    if (linked && !cascade) {
      throw const StudentRepositoryConflictException(
        'This module is linked to topics or academic work. Delete those '
        'items first, or explicitly confirm a cascading delete.',
      );
    }
    _modules.remove(moduleId);
    if (cascade) {
      _topics.removeWhere((_, item) => item.moduleId == moduleId);
      _events.removeWhere((_, item) => item.moduleId == moduleId);
      _assignments.removeWhere((_, item) => item.moduleId == moduleId);
      _exams.removeWhere((_, item) => item.moduleId == moduleId);
      _tasks.removeWhere((_, item) => item.moduleId == moduleId);
      _mastery.removeWhere((_, item) => item.moduleId == moduleId);
    }
    _notify();
  }

  @override
  Future<void> saveTopic(Topic topic) async {
    if (!_modules.containsKey(topic.moduleId)) {
      throw const StudentRepositoryConflictException(
        'Choose an existing module before saving this topic.',
      );
    }
    _topics[topic.id] = topic;
    _notify();
  }

  @override
  Future<void> deleteTopic(String topicId) async {
    _topics.remove(topicId);
    _mastery.remove(topicId);
    _notify();
  }

  @override
  Stream<List<TimetableEvent>> watchTimetableEvents({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    int limit = 250,
  }) {
    _requireRange(rangeStart, rangeEnd);
    return _stream(() {
      final events =
          _events.values.where((event) {
              if (event.recurrence == RecurrenceFrequency.none) {
                return event.startAt.isBefore(rangeEnd) &&
                    event.endAt.isAfter(rangeStart);
              }
              return event.startAt.isBefore(rangeEnd) &&
                  (event.recurrenceUntil == null ||
                      !event.recurrenceUntil!.isBefore(rangeStart));
            }).toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
      return _take(events, limit);
    });
  }

  @override
  Future<void> saveTimetableEvent(TimetableEvent event) async {
    _events[event.id] = event;
    _notify();
  }

  @override
  Future<void> deleteTimetableEvent(String eventId) async {
    _events.remove(eventId);
    _notify();
  }

  @override
  Stream<List<Assignment>> watchAssignments({
    DateTime? dueFrom,
    DateTime? dueBefore,
    bool includeCompleted = true,
    int limit = 100,
  }) => _stream(() {
    final assignments =
        _assignments.values.where((item) {
            return (dueFrom == null || !item.dueAt.isBefore(dueFrom)) &&
                (dueBefore == null || item.dueAt.isBefore(dueBefore)) &&
                (includeCompleted || item.status != WorkStatus.completed);
          }).toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return _take(assignments, limit);
  });

  @override
  Future<StudentPage<Assignment>> loadAssignmentPage({
    int limit = 25,
    String? afterCursor,
  }) async {
    final values =
        _assignments.values.toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return _page(values, (item) => item.id, limit, afterCursor);
  }

  @override
  Future<void> saveAssignment(Assignment assignment) async {
    _assignments[assignment.id] = assignment;
    _notify();
  }

  @override
  Future<void> deleteAssignment(String assignmentId) async {
    _assignments.remove(assignmentId);
    _notify();
  }

  @override
  Stream<List<Exam>> watchExams({
    DateTime? from,
    DateTime? before,
    int limit = 100,
  }) => _stream(() {
    final exams =
        _exams.values.where((item) {
            return (from == null || !item.startAt.isBefore(from)) &&
                (before == null || item.startAt.isBefore(before));
          }).toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return _take(exams, limit);
  });

  @override
  Future<void> saveExam(Exam exam) async {
    _exams[exam.id] = exam;
    _notify();
  }

  @override
  Future<void> deleteExam(String examId) async {
    _exams.remove(examId);
    _notify();
  }

  @override
  Stream<List<StudyTask>> watchStudyTasks({
    DateTime? dueFrom,
    DateTime? dueBefore,
    bool includeCompleted = true,
    int limit = 150,
  }) => _stream(() {
    final tasks =
        _tasks.values.where((item) {
            return (dueFrom == null || !item.dueAt.isBefore(dueFrom)) &&
                (dueBefore == null || item.dueAt.isBefore(dueBefore)) &&
                (includeCompleted || !item.isCompleted);
          }).toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return _take(tasks, limit);
  });

  @override
  Future<StudentPage<StudyTask>> loadStudyTaskPage({
    int limit = 25,
    String? afterCursor,
  }) async {
    final values =
        _tasks.values.toList()..sort((a, b) => a.dueAt.compareTo(b.dueAt));
    return _page(values, (item) => item.id, limit, afterCursor);
  }

  @override
  Future<void> saveStudyTask(StudyTask task) async {
    _tasks[task.id] = task;
    _notify();
  }

  @override
  Future<void> setStudyTaskCompleted(
    String taskId, {
    required bool completed,
  }) async {
    final task = _tasks[taskId];
    if (task == null) {
      throw const StudentRepositoryException(
        'The study task no longer exists.',
      );
    }
    _tasks[taskId] = StudyTask(
      id: task.id,
      title: task.title,
      moduleId: task.moduleId,
      topicId: task.topicId,
      dueAt: task.dueAt,
      estimatedMinutes: task.estimatedMinutes,
      priority: task.priority,
      status: completed ? WorkStatus.completed : WorkStatus.inProgress,
      plannedStartAt: task.plannedStartAt,
      isAiGenerated: task.isAiGenerated,
      needsRescheduling: task.needsRescheduling,
      completedAt: completed ? DateTime.now() : null,
      notes: task.notes,
    );
    _notify();
  }

  @override
  Future<void> deleteStudyTask(String taskId) async {
    _tasks.remove(taskId);
    _notify();
  }

  @override
  Stream<List<StudyPlan>> watchStudyPlans({int limit = 20}) => _stream(() {
    final plans =
        _plans.values.toList()
          ..sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return _take(plans, limit);
  });

  @override
  Future<void> saveStudyPlan(StudyPlan plan) async {
    if (plan.userId != ownerId) {
      throw const StudentRepositoryException(
        'A study plan cannot be assigned to another account.',
      );
    }
    _plans[plan.id] = plan;
    _notify();
  }

  @override
  Future<void> deleteStudyPlan(String planId) async {
    _plans.remove(planId);
    _notify();
  }

  @override
  Stream<List<FocusSession>> watchFocusSessions({int limit = 100}) =>
      _stream(() {
        final values =
            _focusSessions.values.toList()
              ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
        return _take(values, limit);
      });

  @override
  Future<StudentPage<FocusSession>> loadFocusSessionPage({
    int limit = 25,
    String? afterCursor,
  }) async {
    final values =
        _focusSessions.values.toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return _page(values, (item) => item.id, limit, afterCursor);
  }

  @override
  Future<void> saveFocusSession(FocusSession session) async {
    _focusSessions[session.id] = session;
    _notify();
  }

  @override
  Future<void> deleteFocusSession(String sessionId) async {
    _focusSessions.remove(sessionId);
    _notify();
  }

  @override
  Stream<List<Habit>> watchHabits({
    bool includeArchived = false,
    int limit = 100,
  }) => _stream(() {
    final values =
        _habits.values
            .where((habit) => includeArchived || !habit.isArchived)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    return _take(values, limit);
  });

  @override
  Future<void> saveHabit(Habit habit) async {
    _habits[habit.id] = habit;
    _notify();
  }

  @override
  Future<void> deleteHabit(String habitId) async {
    _habits.remove(habitId);
    _habitLogs.removeWhere((_, log) => log.habitId == habitId);
    _notify();
  }

  @override
  Stream<List<HabitLog>> watchHabitLogs({
    DateTime? from,
    DateTime? before,
    int limit = 250,
  }) => _stream(() {
    final values =
        _habitLogs.values.where((log) {
            return (from == null || !log.date.isBefore(from)) &&
                (before == null || log.date.isBefore(before));
          }).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return _take(values, limit);
  });

  @override
  Future<void> saveHabitLog(HabitLog log) async {
    _habitLogs[log.id] = log;
    _notify();
  }

  @override
  Future<void> deleteHabitLog(String logId) async {
    _habitLogs.remove(logId);
    _notify();
  }

  @override
  Stream<List<WellnessCheckIn>> watchWellnessCheckIns({int limit = 90}) =>
      _stream(() {
        final values =
            _wellness.values.toList()
              ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        return _take(values, limit);
      });

  @override
  Future<void> saveWellnessCheckIn(WellnessCheckIn checkIn) async {
    _wellness[checkIn.id] = checkIn;
    _notify();
  }

  @override
  Future<void> deleteWellnessCheckIn(String checkInId) async {
    _wellness.remove(checkInId);
    _notify();
  }

  @override
  Stream<List<Achievement>> watchAchievements({int limit = 100}) => _stream(() {
    final values =
        _achievements.values.toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    return _take(values, limit);
  });

  @override
  Future<void> saveAchievement(Achievement achievement) async {
    _achievements[achievement.id] = achievement;
    _notify();
  }

  @override
  Future<void> deleteAchievement(String achievementId) async {
    _achievements.remove(achievementId);
    _notify();
  }

  @override
  Stream<List<TopicMasteryRecord>> watchTopicMastery({
    String? moduleId,
    int limit = 250,
  }) => _stream(() {
    final values =
        _mastery.values
            .where((record) => moduleId == null || record.moduleId == moduleId)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _take(values, limit);
  });

  @override
  Future<void> saveTopicMastery(TopicMasteryRecord record) async {
    _mastery[record.topicId] = record;
    _notify();
  }

  @override
  Stream<List<SavedLocation>> watchSavedLocations({int limit = 100}) =>
      _stream(() {
        final values =
            _locations.values.toList()
              ..sort((a, b) => a.name.compareTo(b.name));
        return _take(values, limit);
      });

  @override
  Future<void> saveSavedLocation(SavedLocation location) async {
    _locations[location.id] = location;
    _notify();
  }

  @override
  Future<void> deleteSavedLocation(String locationId) async {
    _locations.remove(locationId);
    _notify();
  }

  @override
  Stream<List<AiConversation>> watchAiConversations({
    bool includeArchived = false,
    int limit = 30,
  }) => _stream(() {
    final values =
        _aiConversations.values
            .where((conversation) => includeArchived || !conversation.archived)
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return _take(values, limit);
  });

  @override
  Future<void> saveAiConversation(AiConversation conversation) async {
    _aiConversations[conversation.id] = conversation;
    _notify();
  }

  @override
  Future<void> deleteAiConversation(String conversationId) async {
    _aiConversations.remove(conversationId);
    _notify();
  }

  Stream<List<T>> _stream<T>(List<T> Function() snapshot) async* {
    yield List.unmodifiable(snapshot());
    yield* _changes.stream.map((_) => List.unmodifiable(snapshot()));
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }

  void _seed() {
    final now = seedAnchor.add(const Duration(hours: 12));
    final monday = seedAnchor.subtract(
      Duration(days: seedAnchor.weekday - DateTime.monday),
    );
    DateTime at(int dayOffset, int hour, [int minute = 0]) => DateTime(
      monday.year,
      monday.month,
      monday.day + dayOffset,
      hour,
      minute,
    );

    _modules.addAll({
      'demo-cs101': Module(
        id: 'demo-cs101',
        name: 'Mobile Application Engineering',
        code: 'CSE 401',
        lecturer: 'Dr. Maya Silva',
        semester: 'Semester 2',
        colorHex: '#247CF8',
        notes: 'Flutter, mobile architecture and platform integration.',
        priorityWeight: 1.3,
        createdAt: now.subtract(const Duration(days: 70)),
        updatedAt: now,
      ),
      'demo-ai201': Module(
        id: 'demo-ai201',
        name: 'Applied Artificial Intelligence',
        code: 'AI 420',
        lecturer: 'Prof. N. Fernando',
        semester: 'Semester 2',
        colorHex: '#7651F8',
        priorityWeight: 1.4,
        createdAt: now.subtract(const Duration(days: 70)),
        updatedAt: now,
      ),
      'demo-ds301': Module(
        id: 'demo-ds301',
        name: 'Data Systems',
        code: 'CSE 415',
        lecturer: 'Ms. Amara Perera',
        semester: 'Semester 2',
        colorHex: '#28B8FC',
        priorityWeight: 1.1,
        createdAt: now.subtract(const Duration(days: 70)),
        updatedAt: now,
      ),
      'demo-ux110': Module(
        id: 'demo-ux110',
        name: 'Human-centred Design',
        code: 'UX 310',
        lecturer: 'Mr. Liam Jayasinghe',
        semester: 'Semester 2',
        colorHex: '#A966FB',
        createdAt: now.subtract(const Duration(days: 70)),
        updatedAt: now,
      ),
    });

    void topic(String id, String moduleId, String name, double mastery) {
      _topics[id] = Topic(
        id: id,
        moduleId: moduleId,
        name: name,
        mastery: mastery,
        completedStudyMinutes: (mastery * 360).round(),
        updatedAt: now,
      );
      _mastery[id] = TopicMasteryRecord(
        topicId: id,
        moduleId: moduleId,
        mastery: mastery,
        studyMinutes: (mastery * 360).round(),
        completedTasks: (mastery * 6).round(),
        updatedAt: now,
      );
    }

    topic('demo-topic-flutter', 'demo-cs101', 'Adaptive Flutter UI', 0.72);
    topic('demo-topic-mobile-arch', 'demo-cs101', 'Mobile architecture', 0.58);
    topic('demo-topic-ml', 'demo-ai201', 'Model evaluation', 0.46);
    topic('demo-topic-responsible-ai', 'demo-ai201', 'Responsible AI', 0.64);
    topic('demo-topic-firestore', 'demo-ds301', 'Document databases', 0.81);
    topic('demo-topic-research', 'demo-ux110', 'User research', 0.69);

    void weeklyEvent({
      required String id,
      required String title,
      required String moduleId,
      required EventType type,
      required int day,
      required int hour,
      required int durationMinutes,
      required String location,
    }) {
      final start = at(day, hour);
      _events[id] = TimetableEvent(
        id: id,
        title: title,
        moduleId: moduleId,
        type: type,
        startAt: start,
        endAt: start.add(Duration(minutes: durationMinutes)),
        location: location,
        reminderMinutesBefore: 20,
        recurrence: RecurrenceFrequency.weekly,
        recurringWeekdays: {start.weekday},
      );
    }

    weeklyEvent(
      id: 'demo-event-mobile',
      title: 'Mobile Engineering lecture',
      moduleId: 'demo-cs101',
      type: EventType.lecture,
      day: 0,
      hour: 9,
      durationMinutes: 120,
      location: 'Innovation Building · 2.14',
    );
    weeklyEvent(
      id: 'demo-event-ai',
      title: 'AI laboratory',
      moduleId: 'demo-ai201',
      type: EventType.laboratory,
      day: 1,
      hour: 13,
      durationMinutes: 120,
      location: 'Computing Lab 3',
    );
    weeklyEvent(
      id: 'demo-event-data',
      title: 'Data Systems tutorial',
      moduleId: 'demo-ds301',
      type: EventType.tutorial,
      day: 2,
      hour: 10,
      durationMinutes: 90,
      location: 'Library seminar room',
    );
    weeklyEvent(
      id: 'demo-event-ux',
      title: 'Design studio',
      moduleId: 'demo-ux110',
      type: EventType.seminar,
      day: 3,
      hour: 14,
      durationMinutes: 120,
      location: 'Design Studio',
    );

    _assignments['demo-assignment-mobile'] = Assignment(
      id: 'demo-assignment-mobile',
      moduleId: 'demo-cs101',
      title: 'Mento architecture report',
      description: 'Explain the mobile, Firebase and secure AI architecture.',
      dueAt: now.add(const Duration(days: 5, hours: 5)),
      priority: PriorityLevel.urgent,
      estimatedMinutes: 480,
      status: WorkStatus.inProgress,
      subtasks: [
        const Subtask(
          id: 'demo-subtask-1',
          title: 'System context diagram',
          isCompleted: true,
          estimatedMinutes: 60,
          order: 0,
        ),
        const Subtask(
          id: 'demo-subtask-2',
          title: 'Security analysis',
          estimatedMinutes: 120,
          order: 1,
        ),
      ],
      manualProgress: 0.35,
      reminderAt: now.add(const Duration(days: 4)),
      createdAt: now.subtract(const Duration(days: 14)),
      updatedAt: now,
    );
    _assignments['demo-assignment-ux'] = Assignment(
      id: 'demo-assignment-ux',
      moduleId: 'demo-ux110',
      title: 'Usability evaluation',
      description: 'Run five moderated tasks and synthesise findings.',
      dueAt: now.add(const Duration(days: 12, hours: 3)),
      priority: PriorityLevel.high,
      estimatedMinutes: 360,
      status: WorkStatus.notStarted,
      manualProgress: 0,
      reminderAt: now.add(const Duration(days: 10)),
      createdAt: now.subtract(const Duration(days: 7)),
      updatedAt: now,
    );

    _exams['demo-exam-ai'] = Exam(
      id: 'demo-exam-ai',
      moduleId: 'demo-ai201',
      title: 'Applied AI final examination',
      startAt: now.add(const Duration(days: 20)),
      endAt: now.add(const Duration(days: 20, hours: 2)),
      venue: 'Examination Hall B',
      syllabusTopicIds: const ['demo-topic-ml', 'demo-topic-responsible-ai'],
      importance: PriorityLevel.urgent,
      preparationProgress: 0.42,
      reminderAt: now.add(const Duration(days: 18)),
    );

    void task(
      String id,
      String title,
      String moduleId,
      int days,
      PriorityLevel priority, {
      bool complete = false,
      bool ai = false,
    }) {
      _tasks[id] = StudyTask(
        id: id,
        title: title,
        moduleId: moduleId,
        dueAt: now.add(Duration(days: days)),
        estimatedMinutes: 50,
        priority: priority,
        status: complete ? WorkStatus.completed : WorkStatus.notStarted,
        plannedStartAt: now.add(Duration(days: days - 1, hours: 2)),
        isAiGenerated: ai,
        completedAt: complete ? now.subtract(const Duration(days: 1)) : null,
      );
    }

    task(
      'demo-task-security',
      'Draft threat model',
      'demo-cs101',
      2,
      PriorityLevel.urgent,
      ai: true,
    );
    task(
      'demo-task-ai-cards',
      'Create AI revision cards',
      'demo-ai201',
      3,
      PriorityLevel.high,
    );
    task(
      'demo-task-db',
      'Review Firestore query indexes',
      'demo-ds301',
      4,
      PriorityLevel.medium,
      ai: true,
    );
    task(
      'demo-task-interviews',
      'Prepare interview guide',
      'demo-ux110',
      -1,
      PriorityLevel.medium,
      complete: true,
    );

    _habits.addAll({
      'demo-habit-water': Habit(
        id: 'demo-habit-water',
        name: 'Hydration check',
        category: HabitCategory.hydration,
        frequency: HabitFrequency.daily,
        createdAt: now.subtract(const Duration(days: 30)),
        reminderTimes: const ['10:00', '15:00'],
      ),
      'demo-habit-walk': Habit(
        id: 'demo-habit-walk',
        name: 'Campus walk',
        category: HabitCategory.movement,
        frequency: HabitFrequency.weekdays,
        weekdays: const {1, 2, 3, 4, 5},
        weeklyTarget: 5,
        createdAt: now.subtract(const Duration(days: 24)),
      ),
      'demo-habit-reading': Habit(
        id: 'demo-habit-reading',
        name: 'Read away from screens',
        category: HabitCategory.reading,
        frequency: HabitFrequency.timesPerWeek,
        weeklyTarget: 3,
        createdAt: now.subtract(const Duration(days: 18)),
      ),
    });
    for (var index = 0; index < 5; index++) {
      final date = now.subtract(Duration(days: index));
      _habitLogs['demo-habit-log-$index'] = HabitLog(
        id: 'demo-habit-log-$index',
        habitId: index.isEven ? 'demo-habit-water' : 'demo-habit-walk',
        date: _dateOnly(date),
        loggedAt: date,
      );
    }

    for (var index = 0; index < 4; index++) {
      final start = now.subtract(Duration(days: index + 1, hours: 2));
      _focusSessions['demo-focus-$index'] = FocusSession(
        id: 'demo-focus-$index',
        moduleId: index.isEven ? 'demo-cs101' : 'demo-ai201',
        goal: index.isEven ? 'Architecture report' : 'AI revision',
        targetMinutes: index == 0 ? 50 : 25,
        startedAt: start,
        state: FocusSessionState.completed,
        accumulatedActiveSeconds: (index == 0 ? 48 : 25) * 60,
        accumulatedPausedSeconds: index * 45,
        endedAt: start.add(Duration(minutes: index == 0 ? 51 : 26)),
      );
    }

    _achievements.addAll({
      'demo-achievement-focus': Achievement(
        id: 'demo-achievement-focus',
        type: AchievementType.firstFocusSession,
        title: 'Focused beginning',
        description: 'Complete the first intentional focus session.',
        threshold: 1,
        pointsReward: 50,
        iconName: 'timer',
        progress: 1,
        unlockedAt: now.subtract(const Duration(days: 6)),
      ),
      'demo-achievement-streak': Achievement(
        id: 'demo-achievement-streak',
        type: AchievementType.sevenDayStreak,
        title: 'Steady week',
        description: 'Make meaningful progress on seven consecutive days.',
        threshold: 7,
        pointsReward: 150,
        iconName: 'local_fire_department',
        progress: 0.71,
      ),
    });

    _wellness['demo-wellness'] = WellnessCheckIn(
      id: 'demo-wellness',
      recordedAt: now.subtract(const Duration(hours: 3)),
      mood: 4,
      energy: 3,
      sleepHours: 7.2,
      note: 'A steady day; keep the evening workload light.',
    );

    _locations.addAll({
      'demo-location-library': SavedLocation(
        id: 'demo-location-library',
        name: 'Main Library',
        address: 'University campus',
        latitude: 6.9271,
        longitude: 79.8612,
        type: SavedLocationType.library,
        isFavorite: true,
        createdAt: now.subtract(const Duration(days: 20)),
      ),
      'demo-location-lab': SavedLocation(
        id: 'demo-location-lab',
        name: 'Computing Lab 3',
        latitude: 6.9265,
        longitude: 79.8620,
        type: SavedLocationType.campus,
        createdAt: now.subtract(const Duration(days: 16)),
      ),
    });

    final planStart = now.add(const Duration(days: 1, hours: 1));
    _plans['demo-plan'] = StudyPlan(
      id: 'demo-plan',
      userId: ownerId,
      generatedAt: now,
      rangeStart: seedAnchor,
      rangeEnd: seedAnchor.add(const Duration(days: 7)),
      source: PlanSource.deterministic,
      maxDailyMinutes: 240,
      rationale: 'Demo fallback plan based on deadlines and available time.',
      blocks: [
        PlanBlock(
          id: 'demo-plan-block',
          startAt: planStart,
          endAt: planStart.add(const Duration(minutes: 50)),
          moduleId: 'demo-cs101',
          topicId: 'demo-topic-mobile-arch',
          linkedTaskId: 'demo-task-security',
          objective: 'Draft the Mento threat model',
          recommendedMethod: 'Structured outline followed by risk ranking',
          breakMinutes: 10,
          priority: PriorityLevel.urgent,
          reason: 'The linked report deadline is approaching.',
          source: PlanSource.deterministic,
          status: PlanBlockStatus.accepted,
        ),
      ],
      isAccepted: true,
    );
  }

  static StudentPage<T> _page<T>(
    List<T> values,
    String Function(T) idOf,
    int limit,
    String? afterCursor,
  ) {
    final pageSize = limit.clamp(1, 100);
    var start = 0;
    if (afterCursor != null) {
      final index = values.indexWhere((value) => idOf(value) == afterCursor);
      if (index < 0) {
        throw const StudentRepositoryException(
          'The requested page cursor has expired. Refresh the list.',
        );
      }
      start = index + 1;
    }
    final end = (start + pageSize).clamp(0, values.length);
    final items = values.sublist(start.clamp(0, values.length), end);
    return StudentPage(
      items: List.unmodifiable(items),
      nextCursor:
          end < values.length && items.isNotEmpty ? idOf(items.last) : null,
    );
  }

  static List<T> _take<T>(List<T> values, int limit) =>
      List.unmodifiable(values.take(limit.clamp(1, 500)));

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static void _requireRange(DateTime start, DateTime end) {
    if (!end.isAfter(start)) {
      throw ArgumentError.value(end, 'rangeEnd', 'Must be after rangeStart.');
    }
  }

  static void _requireId(String id) {
    if (id.trim().isEmpty || id.contains('/')) {
      throw ArgumentError.value(id, 'id', 'Must be a non-empty document ID.');
    }
  }
}
