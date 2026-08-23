// Collects and validates assignment details in a create-or-edit bottom sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../academic_organizer/application/academic_organizer_controller.dart';
import '../../academic_organizer/application/academic_organizer_providers.dart';
import '../../academic_organizer/presentation/organizer_form_support.dart';

Future<void> showAssignmentForm(
  BuildContext context, {
  required List<Module> modules,
  Assignment? assignment,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => AssignmentForm(modules: modules, assignment: assignment),
);

class AssignmentForm extends ConsumerStatefulWidget {
  const AssignmentForm({required this.modules, this.assignment, super.key});

  final List<Module> modules;
  final Assignment? assignment;

  @override
  ConsumerState<AssignmentForm> createState() => _AssignmentFormState();
}

class _AssignmentFormState extends ConsumerState<AssignmentForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _effort;
  late String? _moduleId;
  late DateTime _dueAt;
  late PriorityLevel _priority;
  late WorkStatus _status;
  late double _progress;
  late DateTime? _reminderAt;
  final List<_SubtaskDraft> _subtasks = [];

  @override
  void initState() {
    super.initState();
    final assignment = widget.assignment;
    _title = TextEditingController(text: assignment?.title);
    _description = TextEditingController(text: assignment?.description);
    _effort = TextEditingController(
      text: (assignment?.estimatedMinutes ?? 120).toString(),
    );
    _moduleId =
        assignment?.moduleId ??
        (widget.modules.isEmpty ? null : widget.modules.first.id);
    _dueAt = assignment?.dueAt ?? DateTime.now().add(const Duration(days: 7));
    _priority = assignment?.priority ?? PriorityLevel.medium;
    _status = assignment?.status ?? WorkStatus.notStarted;
    _progress = assignment?.manualProgress ?? 0;
    _reminderAt = assignment?.reminderAt;
    for (final subtask in assignment?.subtasks ?? const <Subtask>[]) {
      _subtasks.add(_SubtaskDraft.fromModel(subtask));
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _effort.dispose();
    for (final subtask in _subtasks) {
      subtask.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDue() async {
    final value = await pickOrganizerDateTime(context, _dueAt);
    if (value != null) setState(() => _dueAt = value);
  }

  Future<void> _pickReminder() async {
    final initial = _reminderAt ?? _dueAt.subtract(const Duration(days: 1));
    final value = await pickOrganizerDateTime(context, initial);
    if (value != null) setState(() => _reminderAt = value);
  }

  void _addSubtask() => setState(() => _subtasks.add(_SubtaskDraft.empty()));

  void _removeSubtask(int index) {
    final removed = _subtasks.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final moduleId = _moduleId;
    if (moduleId == null) return;
    final now = DateTime.now();
    final existing = widget.assignment;
    final assignment = Assignment(
      id: existing?.id ?? newOrganizerId('assignment'),
      moduleId: moduleId,
      title: _title.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      dueAt: _dueAt,
      priority: _priority,
      estimatedMinutes: int.tryParse(_effort.text.trim()) ?? 0,
      status: _status,
      subtasks: [
        for (var index = 0; index < _subtasks.length; index++)
          if (_subtasks[index].title.text.trim().isNotEmpty)
            _subtasks[index].toModel(index),
      ],
      manualProgress: _status == WorkStatus.completed ? 1 : _progress,
      reminderAt: _status == WorkStatus.completed ? null : _reminderAt,
      attachments: existing?.attachments ?? const [],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final saved = await ref
        .read(academicOrganizerControllerProvider.notifier)
        .saveAssignment(assignment);
    if (saved && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => OrganizerFormSheet(
    title: widget.assignment == null ? 'Add assignment' : 'Edit assignment',
    formKey: _key,
    isSaving: ref.watch(academicOrganizerControllerProvider).isLoading,
    onSave: _save,
    children: [
      TextFormField(
        key: const Key('assignment-title-field'),
        controller: _title,
        decoration: const InputDecoration(labelText: 'Title'),
        validator: (value) => requiredOrganizerText(value, label: 'Title'),
      ),
      const SizedBox(height: 12),
      OrganizerModuleDropdown(
        modules: widget.modules,
        value: _moduleId,
        onChanged: (value) => setState(() => _moduleId = value),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _description,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'Description (optional)'),
      ),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Due'),
        subtitle: Text(organizerDateTimeLabel(_dueAt)),
        trailing: const Icon(Icons.edit_calendar_outlined),
        onTap: _pickDue,
      ),
      OrganizerResponsivePair(
        first: DropdownButtonFormField<PriorityLevel>(
          value: _priority,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Priority'),
          items: [
            for (final value in PriorityLevel.values)
              DropdownMenuItem(
                value: value,
                child: organizerDropdownLabel(_titleCase(value.name)),
              ),
          ],
          onChanged: (value) => setState(() => _priority = value ?? _priority),
        ),
        second: TextFormField(
          controller: _effort,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Effort (minutes)'),
          validator: (value) {
            final number = int.tryParse(value ?? '');
            return number == null || number < 1 ? 'Enter minutes.' : null;
          },
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<WorkStatus>(
        value: _status,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Status'),
        items: [
          for (final value in WorkStatus.values)
            DropdownMenuItem(
              value: value,
              child: organizerDropdownLabel(_titleCase(value.name)),
            ),
        ],
        onChanged: (value) => setState(() => _status = value ?? _status),
      ),
      const SizedBox(height: 16),
      Text('Progress ${(_progress * 100).round()}%'),
      Slider(
        value: _progress,
        divisions: 20,
        label: '${(_progress * 100).round()}%',
        onChanged:
            _status == WorkStatus.completed
                ? null
                : (value) => setState(() => _progress = value),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Deadline reminder'),
        subtitle: Text(
          _reminderAt == null ? 'Off' : organizerDateTimeLabel(_reminderAt!),
        ),
        value: _reminderAt != null,
        onChanged: (value) {
          if (!value) {
            setState(() => _reminderAt = null);
          } else {
            _pickReminder();
          }
        },
      ),
      const Divider(height: 32),
      Row(
        children: [
          Expanded(
            child: Text(
              'Subtasks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          TextButton.icon(
            onPressed: _addSubtask,
            icon: const Icon(Icons.add),
            label: const Text('Add subtask'),
          ),
        ],
      ),
      for (var index = 0; index < _subtasks.length; index++) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _subtasks[index].completed,
              onChanged:
                  (value) => setState(
                    () => _subtasks[index].completed = value ?? false,
                  ),
            ),
            Expanded(
              child: TextFormField(
                controller: _subtasks[index].title,
                decoration: InputDecoration(labelText: 'Subtask ${index + 1}'),
              ),
            ),
            IconButton(
              tooltip: 'Remove subtask ${index + 1}',
              onPressed: () => _removeSubtask(index),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    ],
  );
}

final class _SubtaskDraft {
  _SubtaskDraft({
    required this.id,
    required this.title,
    required this.completed,
    required this.estimatedMinutes,
    this.completedAt,
  });

  factory _SubtaskDraft.empty() => _SubtaskDraft(
    id: newOrganizerId('subtask'),
    title: TextEditingController(),
    completed: false,
    estimatedMinutes: 0,
  );

  factory _SubtaskDraft.fromModel(Subtask model) => _SubtaskDraft(
    id: model.id,
    title: TextEditingController(text: model.title),
    completed: model.isCompleted,
    estimatedMinutes: model.estimatedMinutes,
    completedAt: model.completedAt,
  );

  final String id;
  final TextEditingController title;
  bool completed;
  final int estimatedMinutes;
  final DateTime? completedAt;

  Subtask toModel(int order) => Subtask(
    id: id,
    title: title.text.trim(),
    isCompleted: completed,
    estimatedMinutes: estimatedMinutes,
    completedAt: completed ? (completedAt ?? DateTime.now()) : null,
    order: order,
  );

  void dispose() => title.dispose();
}

String _titleCase(String value) => value
    .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
    .trim()
    .replaceFirstMapped(RegExp('^.'), (match) => match.group(0)!.toUpperCase());
