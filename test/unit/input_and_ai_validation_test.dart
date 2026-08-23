import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mento/core/logic/logic.dart';
import 'package:mento/data/models/models.dart';

void main() {
  group('InputValidator', () {
    test('validates registration fields', () {
      expect(InputValidator.preferredName('Thulmini Perera'), isNull);
      expect(InputValidator.preferredName('  '), isNotNull);
      expect(InputValidator.email('student@example.edu'), isNull);
      expect(InputValidator.email('student@@example.edu'), isNotNull);
      expect(
        InputValidator.confirmPassword('Different', 'Original'),
        isNotNull,
      );
    });

    test('returns every unmet password requirement', () {
      final issues = InputValidator.passwordRequirements('short');

      expect(issues, hasLength(4));
      expect(issues.any((issue) => issue.contains('10')), isTrue);
      expect(issues.any((issue) => issue.contains('uppercase')), isTrue);
      expect(issues.any((issue) => issue.contains('number')), isTrue);
      expect(issues.any((issue) => issue.contains('symbol')), isTrue);
      expect(InputValidator.password('StrongPass1!'), isNull);
    });

    test('validates durations, date order, and coordinates', () {
      expect(InputValidator.positiveMinutes(0), isNotNull);
      expect(InputValidator.positiveMinutes(45), isNull);
      expect(
        InputValidator.dateRange(
          DateTime(2026, 1, 1, 10),
          DateTime(2026, 1, 1, 9),
        ),
        isNotNull,
      );
      expect(InputValidator.coordinates(6.9271, 79.8612), isNull);
      expect(InputValidator.coordinates(91, 79.8612), isNotNull);
    });
  });

  group('AiStudyPlanValidator', () {
    final rangeStart = DateTime.utc(2026, 1, 5);
    final rangeEnd = DateTime.utc(2026, 1, 7);
    final generatedAt = DateTime.utc(2026, 1, 4, 18);

    Map<String, Object?> block({
      String id = 'block-1',
      String moduleId = 'm1',
      String startAt = '2026-01-05T09:00:00Z',
      String endAt = '2026-01-05T09:50:00Z',
    }) => {
      'id': id,
      'startAt': startAt,
      'endAt': endAt,
      'moduleId': moduleId,
      'topicId': 'topic-1',
      'objective': 'Review algorithms',
      'recommendedMethod': 'Active recall',
      'breakMinutes': 10,
      'priority': 'high',
      'reason': 'Exam is approaching',
    };

    AiStudyPlanValidationResult validate(Object payload) =>
        AiStudyPlanValidator.validate(
          jsonEncode(payload),
          planId: 'ai-plan',
          userId: 'user-1',
          allowedModuleIds: {'m1'},
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          generatedAt: generatedAt,
        );

    test('accepts valid structured JSON and forces trusted source fields', () {
      final result = validate({
        'schemaVersion': 1,
        'rationale': 'Deadline-aware plan',
        'blocks': [block()],
      });

      expect(result.isValid, isTrue);
      expect(result.plan!.source, PlanSource.artificialIntelligence);
      expect(
        result.plan!.blocks.single.source,
        PlanSource.artificialIntelligence,
      );
      expect(result.plan!.blocks.single.moduleId, 'm1');
    });

    test('accepts separate date and time fields', () {
      final result = validate({
        'schemaVersion': 1,
        'blocks': [
          {
            ...block()
              ..remove('startAt')
              ..remove('endAt'),
            'date': '2026-01-05',
            'startTime': '10:00:00Z',
            'endTime': '10:30:00Z',
          },
        ],
      });

      expect(result.isValid, isTrue);
      expect(result.plan!.blocks.single.duration, const Duration(minutes: 30));
    });

    test('rejects unknown modules, overlapping blocks, and invalid JSON', () {
      final unknown = validate({
        'schemaVersion': 1,
        'blocks': [block(moduleId: 'another-user-module')],
      });
      expect(unknown.isValid, isFalse);
      expect(
        unknown.issues.any((issue) => issue.message.contains('not available')),
        isTrue,
      );

      final overlap = validate({
        'schemaVersion': 1,
        'blocks': [
          block(),
          block(
            id: 'block-2',
            startAt: '2026-01-05T09:30:00Z',
            endAt: '2026-01-05T10:00:00Z',
          ),
        ],
      });
      expect(overlap.isValid, isFalse);
      expect(
        overlap.issues.any((issue) => issue.message.contains('overlap')),
        isTrue,
      );

      final malformed = AiStudyPlanValidator.validate(
        'not-json',
        planId: 'ai-plan',
        userId: 'user-1',
        allowedModuleIds: {'m1'},
        rangeStart: rangeStart,
        rangeEnd: rangeEnd,
        generatedAt: generatedAt,
      );
      expect(malformed.isValid, isFalse);
    });

    test('parse throws a typed exception on untrusted output', () {
      expect(
        () => AiStudyPlanValidator.parse(
          jsonEncode({'schemaVersion': 1, 'blocks': []}),
          planId: 'ai-plan',
          userId: 'user-1',
          allowedModuleIds: {'m1'},
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          generatedAt: generatedAt,
        ),
        throwsA(isA<AiStructuredResponseException>()),
      );
    });
  });
}
