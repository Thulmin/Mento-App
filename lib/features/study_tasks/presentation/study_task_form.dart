// Collects and validates study-task scheduling and priority details.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../academic_organizer/application/academic_organizer_controller.dart';
import '../../academic_organizer/application/academic_organizer_providers.dart';
import '../../academic_organizer/presentation/organizer_form_support.dart';

Future<void> showStudyTaskForm(
  BuildContext context, {
  required List<Module> modules,
  required List<Topic> topics,
  StudyTask? task,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => StudyTaskForm(modules: modules, topics: topics, task: task),
);

class StudyTaskForm extends ConsumerStatefulWidget {
  const StudyTaskForm({
    required this.modules,
    required this.topics,
    this.task,
    super.key,
  });

  final List<Module> modules;
  final List<Topic> topics;
  final StudyTask? task;

  @override
  ConsumerState<StudyTaskForm> createState() => _StudyTaskFormState();
}

class _StudyTaskFormState extends ConsumerState<StudyTaskForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _duration;
  late final TextEditingController _notes;
  late String? _moduleId;
  late String? _topicId;
  late DateTime _dueAt;
  late DateTime? _plannedStart;
  late PriorityLevel _priority;
  late WorkStatus _status;
  late bool _needsRescheduling;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _title = TextEditingController(text: task?.title);
    _duration = TextEditingController(
      text: (task?.estimatedMinutes ?? 50).toString(),
    );
    _notes = TextEditingController(text: task?.notes);
    _moduleId = task?.moduleId;
    _topicId = task?.topicId;
    _dueAt = task?.dueAt ?? DateTime.now().add(const Duration(days: 3));
    _plannedStart = task?.plannedStartAt;
    _priority = task?.priority ?? PriorityLevel.medium;
    _status = task?.status ?? WorkStatus.notStarted;
    _needsRescheduling = task?.needsRescheduling ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final value = await pickOrganizerDateTime(context, _dueAt);
    if (value != null) setState(() => _dueAt = value);
  }

  Future<void> _pickPlanned() async {
    final initial = _plannedStart ?? _dueAt.subtract(const Duration(days: 1));
    final value = await pickOrganizerDateTime(context, initial);
    if (value != null) setState(() => _plannedStart = value);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final existing = widget.task;
    final status = _status;
    final task = StudyTask(
      id: existing?.id ?? newOrganizerId('task'),
      title: _title.text.trim(),
      moduleId: _moduleId,
      topicId: _topicId,
      dueAt: _dueAt,
      estimatedMinutes: int.tryParse(_duration.text.trim()) ?? 0,
      priority: _priority,
      status: status,
      plannedStartAt: _plannedStart,
      isAiGenerated: existing?.isAiGenerated ?? false,
      needsRescheduling: _needsRescheduling,
      completedAt:
          status == WorkStatus.completed
              ? (existing?.completedAt ?? DateTime.now())
              : null,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    final saved = await ref
        .read(academicOrganizerControllerProvider.notifier)
        .saveTask(task);
    if (saved && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final availableTopics =
        widget.topics.where((topic) => topic.moduleId == _moduleId).toList();
    return OrganizerFormSheet(
      title: widget.task == null ? 'Add study task' : 'Edit study task',
      formKey: _key,
      isSaving: ref.watch(academicOrganizerControllerProvider).isLoading,
      onSave: _save,
      children: [
        if (widget.task?.isAiGenerated == true)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Chip(
              avatar: Icon(Icons.auto_awesome, size: 18),
              label: Text('AI-generated suggestion'),
            ),
          ),
        TextFormField(
          key: const Key('task-title-field'),
          controller: _title,
          decoration: const InputDecoration(labelText: 'Task title'),
          validator: (value) => requiredOrganizerText(value, label: 'Title'),
        ),
        const SizedBox(height: 12),
        OrganizerModuleDropdown(
          modules: widget.modules,
          value: _moduleId,
          optional: true,
          onChanged:
              (value) => setState(() {
                _moduleId = value;
                if (!widget.topics.any(
                  (topic) => topic.id == _topicId && topic.moduleId == value,
                )) {
                  _topicId = null;
                }
              }),
        ),
        if (availableTopics.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            isExpanded: true,
            value:
                availableTopics.any((topic) => topic.id == _topicId)
                    ? _topicId
                    : null,
            decoration: const InputDecoration(labelText: 'Topic (optional)'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text(
                  'No topic',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final topic in availableTopics)
                DropdownMenuItem<String?>(
                  value: topic.id,
                  child: organizerDropdownLabel(topic.name),
                ),
            ],
            onChanged: (value) => setState(() => _topicId = value),
          ),
        ],
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Due'),
          subtitle: Text(organizerDateTimeLabel(_dueAt)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: _pickDue,
        ),
        OrganizerResponsivePair(
          first: TextFormField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minutes'),
            validator: (value) {
              final number = int.tryParse(value ?? '');
              return number == null || number < 1 ? 'Enter minutes.' : null;
            },
          ),
          second: DropdownButtonFormField<PriorityLevel>(
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
            onChanged:
                (value) => setState(() => _priority = value ?? _priority),
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
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Planned study session'),
          subtitle: Text(
            _plannedStart == null
                ? 'Not scheduled'
                : organizerDateTimeLabel(_plannedStart!),
          ),
          value: _plannedStart != null,
          onChanged: (value) {
            if (!value) {
              setState(() => _plannedStart = null);
            } else {
              _pickPlanned();
            }
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Needs rescheduling'),
          value: _needsRescheduling,
          onChanged: (value) => setState(() => _needsRescheduling = value),
        ),
        TextFormField(
          controller: _notes,
          minLines: 2,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
        ),
      ],
    );
  }
}

String _titleCase(String value) => value
    .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
    .trim()
    .replaceFirstMapped(RegExp('^.'), (match) => match.group(0)!.toUpperCase());
