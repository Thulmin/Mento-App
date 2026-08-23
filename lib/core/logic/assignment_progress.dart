// Calculates assignment completion from both subtasks and estimated effort.

import '../../data/models/assignment.dart';
import '../../data/models/enums.dart';

final class AssignmentProgress {
  const AssignmentProgress({
    required this.fraction,
    required this.completedSubtasks,
    required this.totalSubtasks,
    required this.completedEstimatedMinutes,
    required this.totalEstimatedMinutes,
  });

  final double fraction;
  final int completedSubtasks;
  final int totalSubtasks;
  final int completedEstimatedMinutes;
  final int totalEstimatedMinutes;

  int get percentage => (fraction * 100).round();
  bool get isComplete => fraction >= 1;
}

abstract final class AssignmentProgressCalculator {
  /// Uses estimated effort as subtask weight. If no useful estimates exist,
  /// every subtask has equal weight. Without subtasks, manual progress applies.
  static AssignmentProgress calculate(Assignment assignment) {
    final subtasks = assignment.subtasks;
    if (subtasks.isEmpty) {
      final fraction =
          assignment.status == WorkStatus.completed
              ? 1.0
              : assignment.manualProgress.clamp(0.0, 1.0);
      return AssignmentProgress(
        fraction: fraction,
        completedSubtasks: assignment.status == WorkStatus.completed ? 1 : 0,
        totalSubtasks: 0,
        completedEstimatedMinutes:
            (assignment.estimatedMinutes * fraction).round(),
        totalEstimatedMinutes: assignment.estimatedMinutes,
      );
    }

    final completedCount = subtasks.where((item) => item.isCompleted).length;
    final positiveEstimateTotal = subtasks.fold<int>(
      0,
      (total, item) => total + item.estimatedMinutes.clamp(0, 1 << 31),
    );
    if (positiveEstimateTotal == 0) {
      return AssignmentProgress(
        fraction: completedCount / subtasks.length,
        completedSubtasks: completedCount,
        totalSubtasks: subtasks.length,
        completedEstimatedMinutes: completedCount,
        totalEstimatedMinutes: subtasks.length,
      );
    }
    final completedMinutes = subtasks
        .where((item) => item.isCompleted)
        .fold<int>(
          0,
          (total, item) => total + item.estimatedMinutes.clamp(0, 1 << 31),
        );
    return AssignmentProgress(
      fraction: completedMinutes / positiveEstimateTotal,
      completedSubtasks: completedCount,
      totalSubtasks: subtasks.length,
      completedEstimatedMinutes: completedMinutes,
      totalEstimatedMinutes: positiveEstimateTotal,
    );
  }
}
