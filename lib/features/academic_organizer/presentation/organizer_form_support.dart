// Shares date, time, validation, and selection helpers between organiser forms.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/models.dart';

Future<DateTime?> pickOrganizerDateTime(
  BuildContext context,
  DateTime initial, {
  DateTime? firstDate,
  DateTime? lastDate,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: firstDate ?? DateTime(initial.year - 3),
    lastDate: lastDate ?? DateTime(initial.year + 8),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

String organizerDateTimeLabel(DateTime value) =>
    DateFormat('EEE, d MMM · HH:mm').format(value);

String? requiredOrganizerText(String? value, {String label = 'Value'}) {
  if (value == null || value.trim().isEmpty) return '$label is required.';
  return null;
}

class OrganizerFormSheet extends StatelessWidget {
  const OrganizerFormSheet({
    required this.title,
    required this.formKey,
    required this.children,
    required this.onSave,
    this.isSaving = false,
    super.key,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> children;
  final VoidCallback onSave;
  final bool isSaving;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      16,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Form(
      key: formKey,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: isSaving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('organizer-form-save'),
                onPressed: isSaving ? null : onSave,
                icon:
                    isSaving
                        ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.check),
                label: Text(isSaving ? 'Saving…' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class OrganizerModuleDropdown extends StatelessWidget {
  const OrganizerModuleDropdown({
    required this.modules,
    required this.value,
    required this.onChanged,
    this.optional = false,
    super.key,
  });

  final List<Module> modules;
  final String? value;
  final ValueChanged<String?> onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final entries = <({String value, String label})>[
      if (optional) (value: '', label: 'No module'),
      for (final module in modules)
        (value: module.id, label: '${module.code} · ${module.name}'),
    ];
    return DropdownButtonFormField<String>(
      value: modules.any((module) => module.id == value) ? value : null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: optional ? 'Module (optional)' : 'Module',
      ),
      items: [
        for (final entry in entries)
          DropdownMenuItem(
            value: entry.value,
            child: organizerDropdownLabel(entry.label),
          ),
      ],
      selectedItemBuilder:
          (context) => [
            for (final entry in entries) organizerDropdownLabel(entry.label),
          ],
      validator:
          optional
              ? null
              : (selected) =>
                  selected == null || selected.isEmpty
                      ? 'Choose a module.'
                      : null,
      onChanged:
          (selected) => onChanged(selected?.isEmpty == true ? null : selected),
    );
  }
}

Widget organizerDropdownLabel(String label) =>
    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);

class OrganizerResponsivePair extends StatelessWidget {
  const OrganizerResponsivePair({
    required this.first,
    required this.second,
    this.breakpoint = 480,
    super.key,
  });

  final Widget first;
  final Widget second;
  final double breakpoint;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [first, const SizedBox(height: 12), second],
        );
      }
      return Row(
        children: [
          Expanded(child: first),
          const SizedBox(width: 12),
          Expanded(child: second),
        ],
      );
    },
  );
}
