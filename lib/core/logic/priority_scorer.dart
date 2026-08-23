// Gives study work a transparent score based on urgency, effort, and progress.

import '../../data/models/enums.dart';

final class PriorityScore {
  const PriorityScore({
    required this.total,
    required this.urgency,
    required this.importance,
    required this.workload,
    required this.overdueBonus,
    required this.recoveryBonus,
    required this.masteryBonus,
  });

  final double total;
  final double urgency;
  final double importance;
  final double workload;
  final double overdueBonus;
  final double recoveryBonus;
  final double masteryBonus;
}

abstract final class PriorityScorer {
  /// Produces a stable score from 0–100. `now` is required so scheduling and
  /// tests never depend on the wall clock implicitly.
  static PriorityScore calculate({
    required DateTime deadline,
    required PriorityLevel priority,
    required int remainingMinutes,
    required DateTime now,
    double topicMastery = 0.5,
    bool wasMissed = false,
  }) {
    if (remainingMinutes < 0) {
      throw ArgumentError.value(
        remainingMinutes,
        'remainingMinutes',
        'Cannot be negative.',
      );
    }
    final untilDeadline = deadline.difference(now);
    final hours = untilDeadline.inMinutes / 60;
    final urgency = switch (hours) {
      <= 0 => 40.0,
      <= 24 => 38.0,
      <= 72 => 32.0,
      <= 168 => 24.0,
      <= 336 => 15.0,
      <= 720 => 8.0,
      _ => 3.0,
    };
    final importance = switch (priority) {
      PriorityLevel.low => 5.0,
      PriorityLevel.medium => 12.0,
      PriorityLevel.high => 20.0,
      PriorityLevel.urgent => 28.0,
    };
    final workload = (remainingMinutes / 480 * 15).clamp(0.0, 15.0);
    final overdueBonus = deadline.isBefore(now) ? 7.0 : 0.0;
    final recoveryBonus = wasMissed ? 5.0 : 0.0;
    final masteryBonus = ((1 - topicMastery.clamp(0.0, 1.0)) * 5).clamp(
      0.0,
      5.0,
    );
    final total = (urgency +
            importance +
            workload +
            overdueBonus +
            recoveryBonus +
            masteryBonus)
        .clamp(0.0, 100.0);
    return PriorityScore(
      total: total,
      urgency: urgency,
      importance: importance,
      workload: workload,
      overdueBonus: overdueBonus,
      recoveryBonus: recoveryBonus,
      masteryBonus: masteryBonus,
    );
  }
}
