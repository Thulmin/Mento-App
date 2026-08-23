// Estimates topic mastery from recent study, task, and optional quiz evidence.

final class TopicEvidence {
  const TopicEvidence({
    required this.studyMinutes,
    required this.completedTasks,
    required this.totalTasks,
    required this.lastActivityAt,
    this.quizAverage,
  });

  final int studyMinutes;
  final int completedTasks;
  final int totalTasks;
  final double? quizAverage;
  final DateTime lastActivityAt;
}

final class TopicMasteryScore {
  const TopicMasteryScore({
    required this.total,
    required this.studyContribution,
    required this.taskContribution,
    required this.quizContribution,
    required this.recencyContribution,
  });

  final double total;
  final double studyContribution;
  final double taskContribution;
  final double quizContribution;
  final double recencyContribution;

  int get percentage => (total * 100).round();
  bool get isMastered => total >= 0.8;
}

abstract final class TopicMasteryCalculator {
  /// Transparent evidence weighting: study 30%, tasks 30%, quiz 30%, recency
  /// 10%. Quiz-free topics can still progress but require assessment evidence
  /// before being labelled mastered.
  static TopicMasteryScore calculate(
    TopicEvidence evidence, {
    required DateTime now,
  }) {
    if (evidence.studyMinutes < 0 ||
        evidence.completedTasks < 0 ||
        evidence.totalTasks < 0 ||
        evidence.completedTasks > evidence.totalTasks) {
      throw ArgumentError('Topic evidence counts are invalid.');
    }
    if (evidence.quizAverage != null &&
        (evidence.quizAverage! < 0 || evidence.quizAverage! > 1)) {
      throw ArgumentError.value(evidence.quizAverage, 'quizAverage');
    }
    final study = (evidence.studyMinutes / 180).clamp(0.0, 1.0) * 0.3;
    final tasks =
        evidence.totalTasks == 0
            ? 0.0
            : evidence.completedTasks / evidence.totalTasks * 0.3;
    final quiz = (evidence.quizAverage ?? 0) * 0.3;
    final ageDays = now.difference(evidence.lastActivityAt).inDays;
    final recencyFactor = switch (ageDays) {
      < 0 => 1.0,
      <= 7 => 1.0,
      <= 30 => 0.7,
      <= 90 => 0.3,
      _ => 0.0,
    };
    final recency = recencyFactor * 0.1;
    final total = (study + tasks + quiz + recency).clamp(0.0, 1.0);
    return TopicMasteryScore(
      total: total,
      studyContribution: study,
      taskContribution: tasks,
      quizContribution: quiz,
      recencyContribution: recency,
    );
  }
}
