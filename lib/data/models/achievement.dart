// Represents earned achievements and their progress towards completion.

import 'enums.dart';
import 'model_utils.dart';

final class Achievement {
  Achievement({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.threshold,
    required this.pointsReward,
    required this.iconName,
    double progress = 0,
    this.unlockedAt,
  }) : progress = ModelUtils.clampUnit(progress);

  final String id;
  final AchievementType type;
  final String title;
  final String description;
  final int threshold;
  final int pointsReward;
  final String iconName;
  final double progress;
  final DateTime? unlockedAt;

  bool get isUnlocked => unlockedAt != null;

  factory Achievement.fromMap(Map<String, Object?> map, {String? id}) =>
      Achievement(
        id: id ?? ModelUtils.requiredString(map, 'id'),
        type: ModelUtils.enumValue(map, 'type', AchievementType.values),
        title: ModelUtils.requiredString(map, 'title'),
        description: ModelUtils.requiredString(map, 'description'),
        threshold: ModelUtils.integer(map, 'threshold'),
        pointsReward: ModelUtils.integer(map, 'pointsReward', fallback: 0),
        iconName: ModelUtils.requiredString(map, 'iconName'),
        progress: ModelUtils.decimal(map, 'progress', fallback: 0),
        unlockedAt: ModelUtils.optionalDateTime(map, 'unlockedAt'),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'type': type.name,
    'title': title,
    'description': description,
    'threshold': threshold,
    'pointsReward': pointsReward,
    'iconName': iconName,
    'progress': progress,
    'unlockedAt': unlockedAt,
  };
}

final class TopicMasteryRecord {
  TopicMasteryRecord({
    required this.topicId,
    required this.moduleId,
    required this.updatedAt,
    double mastery = 0,
    this.studyMinutes = 0,
    this.completedTasks = 0,
    this.quizAverage,
  }) : mastery = ModelUtils.clampUnit(mastery);

  final String topicId;
  final String moduleId;
  final double mastery;
  final int studyMinutes;
  final int completedTasks;
  final double? quizAverage;
  final DateTime updatedAt;

  factory TopicMasteryRecord.fromMap(Map<String, Object?> map) =>
      TopicMasteryRecord(
        topicId: ModelUtils.requiredString(map, 'topicId'),
        moduleId: ModelUtils.requiredString(map, 'moduleId'),
        mastery: ModelUtils.decimal(map, 'mastery', fallback: 0),
        studyMinutes: ModelUtils.integer(map, 'studyMinutes', fallback: 0),
        completedTasks: ModelUtils.integer(map, 'completedTasks', fallback: 0),
        quizAverage:
            map['quizAverage'] == null
                ? null
                : ModelUtils.decimal(map, 'quizAverage'),
        updatedAt: ModelUtils.dateTime(map, 'updatedAt'),
      );

  Map<String, Object?> toMap() => {
    'topicId': topicId,
    'moduleId': moduleId,
    'mastery': mastery,
    'studyMinutes': studyMinutes,
    'completedTasks': completedTasks,
    'quizAverage': quizAverage,
    'updatedAt': updatedAt,
  };
}
