// Describes every data operation available to features, regardless of storage.

import '../models/models.dart';

/// A page of owner-scoped student data. [nextCursor] is opaque to callers.
final class StudentPage<T> {
  const StudentPage({required this.items, this.nextCursor});

  final List<T> items;
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

class StudentRepositoryException implements Exception {
  const StudentRepositoryException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class StudentRepositoryConflictException extends StudentRepositoryException {
  const StudentRepositoryConflictException(super.message);
}

/// Owner-scoped persistence contract shared by Firebase and deterministic demo
/// data. UI code depends on this abstraction and never talks to Firestore.
abstract interface class StudentRepository {
  String get ownerId;
  bool get isDemo;
  String get dataOriginLabel;

  Stream<List<Module>> watchModules({int limit = 100});
  Stream<List<Topic>> watchTopics({String? moduleId, int limit = 250});
  Future<void> saveModule(Module module);
  Future<void> deleteModule(String moduleId, {bool cascade = false});
  Future<void> saveTopic(Topic topic);
  Future<void> deleteTopic(String topicId);

  Stream<List<TimetableEvent>> watchTimetableEvents({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    int limit = 250,
  });
  Future<void> saveTimetableEvent(TimetableEvent event);
  Future<void> deleteTimetableEvent(String eventId);

  Stream<List<Assignment>> watchAssignments({
    DateTime? dueFrom,
    DateTime? dueBefore,
    bool includeCompleted = true,
    int limit = 100,
  });
  Future<StudentPage<Assignment>> loadAssignmentPage({
    int limit = 25,
    String? afterCursor,
  });
  Future<void> saveAssignment(Assignment assignment);
  Future<void> deleteAssignment(String assignmentId);

  Stream<List<Exam>> watchExams({
    DateTime? from,
    DateTime? before,
    int limit = 100,
  });
  Future<void> saveExam(Exam exam);
  Future<void> deleteExam(String examId);

  Stream<List<StudyTask>> watchStudyTasks({
    DateTime? dueFrom,
    DateTime? dueBefore,
    bool includeCompleted = true,
    int limit = 150,
  });
  Future<StudentPage<StudyTask>> loadStudyTaskPage({
    int limit = 25,
    String? afterCursor,
  });
  Future<void> saveStudyTask(StudyTask task);
  Future<void> setStudyTaskCompleted(String taskId, {required bool completed});
  Future<void> deleteStudyTask(String taskId);

  Stream<List<StudyPlan>> watchStudyPlans({int limit = 20});
  Future<void> saveStudyPlan(StudyPlan plan);
  Future<void> deleteStudyPlan(String planId);

  Stream<List<FocusSession>> watchFocusSessions({int limit = 100});
  Future<StudentPage<FocusSession>> loadFocusSessionPage({
    int limit = 25,
    String? afterCursor,
  });
  Future<void> saveFocusSession(FocusSession session);
  Future<void> deleteFocusSession(String sessionId);

  Stream<List<Habit>> watchHabits({
    bool includeArchived = false,
    int limit = 100,
  });
  Future<void> saveHabit(Habit habit);
  Future<void> deleteHabit(String habitId);
  Stream<List<HabitLog>> watchHabitLogs({
    DateTime? from,
    DateTime? before,
    int limit = 250,
  });
  Future<void> saveHabitLog(HabitLog log);
  Future<void> deleteHabitLog(String logId);

  Stream<List<WellnessCheckIn>> watchWellnessCheckIns({int limit = 90});
  Future<void> saveWellnessCheckIn(WellnessCheckIn checkIn);
  Future<void> deleteWellnessCheckIn(String checkInId);

  Stream<List<Achievement>> watchAchievements({int limit = 100});
  Future<void> saveAchievement(Achievement achievement);
  Future<void> deleteAchievement(String achievementId);
  Stream<List<TopicMasteryRecord>> watchTopicMastery({
    String? moduleId,
    int limit = 250,
  });
  Future<void> saveTopicMastery(TopicMasteryRecord record);

  Stream<List<SavedLocation>> watchSavedLocations({int limit = 100});
  Future<void> saveSavedLocation(SavedLocation location);
  Future<void> deleteSavedLocation(String locationId);

  Stream<List<AiConversation>> watchAiConversations({
    bool includeArchived = false,
    int limit = 30,
  });
  Future<void> saveAiConversation(AiConversation conversation);
  Future<void> deleteAiConversation(String conversationId);
}
