// Applies an assistant proposal only after the user has confirmed the change.

import 'package:uuid/uuid.dart';

import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

final class AssistantActionException implements Exception {
  const AssistantActionException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class AssistantActionExecutor {
  const AssistantActionExecutor();

  static const _uuid = Uuid();

  Future<String> apply(
    AiConversationAction action,
    StudentRepository repository,
  ) async {
    if (!action.requiresConfirmation) {
      throw const AssistantActionException(
        'Mento actions must require explicit confirmation.',
      );
    }
    switch (action.resource) {
      case AiActionResource.module:
        return _module(action, repository);
      case AiActionResource.topic:
        return _topic(action, repository);
      case AiActionResource.assignment:
        return _assignment(action, repository);
      case AiActionResource.examination:
        return _examination(action, repository);
      case AiActionResource.studyTask:
        return _studyTask(action, repository);
      case AiActionResource.timetableEvent:
        return _timetableEvent(action, repository);
      case AiActionResource.habit:
        return _habit(action, repository);
    }
  }

  Future<String> _module(
    AiConversationAction action,
    StudentRepository repository,
  ) async {
    _allowOnly(action.payload, {
      'name',
      'code',
      'lecturer',
      'semester',
      'notes',
      'colorHex',
      'priorityWeight',
    });
    if (action.operation == AiActionOperation.delete) {
      final id = _requiredResourceId(action);
      await repository.deleteModule(id);
      return 'Module deleted.';
    }

    final existing =
        action.operation == AiActionOperation.update
            ? await _findById(
              repository.watchModules(),
              _requiredResourceId(action),
              (item) => item.id,
              'module',
            )
            : null;
    final now = DateTime.now();
    final color =
        _optionalText(
          action.payload,
          'colorHex',
          fallback: existing?.colorHex ?? '#247CF8',
        ) ??
        '#247CF8';
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) {
      throw const AssistantActionException(
        'The proposed module colour is invalid.',
      );
    }
    final module = Module(
      id: existing?.id ?? _uuid.v4(),
      name: _requiredOrExistingText(action.payload, 'name', existing?.name),
      code:
          _requiredOrExistingText(
            action.payload,
            'code',
            existing?.code,
          ).toUpperCase(),
      lecturer: _optionalText(
        action.payload,
        'lecturer',
        fallback: existing?.lecturer,
      ),
      semester: _requiredOrExistingText(
        action.payload,
        'semester',
        existing?.semester ?? 'Semester 1',
      ),
      notes: _optionalText(action.payload, 'notes', fallback: existing?.notes),
      colorHex: color.toUpperCase(),
      priorityWeight: _decimal(
        action.payload,
        'priorityWeight',
        fallback: existing?.priorityWeight ?? 1,
        minimum: 0.1,
        maximum: 5,
      ),
      topics: existing?.topics ?? const [],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await repository.saveModule(module);
    return existing == null ? 'Module created.' : 'Module updated.';
  }

  Future<String> _topic(
    AiConversationAction action,
    StudentRepository repository,
  ) async {
    _allowOnly(action.payload, {
      'moduleId',
      'name',
      'description',
      'mastery',
      'completedStudyMinutes',
    });
    if (action.operation == AiActionOperation.delete) {
      await repository.deleteTopic(_requiredResourceId(action));
      return 'Topic deleted.';
    }

    final existing =
        action.operation == AiActionOperation.update
            ? await _findById(
              repository.watchTopics(),
              _requiredResourceId(action),
              (item) => item.id,
              'topic',
            )
            : null;
    final moduleId = _requiredOrExistingText(
      action.payload,
      'moduleId',
      existing?.moduleId,
    );
    await _requireModule(repository, moduleId);
    final topic = Topic(
      id: existing?.id ?? _uuid.v4(),
      moduleId: moduleId,
      name: _requiredOrExistingText(action.payload, 'name', existing?.name),
      description: _optionalText(
        action.payload,
        'description',
        fallback: existing?.description,
      ),
      mastery: _decimal(
        action.payload,
        'mastery',
        fallback: existing?.mastery ?? 0,
        minimum: 0,
        maximum: 1,
      ),
      completedStudyMinutes: _integer(
        action.payload,
        'completedStudyMinutes',
        fallback: existing?.completedStudyMinutes ?? 0,
        minimum: 0,
        maximum: 100000,
      ),
      updatedAt: DateTime.now(),
    );
    await repository.saveTopic(topic);
    return existing == null ? 'Topic created.' : 'Topic updated.';
  }

  Future<String> _assignment(
    AiConversationAction action,
    StudentRepository repository,
  ) async {
    _allowOnly(action.payload, {
      'moduleId',
      'title',
      'description',
      'dueAt',
      'priority',
      'estimatedMinutes',
      'status',
      'manualProgress',
      'reminderAt',
    });
    if (action.operation == AiActionOperation.delete) {
      await repository.deleteAssignment(_requiredResourceId(action));
      return 'Assignment deleted.';
    }

    final existing =
        action.operation == AiActionOperation.update
            ? await _findById(
              repository.watchAssignments(),
              _requiredResourceId(action),
              (item) => item.id,
              'assignment',
            )
            : null;
    final moduleId = _requiredOrExistingText(
      action.payload,
      'moduleId',
      existing?.moduleId,
    );
    await _requireModule(repository, moduleId);
    final now = DateTime.now();
    final assignment = Assignment(
      id: existing?.id ?? _uuid.v4(),
      moduleId: moduleId,
      title: _requiredOrExistingText(action.payload, 'title', existing?.title),
      description: _optionalText(
        action.payload,
        'description',
        fallback: existing?.description,
      ),
      dueAt: _dateTime(action.payload, 'dueAt', fallback: existing?.dueAt),
      priority: _enumValue(
        action.payload,
        'priority',
        PriorityLevel.values,
        fallback: existing?.priority ?? PriorityLevel.medium,
      ),
      estimatedMinutes: _integer(
        action.payload,
        'estimatedMinutes',
        fallback: existing?.estimatedMinutes ?? 120,
        minimum: 0,
        maximum: 60000,
      ),
      status: _enumValue(
        action.payload,
        'status',
        WorkStatus.values,
        fallback: existing?.status ?? WorkStatus.notStarted,
      ),
      subtasks: existing?.subtasks ?? const [],
      manualProgress: _decimal(
        action.payload,
        'manualProgress',
        fallback: existing?.manualProgress ?? 0,
        minimum: 0,
        maximum: 1,
      ),
      reminderAt: _optionalDateTime(
        action.payload,
        'reminderAt',
        fallback: existing?.reminderAt,
      ),
      attachments: existing?.attachments ?? const [],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await repository.saveAssignment(assignment);
    return existing == null ? 'Assignment created.' : 'Assignment updated.';
  }

  Future<String> _examination(
    AiConversationAction action,
    StudentRepository repository,
  ) async {
    _allowOnly(action.payload, {
      'moduleId',
      'title',
      'startAt',
      'endAt',
      'venue',
      'importance',
      'preparationProgress',
      'reminderAt',
      'notes',
    });
    if (action.operation == AiActionOperation.delete) {
      await repository.deleteExam(_requiredResourceId(action));
      return 'Examination deleted.';
    }

    final existing =
        action.operation == AiActionOperation.update
            ? await _findById(
              repository.watchExams(),
              _requiredResourceId(action),
              (item) => item.id,
              'examination',
            )
            : null;
    final moduleId = _requiredOrExistingText(
      action.payload,
      'moduleId',
      existing?.moduleId,
    );
    await _requireModule(repository, moduleId);
    final start = _dateTime(
      action.payload,
      'startAt',
      fallback: existing?.startAt,
    );
    final end = _dateTime(action.payload, 'endAt', fallback: existing?.endAt);
    if (!end.isAfter(start)) {
      throw const AssistantActionException(
        'The examination end time must be after its start time.',
      );
    }
    final exam = Exam(
      id: existing?.id ?? _uuid.v4(),
      moduleId: moduleId,
      title: _requiredOrExistingText(action.payload, 'title', existing?.title),
      startAt: start,
      endAt: end,
      venue: _optionalText(action.payload, 'venue', fallback: existing?.venue),
      syllabusTopicIds: existing?.syllabusTopicIds ?? const [],
      importance: _enumValue(
        action.payload,
        'importance',
        PriorityLevel.values,
        fallback: existing?.importance ?? PriorityLevel.high,
      ),
      preparationProgress: _decimal(
        action.payload,
        'preparationProgress',
        fallback: existing?.preparationProgress ?? 0,
        minimum: 0,
        maximum: 1,
      ),
      reminderAt: _optionalDateTime(
        action.payload,
        'reminderAt',
        fallback: existing?.reminderAt,
      ),
      notes: _optionalText(action.payload, 'notes', fallback: existing?.notes),
    );
    await repository.saveExam(exam);
    return existing == null ? 'Examination created.' : 'Examination updated.';
  }

  Future<String> _studyTask(
    AiConversationAction action,
    StudentRepository repository,
  ) async {
    _allowOnly(action.payload, {
      'title',
      'moduleId',
      'topicId',
      'dueAt',
      'estimatedMinutes',
      'priority',
      'status',
      'plannedStartAt',
      'needsRescheduling',
      'notes',
    });
    if (action.operation == AiActionOperation.delete) {
      await repository.deleteStudyTask(_requiredResourceId(action));
      return 'Study task deleted.';
    }

    final existing =
        action.operation == AiActionOperation.update
            ? await _findById(
              repository.watchStudyTasks(),
              _requiredResourceId(action),
              (item) => item.id,
              'study task',
            )
            : null;
    final moduleId = _optionalText(
      action.payload,
      'moduleId',
      fallback: existing?.moduleId,
    );
    if (moduleId != null) await _requireModule(repository, moduleId);
    final topicId = _optionalText(
      action.payload,
      'topicId',
      fallback: existing?.topicId,
    );
    if (topicId != null) {
      final topic = await _findById(
        repository.watchTopics(),
        topicId,
        (item) => item.id,
        'topic',
      );
      if (moduleId != null && topic.moduleId != moduleId) {
        throw const AssistantActionException(
          'The proposed topic does not belong to the selected module.',
        );
      }
    }
    final status = _enumValue(
      action.payload,
      'status',
      WorkStatus.values,
      fallback: existing?.status ?? WorkStatus.notStarted,
    );
    final task = StudyTask(
      id: existing?.id ?? _uuid.v4(),
      title: _requiredOrExistingText(action.payload, 'title', existing?.title),
      moduleId: moduleId,
      topicId: topicId,
      dueAt: _dateTime(action.payload, 'dueAt', fallback: existing?.dueAt),
      estimatedMinutes: _integer(
        action.payload,
        'estimatedMinutes',
        fallback: existing?.estimatedMinutes ?? 45,
        minimum: 1,
        maximum: 4000,
      ),
      priority: _enumValue(
        action.payload,
        'priority',
        PriorityLevel.values,
        fallback: existing?.priority ?? PriorityLevel.medium,
      ),
      status: status,
      plannedStartAt: _optionalDateTime(
        action.payload,
        'plannedStartAt',
        fallback: existing?.plannedStartAt,
      ),
      isAiGenerated: true,
      needsRescheduling: _boolean(
        action.payload,
        'needsRescheduling',
        fallback: existing?.needsRescheduling ?? false,
      ),
      completedAt:
          status == WorkStatus.completed
              ? (existing?.completedAt ?? DateTime.now())
              : null,
      notes: _optionalText(action.payload, 'notes', fallback: existing?.notes),
    );
    await repository.saveStudyTask(task);
    return existing == null ? 'Study task created.' : 'Study task updated.';
  }

  Future<String> _timetableEvent(
    AiConversationAction action,
    StudentRepository repository,
  ) async {
    _allowOnly(action.payload, {
      'title',
      'moduleId',
      'type',
      'startAt',
      'endAt',
      'location',
      'reminderMinutesBefore',
      'recurrence',
      'recurrenceUntil',
      'recurringWeekdays',
      'notes',
    });
    if (action.operation == AiActionOperation.delete) {
      await repository.deleteTimetableEvent(_requiredResourceId(action));
      return 'Timetable event deleted.';
    }

    final now = DateTime.now();
    final existing =
        action.operation == AiActionOperation.update
            ? await _findById(
              repository.watchTimetableEvents(
                rangeStart: now.subtract(const Duration(days: 3650)),
                rangeEnd: now.add(const Duration(days: 3650)),
              ),
              _requiredResourceId(action),
              (item) => item.id,
              'timetable event',
            )
            : null;
    final moduleId = _optionalText(
      action.payload,
      'moduleId',
      fallback: existing?.moduleId,
    );
    if (moduleId != null) await _requireModule(repository, moduleId);
    final start = _dateTime(
      action.payload,
      'startAt',
      fallback: existing?.startAt,
    );
    final end = _dateTime(action.payload, 'endAt', fallback: existing?.endAt);
    if (!end.isAfter(start)) {
      throw const AssistantActionException(
        'The timetable event end time must be after its start time.',
      );
    }
    final recurrence = _enumValue(
      action.payload,
      'recurrence',
      RecurrenceFrequency.values,
      fallback: existing?.recurrence ?? RecurrenceFrequency.none,
    );
    final event = TimetableEvent(
      id: existing?.id ?? _uuid.v4(),
      title: _requiredOrExistingText(action.payload, 'title', existing?.title),
      moduleId: moduleId,
      type: _enumValue(
        action.payload,
        'type',
        EventType.values,
        fallback: existing?.type ?? EventType.personalStudy,
      ),
      startAt: start,
      endAt: end,
      location: _optionalText(
        action.payload,
        'location',
        fallback: existing?.location,
      ),
      savedLocationId: existing?.savedLocationId,
      latitude: existing?.latitude,
      longitude: existing?.longitude,
      reminderMinutesBefore: _optionalInteger(
        action.payload,
        'reminderMinutesBefore',
        fallback: existing?.reminderMinutesBefore,
        minimum: 0,
        maximum: 10080,
      ),
      recurrence: recurrence,
      recurrenceUntil:
          recurrence == RecurrenceFrequency.none
              ? null
              : _optionalDateTime(
                action.payload,
                'recurrenceUntil',
                fallback: existing?.recurrenceUntil,
              ),
      recurringWeekdays:
          recurrence == RecurrenceFrequency.none
              ? const {}
              : _integerSet(
                action.payload,
                'recurringWeekdays',
                fallback: existing?.recurringWeekdays ?? {start.weekday},
                minimum: 1,
                maximum: 7,
              ),
      notes: _optionalText(action.payload, 'notes', fallback: existing?.notes),
    );
    await repository.saveTimetableEvent(event);
    return existing == null
        ? 'Timetable event created.'
        : 'Timetable event updated.';
  }

  Future<String> _habit(
    AiConversationAction action,
    StudentRepository repository,
  ) async {
    _allowOnly(action.payload, {
      'name',
      'category',
      'frequency',
      'weekdays',
      'weeklyTarget',
      'reminderTimes',
      'isArchived',
      'notes',
    });
    if (action.operation == AiActionOperation.delete) {
      await repository.deleteHabit(_requiredResourceId(action));
      return 'Habit deleted.';
    }

    final existing =
        action.operation == AiActionOperation.update
            ? await _findById(
              repository.watchHabits(includeArchived: true),
              _requiredResourceId(action),
              (item) => item.id,
              'habit',
            )
            : null;
    final habit = Habit(
      id: existing?.id ?? _uuid.v4(),
      name: _requiredOrExistingText(action.payload, 'name', existing?.name),
      category: _enumValue(
        action.payload,
        'category',
        HabitCategory.values,
        fallback: existing?.category ?? HabitCategory.custom,
      ),
      frequency: _enumValue(
        action.payload,
        'frequency',
        HabitFrequency.values,
        fallback: existing?.frequency ?? HabitFrequency.daily,
      ),
      weekdays: _integerSet(
        action.payload,
        'weekdays',
        fallback: existing?.weekdays ?? const {},
        minimum: 1,
        maximum: 7,
      ),
      weeklyTarget: _integer(
        action.payload,
        'weeklyTarget',
        fallback: existing?.weeklyTarget ?? 7,
        minimum: 1,
        maximum: 7,
      ),
      reminderTimes: _stringList(
        action.payload,
        'reminderTimes',
        fallback: existing?.reminderTimes ?? const [],
      ),
      isArchived: _boolean(
        action.payload,
        'isArchived',
        fallback: existing?.isArchived ?? false,
      ),
      notes: _optionalText(action.payload, 'notes', fallback: existing?.notes),
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    await repository.saveHabit(habit);
    return existing == null ? 'Habit created.' : 'Habit updated.';
  }

  Future<void> _requireModule(
    StudentRepository repository,
    String moduleId,
  ) async {
    await _findById(
      repository.watchModules(),
      moduleId,
      (item) => item.id,
      'module',
    );
  }

  Future<T> _findById<T>(
    Stream<List<T>> stream,
    String id,
    String Function(T) idOf,
    String label,
  ) async {
    final items = await stream.first.timeout(const Duration(seconds: 8));
    for (final item in items) {
      if (idOf(item) == id) return item;
    }
    throw AssistantActionException(
      'The $label changed or no longer exists. Ask Mento to refresh.',
    );
  }

  String _requiredResourceId(AiConversationAction action) {
    final id = action.resourceId?.trim();
    if (id == null || id.isEmpty || id.contains('/')) {
      throw const AssistantActionException(
        'The proposed action does not identify a valid existing record.',
      );
    }
    return id;
  }

  void _allowOnly(Map<String, Object?> payload, Set<String> allowed) {
    final unknown =
        payload.keys.where((key) => !allowed.contains(key)).toList();
    if (unknown.isNotEmpty) {
      throw AssistantActionException(
        'Mento proposed unsupported fields: ${unknown.join(', ')}.',
      );
    }
  }

  String _requiredOrExistingText(
    Map<String, Object?> payload,
    String key,
    String? existing,
  ) {
    final value = _optionalText(payload, key, fallback: existing);
    if (value == null || value.isEmpty) {
      throw AssistantActionException('The proposed $key is required.');
    }
    return value;
  }

  String? _optionalText(
    Map<String, Object?> payload,
    String key, {
    String? fallback,
  }) {
    if (!payload.containsKey(key)) return fallback;
    final value = payload[key];
    if (value == null) return null;
    if (value is! String) {
      throw AssistantActionException('The proposed $key must be text.');
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int _integer(
    Map<String, Object?> payload,
    String key, {
    required int fallback,
    required int minimum,
    required int maximum,
  }) {
    if (!payload.containsKey(key)) return fallback;
    final value = payload[key];
    if (value is! num || !value.isFinite || value != value.roundToDouble()) {
      throw AssistantActionException(
        'The proposed $key must be a whole number.',
      );
    }
    final result = value.toInt();
    if (result < minimum || result > maximum) {
      throw AssistantActionException(
        'The proposed $key must be between $minimum and $maximum.',
      );
    }
    return result;
  }

  int? _optionalInteger(
    Map<String, Object?> payload,
    String key, {
    required int? fallback,
    required int minimum,
    required int maximum,
  }) {
    if (!payload.containsKey(key)) return fallback;
    if (payload[key] == null) return null;
    return _integer(
      payload,
      key,
      fallback: fallback ?? minimum,
      minimum: minimum,
      maximum: maximum,
    );
  }

  double _decimal(
    Map<String, Object?> payload,
    String key, {
    required double fallback,
    required double minimum,
    required double maximum,
  }) {
    if (!payload.containsKey(key)) return fallback;
    final value = payload[key];
    if (value is! num || !value.isFinite) {
      throw AssistantActionException('The proposed $key must be a number.');
    }
    final result = value.toDouble();
    if (result < minimum || result > maximum) {
      throw AssistantActionException(
        'The proposed $key must be between $minimum and $maximum.',
      );
    }
    return result;
  }

  bool _boolean(
    Map<String, Object?> payload,
    String key, {
    required bool fallback,
  }) {
    if (!payload.containsKey(key)) return fallback;
    final value = payload[key];
    if (value is! bool) {
      throw AssistantActionException(
        'The proposed $key must be true or false.',
      );
    }
    return value;
  }

  DateTime _dateTime(
    Map<String, Object?> payload,
    String key, {
    DateTime? fallback,
  }) {
    if (!payload.containsKey(key)) {
      if (fallback != null) return fallback;
      throw AssistantActionException('The proposed $key is required.');
    }
    final value = payload[key];
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null) {
      throw AssistantActionException(
        'The proposed $key must be an ISO-8601 date and time.',
      );
    }
    return parsed;
  }

  DateTime? _optionalDateTime(
    Map<String, Object?> payload,
    String key, {
    DateTime? fallback,
  }) {
    if (!payload.containsKey(key)) return fallback;
    if (payload[key] == null) return null;
    return _dateTime(payload, key, fallback: fallback);
  }

  T _enumValue<T extends Enum>(
    Map<String, Object?> payload,
    String key,
    List<T> values, {
    required T fallback,
  }) {
    if (!payload.containsKey(key)) return fallback;
    final raw = payload[key];
    if (raw is String) {
      for (final value in values) {
        if (value.name == raw) return value;
      }
    }
    throw AssistantActionException('The proposed $key is not supported.');
  }

  Set<int> _integerSet(
    Map<String, Object?> payload,
    String key, {
    required Set<int> fallback,
    required int minimum,
    required int maximum,
  }) {
    if (!payload.containsKey(key)) return fallback;
    final raw = payload[key];
    if (raw is! List) {
      throw AssistantActionException('The proposed $key must be a list.');
    }
    final values = <int>{};
    for (final item in raw) {
      if (item is! num || !item.isFinite || item != item.roundToDouble()) {
        throw AssistantActionException(
          'The proposed $key must contain whole numbers.',
        );
      }
      final value = item.toInt();
      if (value < minimum || value > maximum) {
        throw AssistantActionException(
          'The proposed $key contains an unsupported value.',
        );
      }
      values.add(value);
    }
    return values;
  }

  List<String> _stringList(
    Map<String, Object?> payload,
    String key, {
    required List<String> fallback,
  }) {
    if (!payload.containsKey(key)) return fallback;
    final raw = payload[key];
    if (raw is! List || raw.any((item) => item is! String)) {
      throw AssistantActionException(
        'The proposed $key must contain only text.',
      );
    }
    return raw.cast<String>().map((item) => item.trim()).toList();
  }
}
