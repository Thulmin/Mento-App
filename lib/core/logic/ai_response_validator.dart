// Checks AI-generated plans before any suggested data reaches the application.

import 'dart:convert';

import '../../data/models/enums.dart';
import '../../data/models/study_plan.dart';

final class AiValidationIssue {
  const AiValidationIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

final class AiStudyPlanValidationResult {
  AiStudyPlanValidationResult({
    required this.plan,
    required List<AiValidationIssue> issues,
  }) : issues = List.unmodifiable(issues);

  final StudyPlan? plan;
  final List<AiValidationIssue> issues;

  bool get isValid => plan != null && issues.isEmpty;
}

final class AiStructuredResponseException implements Exception {
  AiStructuredResponseException(List<AiValidationIssue> issues)
    : issues = List.unmodifiable(issues);

  final List<AiValidationIssue> issues;

  @override
  String toString() => 'Invalid AI study plan: ${issues.join('; ')}';
}

/// Strict trust boundary for provider-generated study-plan JSON.
abstract final class AiStudyPlanValidator {
  static const int maximumResponseBytes = 128 * 1024;

  static StudyPlan parse(
    String response, {
    required String planId,
    required String userId,
    required Set<String> allowedModuleIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime generatedAt,
    int maxDailyMinutes = 240,
    int maxBlocks = 100,
  }) {
    final result = validate(
      response,
      planId: planId,
      userId: userId,
      allowedModuleIds: allowedModuleIds,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      generatedAt: generatedAt,
      maxDailyMinutes: maxDailyMinutes,
      maxBlocks: maxBlocks,
    );
    if (!result.isValid) {
      throw AiStructuredResponseException(result.issues);
    }
    return result.plan!;
  }

  static AiStudyPlanValidationResult validate(
    String response, {
    required String planId,
    required String userId,
    required Set<String> allowedModuleIds,
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime generatedAt,
    int maxDailyMinutes = 240,
    int maxBlocks = 100,
  }) {
    final issues = <AiValidationIssue>[];
    if (!rangeEnd.isAfter(rangeStart)) {
      issues.add(
        const AiValidationIssue(r'$', 'Invalid requested plan range.'),
      );
    }
    if (maxDailyMinutes <= 0 || maxDailyMinutes > 720) {
      issues.add(
        const AiValidationIssue(r'$', 'Daily limit must be from 1 to 720.'),
      );
    }
    if (response.length > maximumResponseBytes) {
      issues.add(
        const AiValidationIssue(r'$', 'Response exceeds the size limit.'),
      );
      return AiStudyPlanValidationResult(plan: null, issues: issues);
    }

    Object? decoded;
    try {
      decoded = jsonDecode(response);
    } on FormatException {
      issues.add(const AiValidationIssue(r'$', 'Response is not valid JSON.'));
      return AiStudyPlanValidationResult(plan: null, issues: issues);
    }
    if (decoded is! Map) {
      issues.add(const AiValidationIssue(r'$', 'Expected a JSON object.'));
      return AiStudyPlanValidationResult(plan: null, issues: issues);
    }
    final root = decoded.map<String, Object?>(
      (key, value) => MapEntry(key.toString(), value),
    );
    final schemaVersion = _int(root['schemaVersion']);
    if (schemaVersion != 1) {
      issues.add(
        const AiValidationIssue(
          r'$.schemaVersion',
          'Only schemaVersion 1 is supported.',
        ),
      );
    }
    final rawBlocks = root['blocks'];
    if (rawBlocks is! List) {
      issues.add(
        const AiValidationIssue(r'$.blocks', 'Expected a JSON array.'),
      );
      return AiStudyPlanValidationResult(plan: null, issues: issues);
    }
    if (rawBlocks.isEmpty) {
      issues.add(
        const AiValidationIssue(r'$.blocks', 'At least one block is required.'),
      );
    }
    if (rawBlocks.length > maxBlocks) {
      issues.add(
        AiValidationIssue(
          r'$.blocks',
          'No more than $maxBlocks blocks are allowed.',
        ),
      );
    }

    final blocks = <PlanBlock>[];
    final ids = <String>{};
    for (
      var index = 0;
      index < rawBlocks.length && index < maxBlocks;
      index++
    ) {
      final path = '\$.blocks[$index]';
      final raw = rawBlocks[index];
      if (raw is! Map) {
        issues.add(AiValidationIssue(path, 'Expected a JSON object.'));
        continue;
      }
      final map = raw.map<String, Object?>(
        (key, value) => MapEntry(key.toString(), value),
      );
      final issueCountBefore = issues.length;
      final start = _readBlockTime(map, path, isStart: true, issues: issues);
      final end = _readBlockTime(map, path, isStart: false, issues: issues);
      final moduleId = _text(
        map['moduleId'],
        '$path.moduleId',
        issues,
        maximumLength: 128,
      );
      if (moduleId != null && !allowedModuleIds.contains(moduleId)) {
        issues.add(
          AiValidationIssue(
            '$path.moduleId',
            'Module is not available to this user.',
          ),
        );
      }
      final objective = _text(
        map['objective'],
        '$path.objective',
        issues,
        maximumLength: 500,
      );
      final method = _text(
        map['recommendedMethod'] ?? map['method'],
        '$path.recommendedMethod',
        issues,
        maximumLength: 300,
      );
      final reason = _text(
        map['reason'],
        '$path.reason',
        issues,
        maximumLength: 1000,
      );
      final priority = _priority(map['priority'], '$path.priority', issues);
      final breakMinutes = _int(map['breakMinutes']) ?? 0;
      if (breakMinutes < 0 || breakMinutes > 120) {
        issues.add(
          AiValidationIssue(
            '$path.breakMinutes',
            'Break must be from 0 to 120 minutes.',
          ),
        );
      }
      final topicId = _optionalText(
        map['topicId'],
        '$path.topicId',
        issues,
        maximumLength: 128,
      );
      final linkedTaskId = _optionalText(
        map['linkedTaskId'],
        '$path.linkedTaskId',
        issues,
        maximumLength: 128,
      );
      if (start != null && end != null) {
        if (!end.isAfter(start)) {
          issues.add(
            AiValidationIssue(path, 'End time must be after start time.'),
          );
        } else {
          final minutes = end.difference(start).inMinutes;
          if (minutes < 15 || minutes > 240) {
            issues.add(
              AiValidationIssue(
                path,
                'Block duration must be from 15 to 240 minutes.',
              ),
            );
          }
        }
        if (start.isBefore(rangeStart) || end.isAfter(rangeEnd)) {
          issues.add(
            AiValidationIssue(
              path,
              'Block is outside the requested plan range.',
            ),
          );
        }
      }

      var id = _optionalText(map['id'], '$path.id', issues, maximumLength: 128);
      id ??=
          start == null
              ? 'ai_block_$index'
              : 'ai_${start.microsecondsSinceEpoch}_$index';
      if (!ids.add(id)) {
        issues.add(AiValidationIssue('$path.id', 'Block id must be unique.'));
      }
      if (issues.length == issueCountBefore &&
          start != null &&
          end != null &&
          moduleId != null &&
          objective != null &&
          method != null &&
          reason != null &&
          priority != null) {
        blocks.add(
          PlanBlock(
            id: id,
            startAt: start,
            endAt: end,
            moduleId: moduleId,
            topicId: topicId,
            objective: objective,
            recommendedMethod: method,
            breakMinutes: breakMinutes,
            priority: priority,
            reason: reason,
            source: PlanSource.artificialIntelligence,
            linkedTaskId: linkedTaskId,
          ),
        );
      }
    }

    blocks.sort((first, second) => first.startAt.compareTo(second.startAt));
    final minutesByDay = <DateTime, int>{};
    for (var index = 0; index < blocks.length; index++) {
      final block = blocks[index];
      if (index > 0 && block.startAt.isBefore(blocks[index - 1].endAt)) {
        issues.add(
          AiValidationIssue(
            r'$.blocks',
            'Plan blocks cannot overlap one another.',
          ),
        );
      }
      final day = DateTime(
        block.startAt.year,
        block.startAt.month,
        block.startAt.day,
      );
      minutesByDay[day] = (minutesByDay[day] ?? 0) + block.duration.inMinutes;
    }
    if (minutesByDay.values.any((minutes) => minutes > maxDailyMinutes)) {
      issues.add(
        AiValidationIssue(
          r'$.blocks',
          'Plan exceeds the $maxDailyMinutes-minute daily workload limit.',
        ),
      );
    }
    final rationale = _optionalText(
      root['rationale'],
      r'$.rationale',
      issues,
      maximumLength: 2000,
    );
    if (issues.isNotEmpty) {
      return AiStudyPlanValidationResult(plan: null, issues: issues);
    }
    return AiStudyPlanValidationResult(
      plan: StudyPlan(
        id: planId,
        userId: userId,
        generatedAt: generatedAt,
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        source: PlanSource.artificialIntelligence,
        blocks: blocks,
        maxDailyMinutes: maxDailyMinutes,
        rationale: rationale,
        schemaVersion: 1,
      ),
      issues: const [],
    );
  }

  static DateTime? _readBlockTime(
    Map<String, Object?> map,
    String path, {
    required bool isStart,
    required List<AiValidationIssue> issues,
  }) {
    final key = isStart ? 'startAt' : 'endAt';
    final direct = map[key];
    if (direct is String) {
      final parsed = DateTime.tryParse(direct);
      if (parsed != null) return parsed;
      issues.add(
        AiValidationIssue('$path.$key', 'Expected ISO-8601 date-time.'),
      );
      return null;
    }
    final date = map['date'];
    final time = map[isStart ? 'startTime' : 'endTime'];
    if (date is String && time is String) {
      final parsed = DateTime.tryParse('${date}T$time');
      if (parsed != null) return parsed;
    }
    issues.add(
      AiValidationIssue(
        '$path.$key',
        'Provide $key or date with ${isStart ? 'startTime' : 'endTime'}.',
      ),
    );
    return null;
  }

  static PriorityLevel? _priority(
    Object? value,
    String path,
    List<AiValidationIssue> issues,
  ) {
    if (value is String) {
      final lower = value.toLowerCase();
      for (final priority in PriorityLevel.values) {
        if (priority.name.toLowerCase() == lower) return priority;
      }
    }
    issues.add(
      AiValidationIssue(path, 'Expected low, medium, high, or urgent.'),
    );
    return null;
  }

  static String? _text(
    Object? value,
    String path,
    List<AiValidationIssue> issues, {
    required int maximumLength,
  }) {
    final text = _optionalText(
      value,
      path,
      issues,
      maximumLength: maximumLength,
    );
    if (text == null) {
      issues.add(AiValidationIssue(path, 'A non-empty string is required.'));
    }
    return text;
  }

  static String? _optionalText(
    Object? value,
    String path,
    List<AiValidationIssue> issues, {
    required int maximumLength,
  }) {
    if (value == null) return null;
    if (value is! String) {
      issues.add(AiValidationIssue(path, 'Expected a string.'));
      return null;
    }
    final text = value.trim();
    if (text.isEmpty) return null;
    if (text.length > maximumLength) {
      issues.add(
        AiValidationIssue(path, 'Must be $maximumLength characters or fewer.'),
      );
      return null;
    }
    if (RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]').hasMatch(text)) {
      issues.add(AiValidationIssue(path, 'Contains unsupported control text.'));
      return null;
    }
    return text;
  }

  static int? _int(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return null;
  }
}
