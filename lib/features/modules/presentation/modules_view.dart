// Presents modules and topics with progress, search, and management actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_states.dart';
import '../../../data/models/models.dart';
import '../../academic_organizer/application/academic_organizer_controller.dart';
import '../../academic_organizer/application/academic_organizer_providers.dart';
import '../../academic_organizer/presentation/organizer_data.dart';
import 'module_form.dart';

class ModulesView extends ConsumerWidget {
  const ModulesView({required this.data, required this.filter, super.key});

  final AcademicOrganizerData data;
  final AcademicOrganizerFilter filter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = filter.search.toLowerCase();
    final modules =
        data.modules.where((module) {
          if (filter.moduleId != null && filter.moduleId != module.id) {
            return false;
          }
          return query.isEmpty ||
              module.name.toLowerCase().contains(query) ||
              module.code.toLowerCase().contains(query) ||
              (module.lecturer?.toLowerCase().contains(query) ?? false);
        }).toList();
    if (modules.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: MentoEmptyState(
          title: 'No matching modules',
          message: 'Add a module or clear the current filters.',
          icon: Icons.menu_book_outlined,
          actionLabel: 'Add module',
          onAction: () => showModuleForm(context),
        ),
      );
    }
    return MentoResponsiveGrid(
      compactColumns: 1,
      mediumColumns: 2,
      expandedColumns: 2,
      children: [
        for (final module in modules)
          _ModuleCard(module: module, topics: data.topicsFor(module.id)),
      ],
    );
  }
}

class _ModuleCard extends ConsumerWidget {
  const _ModuleCard({required this.module, required this.topics});

  final Module module;
  final List<Topic> topics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = _color(
      module.colorHex,
      Theme.of(context).colorScheme.primary,
    );
    return MentoCard(
      semanticLabel: '${module.code}, ${module.name}, ${topics.length} topics',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(Icons.menu_book_outlined, color: accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module.code,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      module.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (module.lecturer != null)
                      Text(
                        module.lecturer!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              PopupMenuButton<_ModuleAction>(
                tooltip: 'Actions for ${module.name}',
                onSelected: (action) {
                  if (action == _ModuleAction.edit) {
                    showModuleForm(context, module: module);
                  } else {
                    _confirmDelete(context, ref);
                  }
                },
                itemBuilder:
                    (_) => const [
                      PopupMenuItem(
                        value: _ModuleAction.edit,
                        child: Text('Edit module'),
                      ),
                      PopupMenuItem(
                        value: _ModuleAction.delete,
                        child: Text('Delete module'),
                      ),
                    ],
              ),
            ],
          ),
          if (module.notes != null) ...[
            const SizedBox(height: 10),
            Text(module.notes!, maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const Divider(height: 28),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Topics',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              TextButton.icon(
                onPressed: () => showTopicForm(context, module: module),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
              ),
            ],
          ),
          if (topics.isEmpty)
            const Text('No topics yet.')
          else
            for (final topic in topics)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(topic.name),
                subtitle: Text('${(topic.mastery * 100).round()}% mastery'),
                trailing: PopupMenuButton<_TopicAction>(
                  tooltip: 'Actions for ${topic.name}',
                  onSelected: (action) {
                    if (action == _TopicAction.edit) {
                      showTopicForm(context, module: module, topic: topic);
                    } else {
                      _deleteTopic(context, ref, topic);
                    }
                  },
                  itemBuilder:
                      (_) => const [
                        PopupMenuItem(
                          value: _TopicAction.edit,
                          child: Text('Edit'),
                        ),
                        PopupMenuItem(
                          value: _TopicAction.delete,
                          child: Text('Delete'),
                        ),
                      ],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final cascade = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('Delete ${module.code}?'),
            content: const Text(
              'Deleting linked data also removes this module’s topics, timetable '
              'events, assignments, examinations and study tasks.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Module only'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete linked data'),
              ),
            ],
          ),
    );
    if (cascade == null) return;
    await ref
        .read(academicOrganizerControllerProvider.notifier)
        .deleteModule(module.id, cascade: cascade);
  }

  Future<void> _deleteTopic(
    BuildContext context,
    WidgetRef ref,
    Topic topic,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete topic?'),
            content: Text('Remove ${topic.name} from ${module.code}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (confirmed == true) {
      await ref
          .read(academicOrganizerControllerProvider.notifier)
          .deleteTopic(topic.id);
    }
  }
}

enum _ModuleAction { edit, delete }

enum _TopicAction { edit, delete }

Color _color(String raw, Color fallback) {
  final value = int.tryParse(raw.replaceFirst('#', ''), radix: 16);
  return value == null ? fallback : Color(0xFF000000 | value);
}
