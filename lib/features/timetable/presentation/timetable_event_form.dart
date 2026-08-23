// Collects and validates one-off or repeating timetable event details.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/models.dart';
import '../../academic_organizer/application/academic_organizer_controller.dart';
import '../../academic_organizer/application/academic_organizer_providers.dart';
import '../../academic_organizer/presentation/organizer_form_support.dart';

Future<void> showTimetableEventForm(
  BuildContext context, {
  required List<Module> modules,
  TimetableEvent? event,
  DateTime? initialStart,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder:
      (_) => TimetableEventForm(
        modules: modules,
        event: event,
        initialStart: initialStart,
      ),
);

class TimetableEventForm extends ConsumerStatefulWidget {
  const TimetableEventForm({
    required this.modules,
    this.event,
    this.initialStart,
    super.key,
  });

  final List<Module> modules;
  final TimetableEvent? event;
  final DateTime? initialStart;

  @override
  ConsumerState<TimetableEventForm> createState() => _TimetableEventFormState();
}

class _TimetableEventFormState extends ConsumerState<TimetableEventForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _location;
  late final TextEditingController _notes;
  late DateTime _start;
  late DateTime _end;
  late EventType _type;
  late RecurrenceFrequency _recurrence;
  late String? _moduleId;
  late int? _reminder;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    final fallback =
        widget.initialStart ?? DateTime.now().add(const Duration(hours: 1));
    _title = TextEditingController(text: event?.title);
    _location = TextEditingController(text: event?.location);
    _notes = TextEditingController(text: event?.notes);
    _start = event?.startAt ?? fallback;
    _end = event?.endAt ?? fallback.add(const Duration(hours: 1));
    _type = event?.type ?? EventType.lecture;
    _recurrence = event?.recurrence ?? RecurrenceFrequency.none;
    _moduleId = event?.moduleId;
    _reminder = event?.reminderMinutesBefore;
  }

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final value = await pickOrganizerDateTime(context, _start);
    if (value == null) return;
    final duration = _end.difference(_start);
    setState(() {
      _start = value;
      _end = value.add(
        duration.isNegative || duration == Duration.zero
            ? const Duration(hours: 1)
            : duration,
      );
    });
  }

  Future<void> _pickEnd() async {
    final value = await pickOrganizerDateTime(context, _end, firstDate: _start);
    if (value != null) setState(() => _end = value);
  }

  TimetableEvent _buildEvent() => TimetableEvent(
    id: widget.event?.id ?? newOrganizerId('event'),
    title: _title.text.trim(),
    moduleId: _moduleId,
    type: _type,
    startAt: _start,
    endAt: _end,
    location: _location.text.trim().isEmpty ? null : _location.text.trim(),
    savedLocationId: widget.event?.savedLocationId,
    latitude: widget.event?.latitude,
    longitude: widget.event?.longitude,
    reminderMinutesBefore: _reminder,
    recurrence: _recurrence,
    recurrenceUntil:
        _recurrence == RecurrenceFrequency.none
            ? null
            : _start.add(const Duration(days: 180)),
    recurringWeekdays:
        _recurrence == RecurrenceFrequency.none ? const {} : {_start.weekday},
    notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
  );

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    if (!_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    final event = _buildEvent();
    final existing = ref.read(academicTimetableProvider).value ?? const [];
    final conflicts = ref
        .read(academicOrganizerControllerProvider.notifier)
        .findEventConflicts(event, existing);
    if (conflicts.isNotEmpty) {
      final override = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('Schedule conflict'),
              content: Text(
                'This overlaps ${conflicts.map((item) => item.title).join(', ')}. '
                'You can keep both events if this is intentional.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Go back'),
                ),
                FilledButton(
                  key: const Key('confirm-conflict-override'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save anyway'),
                ),
              ],
            ),
      );
      if (override != true || !mounted) return;
    }
    final saved = await ref
        .read(academicOrganizerControllerProvider.notifier)
        .saveEvent(event);
    if (saved && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => OrganizerFormSheet(
    title:
        widget.event == null ? 'Add timetable event' : 'Edit timetable event',
    formKey: _key,
    isSaving: ref.watch(academicOrganizerControllerProvider).isLoading,
    onSave: _save,
    children: [
      TextFormField(
        key: const Key('event-title-field'),
        controller: _title,
        decoration: const InputDecoration(labelText: 'Title'),
        validator: (value) => requiredOrganizerText(value, label: 'Title'),
      ),
      const SizedBox(height: 12),
      OrganizerModuleDropdown(
        modules: widget.modules,
        value: _moduleId,
        optional: true,
        onChanged: (value) => setState(() => _moduleId = value),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<EventType>(
        value: _type,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Event type'),
        items: [
          for (final value in EventType.values)
            DropdownMenuItem(
              value: value,
              child: organizerDropdownLabel(_label(value.name)),
            ),
        ],
        onChanged: (value) => setState(() => _type = value ?? _type),
      ),
      const SizedBox(height: 12),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Starts'),
        subtitle: Text(organizerDateTimeLabel(_start)),
        trailing: const Icon(Icons.edit_calendar_outlined),
        onTap: _pickStart,
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ends'),
        subtitle: Text(organizerDateTimeLabel(_end)),
        trailing: const Icon(Icons.schedule_outlined),
        onTap: _pickEnd,
      ),
      DropdownButtonFormField<RecurrenceFrequency>(
        value: _recurrence,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Repeats'),
        items: [
          for (final value in RecurrenceFrequency.values)
            DropdownMenuItem(
              value: value,
              child: organizerDropdownLabel(_label(value.name)),
            ),
        ],
        onChanged:
            (value) => setState(() => _recurrence = value ?? _recurrence),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<int?>(
        value: _reminder,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Reminder'),
        items: const [
          DropdownMenuItem<int?>(
            value: null,
            child: Text(
              'No reminder',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownMenuItem<int?>(
            value: 10,
            child: Text(
              '10 minutes before',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownMenuItem<int?>(
            value: 20,
            child: Text(
              '20 minutes before',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownMenuItem<int?>(
            value: 60,
            child: Text(
              '1 hour before',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownMenuItem<int?>(
            value: 1440,
            child: Text(
              '1 day before',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        onChanged: (value) => setState(() => _reminder = value),
      ),
      const SizedBox(height: 12),
      TextFormField(
        controller: _location,
        decoration: const InputDecoration(labelText: 'Location (optional)'),
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

String _label(String value) => value
    .replaceAllMapped(RegExp(r'([A-Z])'), (match) => ' ${match.group(1)}')
    .trim()
    .replaceFirstMapped(RegExp('^.'), (match) => match.group(0)!.toUpperCase());
