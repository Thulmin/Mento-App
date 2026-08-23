// Defines saved assistant conversations and user-approved data-change proposals.

import 'model_utils.dart';

enum AiMessageRole { user, assistant, tool }

enum AiActionOperation { create, update, delete }

enum AiActionResource {
  module,
  topic,
  assignment,
  examination,
  studyTask,
  timetableEvent,
  habit,
}

final class AiConversationAction {
  AiConversationAction({
    required this.actionId,
    required this.operation,
    required this.resource,
    required this.reason,
    required this.requiresConfirmation,
    this.resourceId,
    Map<String, Object?> payload = const {},
  }) : payload = Map.unmodifiable(payload);

  final String actionId;
  final AiActionOperation operation;
  final AiActionResource resource;
  final String? resourceId;
  final Map<String, Object?> payload;
  final String reason;
  final bool requiresConfirmation;

  factory AiConversationAction.fromMap(
    Map<String, Object?> map,
  ) => AiConversationAction(
    actionId: ModelUtils.requiredString(map, 'actionId'),
    operation: ModelUtils.enumValue(map, 'operation', AiActionOperation.values),
    resource: ModelUtils.enumValue(map, 'resource', AiActionResource.values),
    resourceId: ModelUtils.optionalString(map, 'resourceId'),
    payload:
        map['payload'] == null
            ? const {}
            : ModelUtils.objectMap(map['payload'], field: 'payload'),
    reason: ModelUtils.requiredString(map, 'reason'),
    requiresConfirmation: ModelUtils.boolean(
      map,
      'requiresConfirmation',
      fallback: true,
    ),
  );

  Map<String, Object?> toMap() => {
    'actionId': actionId,
    'operation': operation.name,
    'resource': resource.name,
    'resourceId': resourceId,
    'payload': payload,
    'reason': reason,
    'requiresConfirmation': requiresConfirmation,
  };
}

final class AiConversationMessage {
  AiConversationMessage({
    required this.role,
    required this.content,
    required this.createdAt,
    this.disclaimer,
    List<AiConversationAction> actions = const [],
  }) : actions = List.unmodifiable(actions);

  final AiMessageRole role;
  final String content;
  final DateTime createdAt;
  final String? disclaimer;
  final List<AiConversationAction> actions;

  factory AiConversationMessage.fromMap(Map<String, Object?> map) =>
      AiConversationMessage(
        role: ModelUtils.enumValue(map, 'role', AiMessageRole.values),
        content: ModelUtils.requiredString(map, 'content'),
        createdAt: ModelUtils.dateTime(map, 'createdAt'),
        disclaimer: ModelUtils.optionalString(map, 'disclaimer'),
        actions:
            ModelUtils.list(map, 'actions')
                .map(
                  (value) => AiConversationAction.fromMap(
                    ModelUtils.objectMap(value, field: 'actions'),
                  ),
                )
                .toList(),
      );

  Map<String, Object?> toMap() => {
    'role': role.name,
    'content': content,
    'createdAt': createdAt,
    'disclaimer': disclaimer,
    'actions': actions.map((action) => action.toMap()).toList(),
  };
}

final class AiConversation {
  AiConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    List<AiConversationMessage> messages = const [],
    List<String> executedActionIds = const [],
    this.summary,
    this.provider,
    this.archived = false,
  }) : messages = List.unmodifiable(messages),
       executedActionIds = List.unmodifiable(executedActionIds);

  final String id;
  final String title;
  final List<AiConversationMessage> messages;
  final List<String> executedActionIds;
  final String? summary;
  final String? provider;
  final bool archived;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory AiConversation.fromMap(Map<String, Object?> map, {String? id}) =>
      AiConversation(
        id: id ?? ModelUtils.requiredString(map, 'id'),
        title: ModelUtils.requiredString(map, 'title'),
        messages:
            ModelUtils.list(map, 'messages')
                .map(
                  (value) => AiConversationMessage.fromMap(
                    ModelUtils.objectMap(value, field: 'messages'),
                  ),
                )
                .toList(),
        executedActionIds: ModelUtils.stringList(map, 'executedActionIds'),
        summary: ModelUtils.optionalString(map, 'summary'),
        provider: ModelUtils.optionalString(map, 'provider'),
        archived: ModelUtils.boolean(map, 'archived'),
        createdAt: ModelUtils.dateTime(
          map,
          'createdAt',
          fallback: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
        updatedAt: ModelUtils.dateTime(
          map,
          'updatedAt',
          fallback: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'messages': messages.map((message) => message.toMap()).toList(),
    'executedActionIds': executedActionIds,
    'summary': summary,
    'provider': provider,
    'archived': archived,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };

  AiConversation copyWith({
    String? title,
    List<AiConversationMessage>? messages,
    List<String>? executedActionIds,
    String? summary,
    String? provider,
    bool? archived,
    DateTime? updatedAt,
  }) => AiConversation(
    id: id,
    title: title ?? this.title,
    messages: messages ?? this.messages,
    executedActionIds: executedActionIds ?? this.executedActionIds,
    summary: summary ?? this.summary,
    provider: provider ?? this.provider,
    archived: archived ?? this.archived,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
