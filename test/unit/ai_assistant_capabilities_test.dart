import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mento/app/theme/theme_controller.dart';
import 'package:mento/core/network/mento_ai_client.dart';
import 'package:mento/data/models/models.dart';
import 'package:mento/data/repositories/repositories.dart';
import 'package:mento/features/ai_assistant/application/ai_assistant_controller.dart';
import 'package:mento/features/ai_assistant/application/assistant_action_executor.dart';
import 'package:mento/features/ai_assistant/application/assistant_context_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('assistant context and safe actions', () {
    test('builds bounded current-user academic context', () async {
      final repository = DemoStudentRepository(
        referenceDate: DateTime(2026, 7, 17),
      );
      addTearDown(repository.dispose);

      final snapshot = await const AssistantContextBuilder().build(repository);
      final modules = snapshot.data['modules']! as List<Object?>;
      final tasks = snapshot.data['tasks']! as List<Object?>;

      expect(modules, isNotEmpty);
      expect(
        modules.whereType<Map>().any(
          (module) => module['name'] == 'Mobile Application Engineering',
        ),
        isTrue,
      );
      expect(tasks, isNotEmpty);
      expect(snapshot.data, isNot(contains('email')));
      expect(snapshot.data, isNot(contains('latitude')));
      expect(snapshot.data, isNot(contains('longitude')));
    });

    test('applies only allowlisted owner-scoped proposals', () async {
      final repository = DemoStudentRepository(
        referenceDate: DateTime(2026, 7, 17),
      );
      addTearDown(repository.dispose);
      final executor = const AssistantActionExecutor();
      final dueAt = DateTime(2026, 7, 20, 15);
      final action = AiConversationAction(
        actionId: 'create-review-task',
        operation: AiActionOperation.create,
        resource: AiActionResource.studyTask,
        reason: 'Prepare for the next mobile engineering session.',
        requiresConfirmation: true,
        payload: {
          'title': 'Review mobile architecture notes',
          'moduleId': 'demo-cs101',
          'dueAt': dueAt.toIso8601String(),
          'estimatedMinutes': 45,
          'priority': 'high',
        },
      );

      expect(await executor.apply(action, repository), 'Study task created.');
      final tasks = await repository.watchStudyTasks().first;
      expect(
        tasks.where(
          (task) =>
              task.title == 'Review mobile architecture notes' &&
              task.isAiGenerated,
        ),
        hasLength(1),
      );

      final unsafe = AiConversationAction(
        actionId: 'unsafe-path',
        operation: AiActionOperation.create,
        resource: AiActionResource.studyTask,
        reason: 'Unsafe proposal',
        requiresConfirmation: true,
        payload: {
          'title': 'Unsafe',
          'dueAt': dueAt.toIso8601String(),
          'firestorePath': 'users/another-user/private',
        },
      );
      await expectLater(
        executor.apply(unsafe, repository),
        throwsA(isA<AssistantActionException>()),
      );

      final unconfirmed = AiConversationAction(
        actionId: 'unconfirmed',
        operation: AiActionOperation.delete,
        resource: AiActionResource.studyTask,
        resourceId: tasks.first.id,
        reason: 'Unconfirmed deletion',
        requiresConfirmation: false,
      );
      await expectLater(
        executor.apply(unconfirmed, repository),
        throwsA(isA<AssistantActionException>()),
      );
    });

    test('conversation actions and messages round-trip', () {
      final now = DateTime.utc(2026, 7, 17, 8);
      final conversation = AiConversation(
        id: 'conversation-1',
        title: 'Plan this week',
        messages: [
          AiConversationMessage(
            role: AiMessageRole.assistant,
            content: 'I can create a task after you confirm.',
            createdAt: now,
            actions: [
              AiConversationAction(
                actionId: 'action-1',
                operation: AiActionOperation.create,
                resource: AiActionResource.studyTask,
                reason: 'Start with the nearest deadline.',
                requiresConfirmation: true,
                payload: const {'title': 'Draft outline'},
              ),
            ],
          ),
        ],
        executedActionIds: const ['action-0'],
        createdAt: now,
        updatedAt: now,
      );

      final decoded = AiConversation.fromMap(conversation.toMap());
      expect(decoded.id, conversation.id);
      expect(decoded.messages.single.actions.single.actionId, 'action-1');
      expect(decoded.executedActionIds, ['action-0']);
    });
  });

  group('assistant request and history isolation', () {
    test('safe demo assistant answers from local minimised context', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = DemoStudentRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          studentRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await Future<void>.delayed(Duration.zero);
        repository.dispose();
      });

      container.read(aiAssistantProvider);
      await _waitUntil(
        () => !container.read(aiAssistantProvider).loadingHistory,
      );
      await container
          .read(aiAssistantProvider.notifier)
          .send('What study modules have I added?');

      final state = container.read(aiAssistantProvider);
      expect(state.error, isNull);
      expect(state.sending, isFalse);
      expect(
        state.messages.last.content,
        contains('Safe Demo found 4 modules'),
      );
      expect(state.messages.last.disclaimer, contains('generated locally'));
    });

    test(
      'a stale cancelled response cannot overwrite a newer request',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final repository = DemoStudentRepository(ownerId: 'student-a');
        final gateway = _QueuedAiGateway();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            studentRepositoryProvider.overrideWithValue(repository),
            aiClientProvider.overrideWithValue(gateway),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await Future<void>.delayed(Duration.zero);
          repository.dispose();
        });

        container.read(aiAssistantProvider);
        await _waitUntil(
          () => !container.read(aiAssistantProvider).loadingHistory,
        );
        final controller = container.read(aiAssistantProvider.notifier);

        final first = controller.send('First request');
        await gateway.waitForRequests(1);
        controller.stopWaiting();
        final second = controller.send('Second request');
        await gateway.waitForRequests(2);

        gateway.complete(0, {'reply': 'Stale response'});
        await first;
        gateway.complete(1, {'reply': 'Current response'});
        await second;

        final messages = container.read(aiAssistantProvider).messages;
        expect(
          messages.any((message) => message.content == 'Current response'),
          isTrue,
        );
        expect(
          messages.any((message) => message.content == 'Stale response'),
          isFalse,
        );
        expect(container.read(aiAssistantProvider).sending, isFalse);
      },
    );

    test(
      'synced conversation history remains isolated by repository owner',
      () async {
        SharedPreferences.setMockInitialValues({
          'mento.ai_assistant.history': [
            '{"role":"user","content":"legacy private message"}',
          ],
        });
        final preferences = await SharedPreferences.getInstance();
        final ownerA = DemoStudentRepository(ownerId: 'student-a');
        final ownerB = DemoStudentRepository(ownerId: 'student-b');
        final now = DateTime.utc(2026, 7, 17, 8);
        await ownerA.saveAiConversation(
          AiConversation(
            id: 'private-a',
            title: 'Student A history',
            messages: [
              AiConversationMessage(
                role: AiMessageRole.user,
                content: 'Only student A should see this.',
                createdAt: now,
              ),
            ],
            createdAt: now,
            updatedAt: now,
          ),
        );

        final containerA = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            studentRepositoryProvider.overrideWithValue(ownerA),
          ],
        );
        containerA.read(aiAssistantProvider);
        await _waitUntil(
          () => !containerA.read(aiAssistantProvider).loadingHistory,
        );
        expect(
          containerA.read(aiAssistantProvider).conversations,
          hasLength(1),
        );
        containerA.dispose();
        await Future<void>.delayed(Duration.zero);

        final containerB = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            studentRepositoryProvider.overrideWithValue(ownerB),
          ],
        );
        addTearDown(() async {
          containerB.dispose();
          await Future<void>.delayed(Duration.zero);
          ownerA.dispose();
          ownerB.dispose();
        });
        containerB.read(aiAssistantProvider);
        await _waitUntil(
          () => !containerB.read(aiAssistantProvider).loadingHistory,
        );

        expect(containerB.read(aiAssistantProvider).conversations, isEmpty);
        expect(preferences.containsKey('mento.ai_assistant.history'), isFalse);
      },
    );
  });
}

final class _QueuedAiGateway implements MentoAiGateway {
  final List<Completer<Map<String, dynamic>>> _requests = [];

  @override
  Future<Map<String, dynamic>> post(
    AiEndpoint endpoint,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) {
    final completer = Completer<Map<String, dynamic>>();
    _requests.add(completer);
    return completer.future;
  }

  Future<void> waitForRequests(int count) =>
      _waitUntil(() => _requests.length >= count);

  void complete(int index, Map<String, dynamic> response) {
    _requests[index].complete(response);
  }
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final stopwatch = Stopwatch()..start();
  while (!condition()) {
    if (stopwatch.elapsed > timeout) {
      throw TimeoutException('Condition was not met in $timeout.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
