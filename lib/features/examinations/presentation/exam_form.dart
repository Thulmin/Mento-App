// Collects and validates examination dates, importance, venue, and topics.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../academic_organizer/application/academic_organizer_controller.dart';
import '../../academic_organizer/application/academic_organizer_providers.dart';
import '../../academic_organizer/presentation/organizer_form_support.dart';

Future<void> showExamForm(
  BuildContext context, {
  required List<Module> modules,
  required List<Topic> topics,
  Exam? exam,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => ExamForm(modules: modules, topics: topics, exam: exam),
);

class ExamForm extends ConsumerStatefulWidget {
  const ExamForm({
    required this.modules,
    required this.topics,
    this.exam,
    super.key,
  });

  final List<Module> modules;
  final List<Topic> topics;
  final Exam? exam;

  @override
  ConsumerState<ExamForm> createState() => _ExamFormState();
}

class _ExamFormState extends ConsumerState<ExamForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _venue;
  late final TextEditingController _notes;
  late final TextEditingController _duration;
  late String? _moduleId;
  late DateTime _startAt;
  late PriorityLevel _importance;
  late double _progress;
  late DateTime? _reminderAt;
  late Set<String> _topicIds;

  @override
  void initState() {
    super.initState();
    final exam = widget.exam;
    _title = TextEditingController(text: exam?.title);
    _venue = TextEditingController(text: exam?.venue);
    _notes = TextEditingController(text: exam?.notes);
    _duration = TextEditingController(
      text: (exam?.endAt.difference(exam.startAt).inMinutes ?? 120).toString(),
    );
    _moduleId =
        exam?.moduleId ??
        (widget.modules.isEmpty ? null : widget.modules.first.id);
    _startAt = exam?.startAt ?? DateTime.now().add(const Duration(days: 14));
    _importance = exam?.importance ?? PriorityLevel.high;
    _progress = exam?.preparationProgress ?? 0;
    _reminderAt = exam?.reminderAt;
    _topicIds = {...?exam?.syllabusTopicIds};
  }

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _notes.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final value = await pickOrganizerDateTime(context, _startAt);
    if (value != null) setState(() => _startAt = value);
  }

  Future<void> _pickReminder() async {
    final initial = _reminderAt ?? _startAt.subtract(const Duration(days: 2));
    final value = await pickOrganizerDateTime(context, initial);
    if (value != null) setState(() => _reminderAt = value);
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    final moduleId = _moduleId;
    if (moduleId == null) return;
    final duration = int.tryParse(_duration.text.trim()) ?? 0;
    final exam = Exam(
      id: widget.exam?.id ?? newOrganizerId('exam'),
      moduleId: moduleId,
      title: _title.text.trim(),
      startAt: _startAt,
      endAt: _startAt.add(Duration(minutes: duration)),
      venue: _venue.text.trim().isEmpty ? null : _venue.text.trim(),
      syllabusTopicIds: _topicIds.toList(),
      importance: _importance,
      preparationProgress: _progress,
      reminderAt: _reminderAt,
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    final saved = await ref
        .read(academicOrganizerControllerProvider.notifier)
        .saveExam(exam);
    if (saved && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final availableTopics =
        widget.topics.where((topic) => topic.moduleId == _moduleId).toList();
    return OrganizerFormSheet(
      title: widget.exam == null ? 'Add examination' : 'Edit examination',
      formKey: _key,
      isSaving: ref.watch(academicOrganizerControllerProvider).isLoading,
      onSave: _save,
      children: [
        TextFormField(
          key: const Key('exam-title-field'),
          controller: _title,
          decoration: const InputDecoration(labelText: 'Examination title'),
          validator: (value) => requiredOrganizerText(value, label: 'Title'),
        ),
        const SizedBox(height: 12),
        OrganizerModuleDropdown(
          modules: widget.modules,
          value: _moduleId,
          onChanged:
              (value) => setState(() {
                _moduleId = value;
                _topicIds.removeWhere(
                  (id) =>
                      !widget.topics.any(
                        (topic) => topic.id == id && topic.moduleId == value,
                      ),
                );
              }),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Starts'),
          subtitle: Text(organizerDateTimeLabel(_startAt)),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: _pickStart,
        ),
        OrganizerResponsivePair(
          first: TextFormField(
            controller: _duration,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Duration (minutes)'),
            validator: (value) {
              final minutes = int.tryParse(value ?? '');
              return minutes == null || minutes < 15
                  ? 'Enter at least 15 minutes.'
                  : null;
            },
          ),
          second: DropdownButtonFormField<PriorityLevel>(
            value: _importance,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Importance'),
            items: [
              for (final value in PriorityLevel.values)
                DropdownMenuItem(
                  value: value,
                  child: organizerDropdownLabel(_titleCase(value.name)),
                ),
            ],
            onChanged:
                (value) => setState(() => _importance = value ?? _importance),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _venue,
          decoration: const InputDecoration(labelText: 'Venue (optional)'),
        ),
        const SizedBox(height: 16),
        Text('Preparation ${(_progress * 100).round()}%'),
        Slider(
          value: _progress,
          divisions: 20,
          label: '${(_progress * 100).round()}%',
          onChanged: (value) => setState(() => _progress = value),
        ),
        if (availableTopics.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Syllabus topics',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final topic in availableTopics)
                FilterChip(
                  label: Text(topic.name),
                  selected: _topicIds.contains(topic.id),
                  onSelected:
                      (selected) => setState(() {
                        selected
                            ? _topicIds.add(topic.id)
                            : _topicIds.remove(topic.id);
                      }),
                ),
            ],
          ),
        ],
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Preparation reminder'),
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
