// Requests an AI plan and safely falls back to the local planner when needed.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logic/logic.dart';
import '../../../core/network/mento_ai_client.dart';
import '../../../data/models/models.dart';

class PlanGenerationResult {
  const PlanGenerationResult({
    required this.plan,
    required this.usedFallback,
    required this.message,
  });

  final StudyPlan plan;
  final bool usedFallback;
  final String message;
}

class StudyPlannerInput {
  const StudyPlannerInput({
    required this.userId,
    required this.now,
    required this.rangeStart,
    required this.rangeEnd,
    required this.timeZone,
    required this.workItems,
    required this.availability,
    required this.commitments,
    required this.preferences,
    required this.moduleNames,
    this.recentCompletionRate,
    this.missedTaskIds = const [],
  });

  final String userId;
  final DateTime now;
  final DateTime rangeStart;
  final DateTime rangeEnd;
  final String timeZone;
  final List<PlannerWorkItem> workItems;
  final List<AvailabilitySlot> availability;
  final List<BusyPeriod> commitments;
  final PlannerPreferences preferences;
  final Map<String, String> moduleNames;
  final double? recentCompletionRate;
  final List<String> missedTaskIds;
}

class AiPlannerService {
  AiPlannerService(this._client);

  final MentoAiGateway _client;
  static const _uuid = Uuid();

  Future<PlanGenerationResult> generate(
    StudyPlannerInput input, {
    CancelToken? cancelToken,
  }) async {
    try {
      final data = await _client.post(
        AiEndpoint.studyPlan,
        _toWorkerInput(input),
        cancelToken: cancelToken,
      );
      final transformed = _workerPlanToValidatorJson(data);
      final plan = AiStudyPlanValidator.parse(
        jsonEncode(transformed),
        planId: _uuid.v4(),
        userId: input.userId,
        allowedModuleIds: input.moduleNames.keys.toSet(),
        rangeStart: input.rangeStart,
        rangeEnd: input.rangeEnd,
        generatedAt: input.now,
        maxDailyMinutes: input.preferences.maxDailyMinutes,
      );
      return PlanGenerationResult(
        plan: plan,
        usedFallback: false,
        message: 'AI plan validated. Review every block before accepting it.',
      );
    } on AiClientFailure catch (error) {
      if (error.code == 'cancelled') rethrow;
      return _fallback(input, error.message);
    } on AiStructuredResponseException {
      return _fallback(
        input,
        'The AI response failed validation, so no AI output was saved.',
      );
    }
  }

  PlanGenerationResult _fallback(StudyPlannerInput input, String reason) {
    final plan = DeterministicFallbackPlanner.generate(
      planId: _uuid.v4(),
      userId: input.userId,
      now: input.now,
      rangeStart: input.rangeStart,
      rangeEnd: input.rangeEnd,
      workItems: input.workItems,
      availability: input.availability,
      commitments: input.commitments,
      preferences: input.preferences,
    );
    return PlanGenerationResult(
      plan: plan,
      usedFallback: true,
      message: '$reason A deterministic offline plan was generated instead.',
    );
  }

  Map<String, Object?> _toWorkerInput(StudyPlannerInput input) {
    final date = DateFormat('yyyy-MM-dd');
    final clock = DateFormat('HH:mm');
    return {
      'timezone': input.timeZone,
      'rangeStart': date.format(input.rangeStart),
      'rangeEnd': date.format(input.rangeEnd),
      'deadlines': [
        for (final item in input.workItems)
          {
            'id': item.id,
            'title': item.title,
            'type': 'task',
            if (item.moduleId != null) 'moduleId': item.moduleId,
            if (item.moduleId != null &&
                input.moduleNames[item.moduleId] != null)
              'moduleName': input.moduleNames[item.moduleId],
            'dueAt': item.deadline.toUtc().toIso8601String(),
            'priority': item.priority.name,
            'remainingMinutes': item.remainingMinutes,
          },
      ],
      'commitments': [
        for (final item in input.commitments)
          {
            'startAt': item.startAt.toUtc().toIso8601String(),
            'endAt': item.endAt.toUtc().toIso8601String(),
            if (item.reason != null) 'label': item.reason,
          },
      ],
      'availableWindows': [
        for (final item in input.availability)
          {
            'date': date.format(item.startAt),
            'startTime': clock.format(item.startAt),
            'endTime': clock.format(item.endAt),
          },
      ],
      'preferences': {
        'preferredSessionMinutes': input.preferences.preferredSessionMinutes,
        'preferredBreakMinutes': input.preferences.breakMinutes.clamp(5, 60),
        'maximumDailyMinutes': input.preferences.maxDailyMinutes,
      },
      if (input.recentCompletionRate != null)
        'recentCompletionRate': input.recentCompletionRate,
      if (input.missedTaskIds.isNotEmpty) 'missedTaskIds': input.missedTaskIds,
    };
  }

  Map<String, Object?> _workerPlanToValidatorJson(Map<String, dynamic> data) {
    final rawBlocks = data['blocks'];
    if (rawBlocks is! List) return const {};
    return {
      'schemaVersion': 1,
      'rationale': data['summary'],
      'blocks': [
        for (final value in rawBlocks)
          if (value is Map)
            {
              'id': value['id'],
              'startAt': '${value['date']}T${value['startTime']}',
              'endAt': '${value['date']}T${value['endTime']}',
              'moduleId': value['moduleId'],
              'topicId': null,
              'objective': value['objective'],
              'recommendedMethod': value['method'],
              'breakMinutes': _breakMinutes(value['breakGuidance']),
              'priority': value['priority'],
              'reason': value['reason'],
            },
      ],
    };
  }

  int _breakMinutes(Object? guidance) {
    final match = RegExp(
      r'\b(\d{1,3})\b',
    ).firstMatch(guidance?.toString() ?? '');
    return (int.tryParse(match?.group(1) ?? '') ?? 10).clamp(0, 120);
  }
}
