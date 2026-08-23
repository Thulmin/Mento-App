// Manages assistant conversations, cancellation, and confirmation-gated actions.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/theme_controller.dart';
import '../../../core/network/mento_ai_client.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import 'assistant_action_executor.dart';
import 'assistant_context_builder.dart';

final class AssistantState {
  const AssistantState({
    this.conversations = const [],
    this.messages = const [],
    this.activeConversationId,
    this.loadingHistory = true,
    this.sending = false,
    this.error,
    this.applyingActionIds = const {},
    this.actionResults = const {},
  });

  final List<AiConversation> conversations;
  final List<AiConversationMessage> messages;
  final String? activeConversationId;
  final bool loadingHistory;
  final bool sending;
  final String? error;
  final Set<String> applyingActionIds;
  final Map<String, String> actionResults;

  AiConversation? get activeConversation {
    final id = activeConversationId;
    if (id == null) return null;
    for (final conversation in conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  AssistantState copyWith({
    List<AiConversation>? conversations,
    List<AiConversationMessage>? messages,
    String? activeConversationId,
    bool clearActiveConversationId = false,
    bool? loadingHistory,
    bool? sending,
    String? error,
    bool clearError = false,
    Set<String>? applyingActionIds,
    Map<String, String>? actionResults,
  }) => AssistantState(
    conversations: conversations ?? this.conversations,
    messages: messages ?? this.messages,
    activeConversationId:
        clearActiveConversationId
            ? null
            : activeConversationId ?? this.activeConversationId,
    loadingHistory: loadingHistory ?? this.loadingHistory,
    sending: sending ?? this.sending,
    error: clearError ? null : error ?? this.error,
    applyingActionIds: applyingActionIds ?? this.applyingActionIds,
    actionResults: actionResults ?? this.actionResults,
  );
}

final aiClientProvider = Provider<MentoAiGateway>((ref) {
  final repository = ref.watch(studentRepositoryProvider);
  return repository.isDemo ? const _SafeDemoAiGateway() : MentoAiClient();
});

/// Keeps Safe Demo useful without weakening the authenticated AI proxy.
///
/// The demo repository is memory-only and has no Firebase user whose ID token
/// could authenticate a real Worker request. This gateway produces a clearly
/// labelled response from the same privacy-minimised context that would be sent
/// by an authenticated account. Non-chat requests still fall back to the
/// existing deterministic planner.
final class _SafeDemoAiGateway implements MentoAiGateway {
  const _SafeDemoAiGateway();

  @override
  Future<Map<String, dynamic>> post(
    AiEndpoint endpoint,
    Map<String, Object?> input, {
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled == true) {
      throw const AiClientFailure(
        'The AI request was cancelled.',
        code: 'cancelled',
      );
    }
    if (endpoint != AiEndpoint.chat) {
      throw const AiClientFailure(
        'Safe Demo uses the deterministic offline planner.',
        code: 'demo-offline-planner',
      );
    }

    final context = input['context'];
    final rawModules = context is Map ? context['modules'] : null;
    final names = <String>[];
    if (rawModules is List) {
      for (final rawModule in rawModules) {
        if (rawModule is! Map) continue;
        final name = rawModule['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) names.add(name);
      }
    }
    final moduleSummary = names.isEmpty ? 'no modules yet' : names.join(', ');

    return {
      'reply':
          'Safe Demo found ${names.length} modules in the memory-only '
          'workspace: $moduleSummary. In a signed-in session, Mento sends the '
          'same minimised academic context to the authenticated AI proxy.',
      'disclaimer':
          'Safe Demo response generated locally; no AI provider was contacted.',
      'dataActions': const <Object?>[],
    };
  }
}

final assistantContextBuilderProvider = Provider<AssistantContextBuilder>(
  (ref) => const AssistantContextBuilder(),
);

final assistantActionExecutorProvider = Provider<AssistantActionExecutor>(
  (ref) => const AssistantActionExecutor(),
);

final aiAssistantProvider =
    NotifierProvider<AiAssistantController, AssistantState>(
      AiAssistantController.new,
    );

final class AiAssistantController extends Notifier<AssistantState> {
  static const _uuid = Uuid();
  static const _legacyHistoryKey = 'mento.ai_assistant.history';
  static const _blankConversationMarker = '__new__';

  StreamSubscription<List<AiConversation>>? _historySubscription;
  CancelToken? _cancelToken;
  String? _restoredActiveId;
  bool _preferBlankConversation = false;
  bool _disposed = false;
  int _historyGeneration = 0;
  int _requestGeneration = 0;

  StudentRepository get _repository => ref.read(studentRepositoryProvider);

  @override
  AssistantState build() {
    _disposed = false;
    final repository = ref.watch(studentRepositoryProvider);
    final preferences = ref.watch(sharedPreferencesProvider);
    final stored = preferences.getString(_activePreferenceKey(repository));
    _preferBlankConversation = stored == _blankConversationMarker;
    _restoredActiveId =
        stored == null || stored == _blankConversationMarker ? null : stored;

    // Earlier versions stored every account's messages under one device-wide
    // key. Remove that privacy-sensitive cache; Firestore history is owner
    // scoped by the active repository instead.
    unawaited(preferences.remove(_legacyHistoryKey));

    final generation = ++_historyGeneration;
    unawaited(_subscribeToHistory(repository, generation));
    ref.onDispose(() {
      _disposed = true;
      _requestGeneration++;
      _cancelToken?.cancel('disposed');
      unawaited(_historySubscription?.cancel());
    });
    return const AssistantState();
  }

  Future<void> _subscribeToHistory(
    StudentRepository repository,
    int generation,
  ) async {
    await _historySubscription?.cancel();
    if (_disposed || generation != _historyGeneration) return;
    _historySubscription = repository
        .watchAiConversations(limit: 30)
        .listen(
          (conversations) =>
              _receiveHistory(repository, generation, conversations),
          onError: (Object _) {
            if (_disposed || generation != _historyGeneration) return;
            state = state.copyWith(
              loadingHistory: false,
              error:
                  'Mento could not load your synced conversation history. '
                  'Your academic data is still safe.',
            );
          },
        );
  }

  void _receiveHistory(
    StudentRepository repository,
    int generation,
    List<AiConversation> remoteConversations,
  ) {
    if (_disposed ||
        generation != _historyGeneration ||
        repository.ownerId != _repository.ownerId) {
      return;
    }
    final conversations = _mergeWithLocal(remoteConversations);
    var activeId = state.activeConversationId;
    if (activeId == null && !_preferBlankConversation) {
      final restoredExists = conversations.any(
        (conversation) => conversation.id == _restoredActiveId,
      );
      activeId =
          restoredExists
              ? _restoredActiveId
              : (conversations.isEmpty ? null : conversations.first.id);
    }
    final active = _findConversation(conversations, activeId);
    final keepPendingLocalMessages =
        state.sending &&
        activeId != null &&
        activeId == state.activeConversationId &&
        state.messages.length > (active?.messages.length ?? 0);
    state = state.copyWith(
      conversations: conversations,
      messages:
          keepPendingLocalMessages
              ? state.messages
              : (active?.messages ?? const []),
      activeConversationId: activeId,
      clearActiveConversationId: activeId == null,
      loadingHistory: false,
      clearError: state.error?.contains('conversation history') == true,
    );
    if (activeId != null) _rememberActiveConversation(activeId);
  }

  Future<void> send(String rawMessage) async {
    final trimmed = rawMessage.trim();
    if (trimmed.isEmpty || state.sending) return;
    final content =
        trimmed.length > 4000 ? trimmed.substring(0, 4000) : trimmed;
    final requestGeneration = ++_requestGeneration;
    final now = DateTime.now();
    final userMessage = AiConversationMessage(
      role: AiMessageRole.user,
      content: content,
      createdAt: now,
    );
    final previous = state.activeConversation;
    final conversation =
        previous ??
        AiConversation(
          id: _uuid.v4(),
          title: _conversationTitle(content),
          createdAt: now,
          updatedAt: now,
        );
    final withUserMessage = conversation.copyWith(
      messages: _boundedMessages([...conversation.messages, userMessage]),
      updatedAt: now,
    );

    _preferBlankConversation = false;
    _rememberActiveConversation(withUserMessage.id);
    state = state.copyWith(
      activeConversationId: withUserMessage.id,
      sending: true,
      clearError: true,
    );

    try {
      await _persistConversation(withUserMessage);
      if (!_isCurrentRequest(requestGeneration)) return;

      final localSafety = _localSafetyResponse(content);
      if (localSafety != null) {
        final safeConversation = withUserMessage.copyWith(
          messages: _boundedMessages([
            ...withUserMessage.messages,
            AiConversationMessage(
              role: AiMessageRole.assistant,
              content: localSafety,
              createdAt: DateTime.now(),
              disclaimer: 'Mento cannot diagnose or replace qualified support.',
            ),
          ]),
          updatedAt: DateTime.now(),
        );
        await _persistConversation(safeConversation);
        return;
      }

      final snapshot = await ref
          .read(assistantContextBuilderProvider)
          .build(_repository);
      if (!_isCurrentRequest(requestGeneration)) return;

      final earlierMessages =
          withUserMessage.messages
              .take(withUserMessage.messages.length - 1)
              .where(
                (message) =>
                    message.role == AiMessageRole.user ||
                    message.role == AiMessageRole.assistant,
              )
              .toList();
      final conversationWindow =
          earlierMessages.length <= 12
              ? earlierMessages
              : earlierMessages.sublist(earlierMessages.length - 12);

      final cancelToken = CancelToken();
      _cancelToken = cancelToken;
      final data = await ref.read(aiClientProvider).post(AiEndpoint.chat, {
        'message': content,
        if (conversationWindow.isNotEmpty)
          'conversation': [
            for (final message in conversationWindow)
              {'role': message.role.name, 'content': message.content},
          ],
        'context': snapshot.data,
      }, cancelToken: cancelToken);
      if (!_isCurrentRequest(requestGeneration)) return;

      final reply = data['reply'];
      if (reply is! String || reply.trim().isEmpty) {
        throw const AiClientFailure(
          'The assistant returned an empty response.',
          code: 'invalid-response',
        );
      }
      final current =
          _findConversation(state.conversations, withUserMessage.id) ??
          withUserMessage;
      final completed = current.copyWith(
        messages: _boundedMessages([
          ...current.messages,
          AiConversationMessage(
            role: AiMessageRole.assistant,
            content: reply.trim(),
            createdAt: DateTime.now(),
            disclaimer: data['disclaimer']?.toString(),
            actions: _parseActions(data['dataActions']),
          ),
        ]),
        provider: 'mento-ai-proxy',
        updatedAt: DateTime.now(),
      );
      await _persistConversation(completed);
    } catch (error) {
      if (!_isCurrentRequest(requestGeneration)) return;
      final publicMessage =
          error is AiClientFailure
              ? error.message
              : error is StudentRepositoryException
              ? error.message
              : 'Mento is temporarily unavailable. Please try again.';
      state = state.copyWith(sending: false, error: publicMessage);
    } finally {
      if (_isCurrentRequest(requestGeneration)) {
        _cancelToken = null;
        state = state.copyWith(sending: false);
      }
    }
  }

  void stopWaiting() {
    if (!state.sending) return;
    _requestGeneration++;
    final token = _cancelToken;
    _cancelToken = null;
    token?.cancel('user-stopped-waiting');
    state = state.copyWith(
      sending: false,
      error:
          'Stopped waiting on this device. The provider may already be '
          'finishing the request, so no database change was applied.',
    );
  }

  void startNewConversation() {
    _preferBlankConversation = true;
    _restoredActiveId = null;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(
            _activePreferenceKey(_repository),
            _blankConversationMarker,
          ),
    );
    state = state.copyWith(
      messages: const [],
      clearActiveConversationId: true,
      clearError: true,
      actionResults: const {},
    );
  }

  void selectConversation(String conversationId) {
    final conversation = _findConversation(state.conversations, conversationId);
    if (conversation == null) return;
    _preferBlankConversation = false;
    _restoredActiveId = conversation.id;
    _rememberActiveConversation(conversation.id);
    state = state.copyWith(
      activeConversationId: conversation.id,
      messages: conversation.messages,
      clearError: true,
      actionResults: const {},
    );
  }

  Future<void> deleteConversation(String conversationId) async {
    if (conversationId == state.activeConversationId && state.sending) {
      stopWaiting();
    }
    try {
      await _repository.deleteAiConversation(conversationId);
      final remaining =
          state.conversations
              .where((conversation) => conversation.id != conversationId)
              .toList();
      final deletingActive = conversationId == state.activeConversationId;
      final next =
          deletingActive && remaining.isNotEmpty ? remaining.first : null;
      _preferBlankConversation = deletingActive && next == null;
      if (next != null) {
        _rememberActiveConversation(next.id);
      } else if (deletingActive) {
        unawaited(
          ref
              .read(sharedPreferencesProvider)
              .setString(
                _activePreferenceKey(_repository),
                _blankConversationMarker,
              ),
        );
      }
      state = state.copyWith(
        conversations: remaining,
        activeConversationId:
            deletingActive ? next?.id : state.activeConversationId,
        clearActiveConversationId: deletingActive && next == null,
        messages:
            deletingActive ? (next?.messages ?? const []) : state.messages,
        clearError: true,
        actionResults: const {},
      );
    } catch (error) {
      state = state.copyWith(
        error:
            error is StudentRepositoryException
                ? error.message
                : 'This conversation could not be deleted.',
      );
    }
  }

  Future<void> applyConfirmedAction(AiConversationAction action) async {
    final conversation = state.activeConversation;
    if (conversation == null ||
        conversation.executedActionIds.contains(action.actionId) ||
        state.applyingActionIds.contains(action.actionId)) {
      return;
    }
    state = state.copyWith(
      applyingActionIds: {...state.applyingActionIds, action.actionId},
      actionResults: Map.of(state.actionResults)..remove(action.actionId),
      clearError: true,
    );
    try {
      final result = await ref
          .read(assistantActionExecutorProvider)
          .apply(action, _repository);
      final latest =
          _findConversation(state.conversations, conversation.id) ??
          conversation;
      if (!latest.executedActionIds.contains(action.actionId)) {
        final updated = latest.copyWith(
          executedActionIds: [...latest.executedActionIds, action.actionId],
          messages: _boundedMessages([
            ...latest.messages,
            AiConversationMessage(
              role: AiMessageRole.tool,
              content: result,
              createdAt: DateTime.now(),
            ),
          ]),
          updatedAt: DateTime.now(),
        );
        await _persistConversation(updated);
      }
      state = state.copyWith(
        actionResults: {...state.actionResults, action.actionId: result},
      );
    } catch (error) {
      final message =
          error is AssistantActionException
              ? error.message
              : error is StudentRepositoryException
              ? error.message
              : 'The proposed change could not be applied.';
      state = state.copyWith(
        actionResults: {...state.actionResults, action.actionId: message},
      );
    } finally {
      state = state.copyWith(
        applyingActionIds:
            state.applyingActionIds
                .where((id) => id != action.actionId)
                .toSet(),
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> _persistConversation(AiConversation conversation) async {
    _putLocalConversation(conversation);
    await _repository.saveAiConversation(conversation);
  }

  void _putLocalConversation(AiConversation conversation) {
    final conversations = [
      conversation,
      for (final existing in state.conversations)
        if (existing.id != conversation.id) existing,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = state.copyWith(
      conversations: List.unmodifiable(conversations.take(30)),
      messages:
          state.activeConversationId == conversation.id
              ? conversation.messages
              : state.messages,
    );
  }

  List<AiConversation> _mergeWithLocal(
    List<AiConversation> remoteConversations,
  ) {
    final localById = {
      for (final conversation in state.conversations)
        conversation.id: conversation,
    };
    final merged = <AiConversation>[];
    for (final remote in remoteConversations) {
      final local = localById.remove(remote.id);
      final keepLocal =
          local != null &&
          local.messages.length >= remote.messages.length &&
          local.updatedAt.isAfter(remote.updatedAt);
      merged.add(keepLocal ? local : remote);
    }
    if (state.sending) {
      merged.addAll(localById.values);
    }
    merged.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(merged.take(30));
  }

  List<AiConversationAction> _parseActions(Object? rawActions) {
    if (rawActions is! List) return const [];
    final actions = <AiConversationAction>[];
    final seenIds = <String>{};
    for (final raw in rawActions.take(8)) {
      if (raw is! Map || raw['requiresConfirmation'] != true) continue;
      try {
        final map = raw.map(
          (key, value) => MapEntry(key.toString(), value as Object?),
        );
        final action = AiConversationAction.fromMap(map);
        final resourceId = action.resourceId;
        if (action.actionId.contains('/') ||
            action.actionId.length > 128 ||
            action.payload.length > 20 ||
            (resourceId != null && resourceId.contains('/')) ||
            !seenIds.add(action.actionId)) {
          continue;
        }
        actions.add(action);
      } catch (_) {
        // A malformed model proposal is ignored and can never reach a
        // repository mutation.
      }
    }
    return List.unmodifiable(actions);
  }

  List<AiConversationMessage> _boundedMessages(
    List<AiConversationMessage> messages,
  ) => List.unmodifiable(
    messages.length <= 50 ? messages : messages.sublist(messages.length - 50),
  );

  bool _isCurrentRequest(int generation) =>
      !_disposed && generation == _requestGeneration;

  AiConversation? _findConversation(
    List<AiConversation> conversations,
    String? id,
  ) {
    if (id == null) return null;
    for (final conversation in conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  String _conversationTitle(String message) {
    final firstLine = message.split(RegExp(r'[\r\n]')).first.trim();
    if (firstLine.length <= 60) return firstLine;
    return '${firstLine.substring(0, 57).trimRight()}...';
  }

  void _rememberActiveConversation(String conversationId) {
    _restoredActiveId = conversationId;
    unawaited(
      ref
          .read(sharedPreferencesProvider)
          .setString(_activePreferenceKey(_repository), conversationId),
    );
  }

  String _activePreferenceKey(StudentRepository repository) =>
      'mento.ai_assistant.active.${repository.ownerId}';

  String? _localSafetyResponse(String input) {
    final lower = input.toLowerCase();
    if (RegExp(
      r'\b(diagnose|diagnosis|prescribe|medication dosage|am i depressed|do i have anxiety)\b',
    ).hasMatch(lower)) {
      return 'I can help you make a gentle study or rest plan, but I cannot '
          'diagnose a condition or recommend treatment. A qualified health '
          'professional or your university support service can give '
          'appropriate guidance.';
    }
    if (RegExp(
      r'\b(suicide|kill myself|self harm|hurt myself)\b',
    ).hasMatch(lower)) {
      return 'I’m really sorry you’re dealing with this. Please contact local '
          'emergency services or a trusted person who can stay with you now. '
          'Your university crisis or counselling service can also help. If '
          'you are in immediate danger, call your local emergency number now.';
    }
    return null;
  }
}
