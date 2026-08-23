// Stores each signed-in student's data inside their private Firestore area.

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import 'student_repository.dart';

/// Production repository. Every document lives below `users/{uid}` and also
/// carries an immutable ownerId for rules validation and export safety.
final class FirestoreStudentRepository implements StudentRepository {
  FirestoreStudentRepository({
    required String ownerId,
    FirebaseFirestore? firestore,
  }) : _ownerId = ownerId.trim(),
       _firestore = firestore ?? FirebaseFirestore.instance {
    if (_ownerId.isEmpty) {
      throw ArgumentError.value(ownerId, 'ownerId', 'Cannot be empty.');
    }
  }

  final FirebaseFirestore _firestore;
  final String _ownerId;

  @override
  String get ownerId => _ownerId;

  @override
  bool get isDemo => false;

  @override
  String get dataOriginLabel => 'Synced with your private Firebase account';

  DocumentReference<Map<String, dynamic>> get _user =>
      _firestore.collection('users').doc(_ownerId);

  CollectionReference<Map<String, dynamic>> _collection(String name) =>
      _user.collection(name);

  @override
  Stream<List<Module>> watchModules({int limit = 100}) => _watch(
    _collection('modules').orderBy('code').limit(_safeLimit(limit)),
    _decodeModule,
  );

  Module _decodeModule(QueryDocumentSnapshot<Map<String, dynamic>> document) {
    final map = _documentMap(document);
    final code = map['code'];
    if (code is! String || code.trim().isEmpty) {
      final suffix =
          document.id
              .replaceAll(RegExp('[^A-Za-z0-9]'), '')
              .padRight(4, '0')
              .substring(0, 4)
              .toUpperCase();
      map['code'] = 'MOD-$suffix';
    }
    final semester = map['semester'];
    if (semester is num) map['semester'] = 'Semester ${semester.toInt()}';
    if (map['colorHex'] == null && map['colorValue'] is num) {
      final value = (map['colorValue'] as num).toInt() & 0xFFFFFF;
      map['colorHex'] =
          '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
    }
    return Module.fromMap(map, id: document.id);
  }

  @override
  Stream<List<Topic>> watchTopics({String? moduleId, int limit = 250}) {
    Query<Map<String, dynamic>> query = _collection('topics').orderBy('name');
    if (moduleId != null) query = query.where('moduleId', isEqualTo: moduleId);
    return _watch(
      query.limit(_safeLimit(limit)),
      (doc) => Topic.fromMap(_documentMap(doc), id: doc.id),
    );
  }

  @override
  Future<void> saveModule(Module module) async {
    final map = Map<String, Object?>.from(module.toMap())..remove('topics');
    await _upsert(
      'modules',
      module.id,
      map,
      serverCreatedAt: true,
      serverUpdatedAt: true,
    );
  }

  @override
  Future<void> deleteModule(String moduleId, {bool cascade = false}) async {
    final dependencies = <Query<Map<String, dynamic>>>[
      _collection('topics').where('moduleId', isEqualTo: moduleId),
      _collection('timetableEvents').where('moduleId', isEqualTo: moduleId),
      _collection('assignments').where('moduleId', isEqualTo: moduleId),
      _collection('examinations').where('moduleId', isEqualTo: moduleId),
      _collection('studyTasks').where('moduleId', isEqualTo: moduleId),
    ];
    if (!cascade) {
      final checks = await Future.wait(
        dependencies.map((query) => query.limit(1).get()),
      );
      if (checks.any((snapshot) => snapshot.docs.isNotEmpty)) {
        throw const StudentRepositoryConflictException(
          'This module is linked to topics or academic work. Delete those '
          'items first, or explicitly confirm a cascading delete.',
        );
      }
      await _delete('modules', moduleId);
      return;
    }

    final snapshots = await Future.wait(
      dependencies.map((query) => query.limit(451).get()),
    );
    final references = [
      for (final snapshot in snapshots)
        for (final document in snapshot.docs) document.reference,
    ];
    if (references.length > 450) {
      throw const StudentRepositoryConflictException(
        'This module has too many linked records for a safe mobile batch. '
        'Use the account data-deletion workflow instead.',
      );
    }
    final batch = _firestore.batch();
    for (final reference in references) {
      batch.delete(reference);
    }
    batch.delete(_collection('modules').doc(moduleId));
    await batch.commit();
  }

  @override
  Future<void> saveTopic(Topic topic) async {
    final moduleRef = _collection('modules').doc(topic.moduleId);
    final topicRef = _collection('topics').doc(topic.id);
    await _firestore.runTransaction((transaction) async {
      final module = await transaction.get(moduleRef);
      if (!module.exists) {
        throw const StudentRepositoryConflictException(
          'Choose an existing module before saving this topic.',
        );
      }
      _assertOwner(module.data());
      final existing = await transaction.get(topicRef);
      _assertOwner(existing.data());
      final data =
          _firestoreMap(topic.toMap())
            ..remove('id')
            ..['ownerId'] = _ownerId
            ..['updatedAt'] = FieldValue.serverTimestamp();
      transaction.set(topicRef, data, SetOptions(merge: true));
    });
  }

  @override
  Future<void> deleteTopic(String topicId) => _delete('topics', topicId);

  @override
  Stream<List<TimetableEvent>> watchTimetableEvents({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    int limit = 250,
  }) {
    _requireRange(rangeStart, rangeEnd);
    final query = _collection('timetableEvents')
        .where('startAt', isLessThan: Timestamp.fromDate(rangeEnd.toUtc()))
        .orderBy('startAt', descending: true)
        .limit(_safeLimit(limit));
    return _watch(
      query,
      (doc) => TimetableEvent.fromMap(_documentMap(doc), id: doc.id),
    ).map((events) {
      final filtered =
          events.where((event) {
              if (event.recurrence == RecurrenceFrequency.none) {
                return event.endAt.isAfter(rangeStart);
              }
              return event.recurrenceUntil == null ||
                  !event.recurrenceUntil!.isBefore(rangeStart);
            }).toList()
            ..sort((a, b) => a.startAt.compareTo(b.startAt));
      return List.unmodifiable(filtered);
    });
  }

  @override
  Future<void> saveTimetableEvent(TimetableEvent event) => _upsert(
    'timetableEvents',
    event.id,
    event.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Future<void> deleteTimetableEvent(String eventId) =>
      _delete('timetableEvents', eventId);

  @override
  Stream<List<Assignment>> watchAssignments({
    DateTime? dueFrom,
    DateTime? dueBefore,
    bool includeCompleted = true,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _collection('assignments');
    if (dueFrom != null) {
      query = query.where(
        'dueAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(dueFrom.toUtc()),
      );
    }
    if (dueBefore != null) {
      query = query.where(
        'dueAt',
        isLessThan: Timestamp.fromDate(dueBefore.toUtc()),
      );
    }
    query = query.orderBy('dueAt').limit(_safeLimit(limit));
    return _watch(
      query,
      (doc) => Assignment.fromMap(_documentMap(doc), id: doc.id),
    ).map(
      (items) =>
          includeCompleted
              ? items
              : List.unmodifiable(
                items.where((item) => item.status != WorkStatus.completed),
              ),
    );
  }

  @override
  Future<StudentPage<Assignment>> loadAssignmentPage({
    int limit = 25,
    String? afterCursor,
  }) => _page(
    collection: 'assignments',
    orderField: 'dueAt',
    limit: limit,
    afterCursor: afterCursor,
    decode: (doc) => Assignment.fromMap(_documentMap(doc), id: doc.id),
  );

  @override
  Future<void> saveAssignment(Assignment assignment) => _upsert(
    'assignments',
    assignment.id,
    assignment.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Future<void> deleteAssignment(String assignmentId) =>
      _delete('assignments', assignmentId);

  @override
  Stream<List<Exam>> watchExams({
    DateTime? from,
    DateTime? before,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _collection('examinations');
    if (from != null) {
      query = query.where(
        'startAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from.toUtc()),
      );
    }
    if (before != null) {
      query = query.where(
        'startAt',
        isLessThan: Timestamp.fromDate(before.toUtc()),
      );
    }
    return _watch(
      query.orderBy('startAt').limit(_safeLimit(limit)),
      (doc) => Exam.fromMap(_documentMap(doc), id: doc.id),
    );
  }

  @override
  Future<void> saveExam(Exam exam) => _upsert(
    'examinations',
    exam.id,
    exam.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Future<void> deleteExam(String examId) => _delete('examinations', examId);

  @override
  Stream<List<StudyTask>> watchStudyTasks({
    DateTime? dueFrom,
    DateTime? dueBefore,
    bool includeCompleted = true,
    int limit = 150,
  }) {
    Query<Map<String, dynamic>> query = _collection('studyTasks');
    if (dueFrom != null) {
      query = query.where(
        'dueAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(dueFrom.toUtc()),
      );
    }
    if (dueBefore != null) {
      query = query.where(
        'dueAt',
        isLessThan: Timestamp.fromDate(dueBefore.toUtc()),
      );
    }
    query = query.orderBy('dueAt').limit(_safeLimit(limit));
    return _watch(
      query,
      (doc) => StudyTask.fromMap(_documentMap(doc), id: doc.id),
    ).map(
      (items) =>
          includeCompleted
              ? items
              : List.unmodifiable(items.where((item) => !item.isCompleted)),
    );
  }

  @override
  Future<StudentPage<StudyTask>> loadStudyTaskPage({
    int limit = 25,
    String? afterCursor,
  }) => _page(
    collection: 'studyTasks',
    orderField: 'dueAt',
    limit: limit,
    afterCursor: afterCursor,
    decode: (doc) => StudyTask.fromMap(_documentMap(doc), id: doc.id),
  );

  @override
  Future<void> saveStudyTask(StudyTask task) => _upsert(
    'studyTasks',
    task.id,
    task.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Future<void> setStudyTaskCompleted(
    String taskId, {
    required bool completed,
  }) async {
    final reference = _collection('studyTasks').doc(taskId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      if (!snapshot.exists) {
        throw const StudentRepositoryException(
          'The study task no longer exists.',
        );
      }
      _assertOwner(snapshot.data());
      transaction.update(reference, {
        'status':
            completed ? WorkStatus.completed.name : WorkStatus.inProgress.name,
        'completedAt':
            completed ? FieldValue.serverTimestamp() : FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> deleteStudyTask(String taskId) => _delete('studyTasks', taskId);

  @override
  Stream<List<StudyPlan>> watchStudyPlans({int limit = 20}) => _watch(
    _collection(
      'studyPlans',
    ).orderBy('generatedAt', descending: true).limit(_safeLimit(limit)),
    (doc) => StudyPlan.fromMap(_documentMap(doc), id: doc.id),
  );

  @override
  Future<void> saveStudyPlan(StudyPlan plan) {
    if (plan.userId != _ownerId) {
      throw const StudentRepositoryException(
        'A study plan cannot be assigned to another account.',
      );
    }
    return _upsert(
      'studyPlans',
      plan.id,
      plan.toMap(),
      serverCreatedAt: true,
      serverUpdatedAt: true,
    );
  }

  @override
  Future<void> deleteStudyPlan(String planId) => _delete('studyPlans', planId);

  @override
  Stream<List<FocusSession>> watchFocusSessions({int limit = 100}) => _watch(
    _collection(
      'focusSessions',
    ).orderBy('startedAt', descending: true).limit(_safeLimit(limit)),
    (doc) => FocusSession.fromMap(_documentMap(doc), id: doc.id),
  );

  @override
  Future<StudentPage<FocusSession>> loadFocusSessionPage({
    int limit = 25,
    String? afterCursor,
  }) => _page(
    collection: 'focusSessions',
    orderField: 'startedAt',
    descending: true,
    limit: limit,
    afterCursor: afterCursor,
    decode: (doc) => FocusSession.fromMap(_documentMap(doc), id: doc.id),
  );

  @override
  Future<void> saveFocusSession(FocusSession session) => _upsert(
    'focusSessions',
    session.id,
    session.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Future<void> deleteFocusSession(String sessionId) =>
      _delete('focusSessions', sessionId);

  @override
  Stream<List<Habit>> watchHabits({
    bool includeArchived = false,
    int limit = 100,
  }) => _watch(
    _collection('habits').orderBy('name').limit(_safeLimit(limit)),
    (doc) => Habit.fromMap(_documentMap(doc), id: doc.id),
  ).map(
    (items) =>
        includeArchived
            ? items
            : List.unmodifiable(items.where((habit) => !habit.isArchived)),
  );

  @override
  Future<void> saveHabit(Habit habit) => _upsert(
    'habits',
    habit.id,
    habit.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Future<void> deleteHabit(String habitId) => _delete('habits', habitId);

  @override
  Stream<List<HabitLog>> watchHabitLogs({
    DateTime? from,
    DateTime? before,
    int limit = 250,
  }) {
    Query<Map<String, dynamic>> query = _collection('habitLogs');
    if (from != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(from.toUtc()),
      );
    }
    if (before != null) {
      query = query.where(
        'date',
        isLessThan: Timestamp.fromDate(before.toUtc()),
      );
    }
    return _watch(
      query.orderBy('date', descending: true).limit(_safeLimit(limit)),
      (doc) => HabitLog.fromMap(_documentMap(doc), id: doc.id),
    );
  }

  @override
  Future<void> saveHabitLog(HabitLog log) => _upsert(
    'habitLogs',
    log.id,
    log.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Future<void> deleteHabitLog(String logId) => _delete('habitLogs', logId);

  @override
  Stream<List<WellnessCheckIn>> watchWellnessCheckIns({int limit = 90}) =>
      _watch(
        _collection(
          'wellnessCheckIns',
        ).orderBy('recordedAt', descending: true).limit(_safeLimit(limit)),
        (doc) => WellnessCheckIn.fromMap(_documentMap(doc), id: doc.id),
      );

  @override
  Future<void> saveWellnessCheckIn(WellnessCheckIn checkIn) => _upsert(
    'wellnessCheckIns',
    checkIn.id,
    checkIn.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Future<void> deleteWellnessCheckIn(String checkInId) =>
      _delete('wellnessCheckIns', checkInId);

  @override
  Stream<List<Achievement>> watchAchievements({int limit = 100}) => _watch(
    _collection('achievements').orderBy('title').limit(_safeLimit(limit)),
    (doc) => Achievement.fromMap(_documentMap(doc), id: doc.id),
  );

  @override
  Future<void> saveAchievement(Achievement achievement) => _upsert(
    'achievements',
    achievement.id,
    achievement.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Future<void> deleteAchievement(String achievementId) =>
      _delete('achievements', achievementId);

  @override
  Stream<List<TopicMasteryRecord>> watchTopicMastery({
    String? moduleId,
    int limit = 250,
  }) {
    Query<Map<String, dynamic>> query = _collection(
      'topicMastery',
    ).orderBy('updatedAt', descending: true);
    if (moduleId != null) query = query.where('moduleId', isEqualTo: moduleId);
    return _watch(
      query.limit(_safeLimit(limit)),
      (doc) => TopicMasteryRecord.fromMap(_documentMap(doc)),
    );
  }

  @override
  Future<void> saveTopicMastery(TopicMasteryRecord record) => _upsert(
    'topicMastery',
    record.topicId,
    record.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Stream<List<SavedLocation>> watchSavedLocations({int limit = 100}) => _watch(
    _collection('savedLocations').orderBy('name').limit(_safeLimit(limit)),
    (doc) => SavedLocation.fromMap(_documentMap(doc), id: doc.id),
  );

  @override
  Future<void> saveSavedLocation(SavedLocation location) => _upsert(
    'savedLocations',
    location.id,
    location.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Future<void> deleteSavedLocation(String locationId) =>
      _delete('savedLocations', locationId);

  @override
  Stream<List<AiConversation>> watchAiConversations({
    bool includeArchived = false,
    int limit = 30,
  }) => _watch(
    _collection(
      'aiConversations',
    ).orderBy('updatedAt', descending: true).limit(_safeLimit(limit)),
    (doc) => AiConversation.fromMap(_documentMap(doc), id: doc.id),
  ).map(
    (items) =>
        includeArchived
            ? items
            : List.unmodifiable(
              items.where((conversation) => !conversation.archived),
            ),
  );

  @override
  Future<void> saveAiConversation(AiConversation conversation) => _upsert(
    'aiConversations',
    conversation.id,
    conversation.toMap(),
    serverCreatedAt: true,
    serverUpdatedAt: true,
  );

  @override
  Future<void> deleteAiConversation(String conversationId) =>
      _delete('aiConversations', conversationId);

  Stream<List<T>> _watch<T>(
    Query<Map<String, dynamic>> query,
    T Function(QueryDocumentSnapshot<Map<String, dynamic>>) decode,
  ) => query
      .snapshots(includeMetadataChanges: true)
      .map((snapshot) => List.unmodifiable(snapshot.docs.map(decode)));

  Future<StudentPage<T>> _page<T>({
    required String collection,
    required String orderField,
    required int limit,
    required String? afterCursor,
    required T Function(QueryDocumentSnapshot<Map<String, dynamic>>) decode,
    bool descending = false,
  }) async {
    final pageSize = _safeLimit(limit, maximum: 100);
    Query<Map<String, dynamic>> query = _collection(
      collection,
    ).orderBy(orderField, descending: descending).limit(pageSize);
    if (afterCursor != null) {
      final cursor = await _collection(collection).doc(afterCursor).get();
      if (!cursor.exists) {
        throw const StudentRepositoryException(
          'The requested page cursor has expired. Refresh the list.',
        );
      }
      _assertOwner(cursor.data());
      query = query.startAfterDocument(cursor);
    }
    final snapshot = await query.get();
    return StudentPage(
      items: List.unmodifiable(snapshot.docs.map(decode)),
      nextCursor:
          snapshot.docs.length == pageSize ? snapshot.docs.last.id : null,
    );
  }

  Future<void> _upsert(
    String collection,
    String id,
    Map<String, Object?> model, {
    bool serverCreatedAt = false,
    bool serverUpdatedAt = false,
  }) async {
    _requireId(id);
    final reference = _collection(collection).doc(id);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      _assertOwner(existing.data());
      final data =
          _firestoreMap(model)
            ..remove('id')
            ..['ownerId'] = _ownerId;
      if (serverCreatedAt) {
        data.remove('createdAt');
        if (!existing.exists) data['createdAt'] = FieldValue.serverTimestamp();
      }
      if (serverUpdatedAt) {
        data['updatedAt'] = FieldValue.serverTimestamp();
      }
      transaction.set(reference, data, SetOptions(merge: true));
    });
  }

  Future<void> _delete(String collection, String id) async {
    _requireId(id);
    final reference = _collection(collection).doc(id);
    await _firestore.runTransaction((transaction) async {
      final existing = await transaction.get(reference);
      if (!existing.exists) return;
      _assertOwner(existing.data());
      transaction.delete(reference);
    });
  }

  Map<String, Object?> _documentMap(
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final raw = document.data();
    _assertOwner(raw);
    final normalized = _fromFirestore(raw);
    final map = Map<String, Object?>.from(normalized as Map);
    // Local server timestamps can briefly be null before acknowledgement.
    for (final field in const ['createdAt', 'updatedAt']) {
      if (map.containsKey(field) && map[field] == null) {
        map[field] = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      }
    }
    return map;
  }

  void _assertOwner(Map<String, dynamic>? data) {
    final storedOwner = data?['ownerId'];
    if (storedOwner != null && storedOwner != _ownerId) {
      throw const StudentRepositoryException(
        'A private record failed its ownership check.',
      );
    }
  }

  static Map<String, dynamic> _firestoreMap(Map<String, Object?> value) =>
      value.map((key, item) => MapEntry(key, _toFirestore(item)));

  static Object? _toFirestore(Object? value) => switch (value) {
    DateTime date => Timestamp.fromDate(date.toUtc()),
    Map map => map.map(
      (key, item) => MapEntry(key.toString(), _toFirestore(item)),
    ),
    Iterable values => values.map(_toFirestore).toList(),
    _ => value,
  };

  static Object? _fromFirestore(Object? value) => switch (value) {
    Timestamp timestamp => timestamp.toDate(),
    Map map => map.map(
      (key, item) => MapEntry(key.toString(), _fromFirestore(item)),
    ),
    Iterable values => values.map(_fromFirestore).toList(),
    _ => value,
  };

  static int _safeLimit(int value, {int maximum = 500}) {
    if (value < 1) {
      throw ArgumentError.value(value, 'limit', 'Must be positive.');
    }
    return value.clamp(1, maximum);
  }

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
