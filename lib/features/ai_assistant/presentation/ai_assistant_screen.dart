// Presents chat history, suggested prompts, and previews of proposed changes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_controls.dart';
import '../../../data/models/models.dart';
import '../application/ai_assistant_controller.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiAssistantProvider);
    ref.listen(aiAssistantProvider, (previous, next) {
      if (previous?.messages.length != next.messages.length ||
          previous?.sending != next.sending) {
        _scrollToLatest();
      }
    });
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          identifier: 'mento_screen_ai_assistant',
          child: const Text('Mento assistant'),
        ),
        actions: [
          MentoIconButton(
            icon: Icons.history_outlined,
            tooltip: 'Conversation history',
            onPressed: () => _showHistory(context),
          ),
          MentoIconButton(
            icon: Icons.add_comment_outlined,
            tooltip: 'New conversation',
            semanticIdentifier: 'mento_ai_new_conversation',
            onPressed:
                state.sending
                    ? null
                    : () =>
                        ref
                            .read(aiAssistantProvider.notifier)
                            .startNewConversation(),
          ),
          MentoIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete this conversation',
            onPressed:
                state.activeConversationId == null
                    ? null
                    : () => _confirmDelete(
                      context,
                      state.activeConversationId!,
                      state.activeConversation?.title,
                    ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: context.contentMaxWidth,
                    ),
                    child: Padding(
                      padding: context.pagePadding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          MentoCard(
                            highlighted: true,
                            child: const Text(
                              'Mento can use your synced modules, deadlines, '
                              'tasks, timetable and study progress to give '
                              'account-specific help. It can propose changes, '
                              'but nothing is created, edited or deleted until '
                              'you review and confirm it.',
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (state.loadingHistory && state.messages.isEmpty)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator(),
                              ),
                            ),
                          if (!state.loadingHistory && state.messages.isEmpty)
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final prompt in const [
                                  'What study modules have I added?',
                                  'Help me prioritise this week',
                                  'Create a task for my nearest deadline',
                                  'Suggest a balanced revision method',
                                ])
                                  ActionChip(
                                    label: Text(prompt),
                                    onPressed:
                                        state.sending
                                            ? null
                                            : () => _send(prompt),
                                  ),
                              ],
                            ),
                          for (final message in state.messages)
                            _MessageBubble(
                              message: message,
                              state: state,
                              onApply:
                                  (action) => _confirmAction(context, action),
                            ),
                          if (state.sending) ...[
                            const SizedBox(height: 10),
                            const LinearProgressIndicator(),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed:
                                    () =>
                                        ref
                                            .read(aiAssistantProvider.notifier)
                                            .stopWaiting(),
                                icon: const Icon(Icons.stop_circle_outlined),
                                label: const Text('Stop waiting'),
                              ),
                            ),
                          ],
                          if (state.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Semantics(
                                identifier: 'mento_ai_error',
                                container: true,
                                child: Material(
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      10,
                                      4,
                                      10,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            state.error!,
                                            style: TextStyle(
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onErrorContainer,
                                            ),
                                          ),
                                        ),
                                        Semantics(
                                          identifier: 'mento_ai_dismiss_error',
                                          child: IconButton(
                                            tooltip: 'Dismiss message',
                                            onPressed:
                                                () =>
                                                    ref
                                                        .read(
                                                          aiAssistantProvider
                                                              .notifier,
                                                        )
                                                        .clearError(),
                                            icon: const Icon(Icons.close),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _Composer(
              controller: _controller,
              sending: state.sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showHistory(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (sheetContext) => FractionallySizedBox(
          heightFactor: 0.78,
          child: SafeArea(
            child: Consumer(
              builder: (context, ref, _) {
                final state = ref.watch(aiAssistantProvider);
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Conversation history',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TextButton.icon(
                            onPressed:
                                state.sending
                                    ? null
                                    : () {
                                      ref
                                          .read(aiAssistantProvider.notifier)
                                          .startNewConversation();
                                      Navigator.of(sheetContext).pop();
                                    },
                            icon: const Icon(Icons.add),
                            label: const Text('New'),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child:
                          state.conversations.isEmpty
                              ? const Center(
                                child: Text('No saved conversations yet.'),
                              )
                              : ListView.separated(
                                itemCount: state.conversations.length,
                                separatorBuilder:
                                    (_, _) => const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final conversation =
                                      state.conversations[index];
                                  final selected =
                                      conversation.id ==
                                      state.activeConversationId;
                                  return ListTile(
                                    selected: selected,
                                    leading: Icon(
                                      selected
                                          ? Icons.chat
                                          : Icons.chat_bubble_outline,
                                    ),
                                    title: Text(
                                      conversation.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      _historySubtitle(conversation),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: IconButton(
                                      tooltip: 'Delete conversation',
                                      onPressed:
                                          () => _confirmDelete(
                                            sheetContext,
                                            conversation.id,
                                            conversation.title,
                                          ),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                    onTap: () {
                                      ref
                                          .read(aiAssistantProvider.notifier)
                                          .selectConversation(conversation.id);
                                      Navigator.of(sheetContext).pop();
                                    },
                                  );
                                },
                              ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
  );

  String _historySubtitle(AiConversation conversation) {
    final updated = DateFormat(
      'MMM d, HH:mm',
    ).format(conversation.updatedAt.toLocal());
    if (conversation.messages.isEmpty) return updated;
    return '$updated · ${conversation.messages.last.content}';
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String conversationId,
    String? title,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete conversation?'),
            content: Text(
              title == null
                  ? 'This removes the conversation from your synced history.'
                  : '“$title” will be removed from your synced history.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Keep'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await ref
        .read(aiAssistantProvider.notifier)
        .deleteConversation(conversationId);
  }

  Future<void> _confirmAction(
    BuildContext context,
    AiConversationAction action,
  ) async {
    final isDelete = action.operation == AiActionOperation.delete;
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(
              isDelete ? 'Confirm permanent deletion' : 'Apply this change?',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.reason),
                  if (action.payload.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _ActionPayload(payload: action.payload),
                  ],
                  if (isDelete) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Deletion cannot be undone.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style:
                    isDelete
                        ? FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                        )
                        : null,
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(isDelete ? 'Delete' : 'Confirm'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    await ref.read(aiAssistantProvider.notifier).applyConfirmedAction(action);
  }

  void _send(String text) {
    if (text.trim().isEmpty) return;
    _controller.clear();
    ref.read(aiAssistantProvider.notifier).send(text);
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    });
  }
}

final class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        10 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: MentoTextField(
              label: 'Ask Mento',
              semanticIdentifier: 'mento_ai_prompt',
              controller: controller,
              minLines: 1,
              maxLines: 4,
              enabled: !sending,
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(width: 8),
          MentoIconButton(
            icon: Icons.send,
            tooltip: 'Send to Mento',
            semanticIdentifier: 'mento_ai_send',
            onPressed: sending ? null : () => onSend(controller.text),
          ),
        ],
      ),
    ),
  );
}

final class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.state,
    required this.onApply,
  });

  final AiConversationMessage message;
  final AssistantState state;
  final ValueChanged<AiConversationAction> onApply;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == AiMessageRole.user;
    final isTool = message.role == AiMessageRole.tool;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      identifier:
          isUser
              ? 'mento_ai_user_message'
              : isTool
              ? 'mento_ai_tool_message'
              : 'mento_ai_assistant_message',
      container: true,
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color:
                isUser
                    ? scheme.primaryContainer
                    : isTool
                    ? scheme.tertiaryContainer
                    : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isTool) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 18,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Change applied',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              SelectableText(message.content),
              if (message.disclaimer != null) ...[
                const SizedBox(height: 8),
                Text(
                  message.disclaimer!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              for (final action in message.actions) ...[
                const SizedBox(height: 12),
                _ActionCard(
                  action: action,
                  applying: state.applyingActionIds.contains(action.actionId),
                  applied:
                      state.activeConversation?.executedActionIds.contains(
                        action.actionId,
                      ) ==
                      true,
                  result: state.actionResults[action.actionId],
                  onApply: () => onApply(action),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.action,
    required this.applying,
    required this.applied,
    required this.result,
    required this.onApply,
  });

  final AiConversationAction action;
  final bool applying;
  final bool applied;
  final String? result;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final isDelete = action.operation == AiActionOperation.delete;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_operationLabel(action.operation)} '
            '${_resourceLabel(action.resource)}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(action.reason),
          if (action.payload.isNotEmpty) ...[
            const SizedBox(height: 10),
            _ActionPayload(payload: action.payload),
          ],
          if (result != null) ...[
            const SizedBox(height: 8),
            Text(
              result!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: applied ? scheme.primary : scheme.error,
              ),
            ),
          ],
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: applying || applied ? null : onApply,
            icon:
                applying
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : Icon(
                      applied
                          ? Icons.check
                          : isDelete
                          ? Icons.delete_outline
                          : Icons.edit_outlined,
                    ),
            label: Text(
              applied
                  ? 'Applied'
                  : applying
                  ? 'Applying…'
                  : 'Review and confirm',
            ),
          ),
        ],
      ),
    );
  }

  static String _operationLabel(AiActionOperation operation) =>
      switch (operation) {
        AiActionOperation.create => 'Create',
        AiActionOperation.update => 'Update',
        AiActionOperation.delete => 'Delete',
      };

  static String _resourceLabel(AiActionResource resource) => switch (resource) {
    AiActionResource.module => 'module',
    AiActionResource.topic => 'topic',
    AiActionResource.assignment => 'assignment',
    AiActionResource.examination => 'examination',
    AiActionResource.studyTask => 'study task',
    AiActionResource.timetableEvent => 'timetable event',
    AiActionResource.habit => 'habit',
  };
}

final class _ActionPayload extends StatelessWidget {
  const _ActionPayload({required this.payload});

  final Map<String, Object?> payload;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in payload.entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text('${_fieldLabel(entry.key)}: ${_value(entry.value)}'),
          ),
      ],
    ),
  );

  static String _fieldLabel(String value) =>
      value
          .replaceAllMapped(
            RegExp(r'([a-z])([A-Z])'),
            (match) => '${match.group(1)} ${match.group(2)}',
          )
          .replaceAll('_', ' ')
          .trim();

  static String _value(Object? value) => switch (value) {
    null => 'Not set',
    List values => values.join(', '),
    _ => value.toString(),
  };
}
