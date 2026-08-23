// Collects and validates module details in a create-or-edit bottom sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../academic_organizer/application/academic_organizer_controller.dart';
import '../../academic_organizer/application/academic_organizer_providers.dart';
import '../../academic_organizer/presentation/organizer_form_support.dart';

Future<void> showModuleForm(BuildContext context, {Module? module}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ModuleForm(module: module),
    );

class ModuleForm extends ConsumerStatefulWidget {
  const ModuleForm({this.module, super.key});

  final Module? module;

  @override
  ConsumerState<ModuleForm> createState() => _ModuleFormState();
}

class _ModuleFormState extends ConsumerState<ModuleForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _code;
  late final TextEditingController _lecturer;
  late final TextEditingController _semester;
  late final TextEditingController _notes;
  late final TextEditingController _color;

  @override
  void initState() {
    super.initState();
    final module = widget.module;
    _name = TextEditingController(text: module?.name);
    _code = TextEditingController(text: module?.code);
    _lecturer = TextEditingController(text: module?.lecturer);
    _semester = TextEditingController(text: module?.semester ?? 'Semester 1');
    _notes = TextEditingController(text: module?.notes);
    _color = TextEditingController(text: module?.colorHex ?? '#247CF8');
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _code,
      _lecturer,
      _semester,
      _notes,
      _color,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final now = DateTime.now();
    final existing = widget.module;
    final module = Module(
      id: existing?.id ?? newOrganizerId('module'),
      name: _name.text.trim(),
      code: _code.text.trim().toUpperCase(),
      lecturer: _lecturer.text.trim().isEmpty ? null : _lecturer.text.trim(),
      colorHex: _color.text.trim().toUpperCase(),
      semester: _semester.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      priorityWeight: existing?.priorityWeight ?? 1,
      topics: existing?.topics ?? const [],
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final saved = await ref
        .read(academicOrganizerControllerProvider.notifier)
        .saveModule(module);
    if (saved && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(academicOrganizerControllerProvider).isLoading;
    return OrganizerFormSheet(
      title: widget.module == null ? 'Add module' : 'Edit module',
      formKey: _key,
      isSaving: saving,
      onSave: _save,
      children: [
        TextFormField(
          key: const Key('module-name-field'),
          controller: _name,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'Module name'),
          validator:
              (value) => requiredOrganizerText(value, label: 'Module name'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          key: const Key('module-code-field'),
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Module code'),
          validator:
              (value) => requiredOrganizerText(value, label: 'Module code'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _lecturer,
          decoration: const InputDecoration(labelText: 'Lecturer (optional)'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _semester,
          decoration: const InputDecoration(labelText: 'Semester'),
          validator: (value) => requiredOrganizerText(value, label: 'Semester'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _color,
          decoration: const InputDecoration(
            labelText: 'Colour',
            hintText: '#247CF8',
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(text)
                ? null
                : 'Use a six-digit colour such as #247CF8.';
          },
        ),
        const SizedBox(height: 12),
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

Future<void> showTopicForm(
  BuildContext context, {
  required Module module,
  Topic? topic,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => TopicForm(module: module, topic: topic),
);

class TopicForm extends ConsumerStatefulWidget {
  const TopicForm({required this.module, this.topic, super.key});

  final Module module;
  final Topic? topic;

  @override
  ConsumerState<TopicForm> createState() => _TopicFormState();
}

class _TopicFormState extends ConsumerState<TopicForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.topic?.name,
  );
  late final TextEditingController _description = TextEditingController(
    text: widget.topic?.description,
  );
  late double _mastery = widget.topic?.mastery ?? 0;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final topic = Topic(
      id: widget.topic?.id ?? newOrganizerId('topic'),
      moduleId: widget.module.id,
      name: _name.text.trim(),
      description:
          _description.text.trim().isEmpty ? null : _description.text.trim(),
      mastery: _mastery,
      completedStudyMinutes: widget.topic?.completedStudyMinutes ?? 0,
      updatedAt: DateTime.now(),
    );
    final saved = await ref
        .read(academicOrganizerControllerProvider.notifier)
        .saveTopic(topic);
    if (saved && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => OrganizerFormSheet(
    title:
        widget.topic == null
            ? 'Add topic to ${widget.module.code}'
            : 'Edit topic',
    formKey: _key,
    isSaving: ref.watch(academicOrganizerControllerProvider).isLoading,
    onSave: _save,
    children: [
      TextFormField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Topic name'),
        validator: (value) => requiredOrganizerText(value, label: 'Topic name'),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _description,
        minLines: 2,
        maxLines: 4,
        decoration: const InputDecoration(labelText: 'Description (optional)'),
      ),
      const SizedBox(height: 16),
      Text('Mastery ${(100 * _mastery).round()}%'),
      Slider(
        value: _mastery,
        divisions: 20,
        label: '${(_mastery * 100).round()}%',
        onChanged: (value) => setState(() => _mastery = value),
      ),
    ],
  );
}
