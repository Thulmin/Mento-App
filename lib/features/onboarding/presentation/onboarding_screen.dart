// Guides first-time users through a resumable five-step Mento setup.

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_controls.dart';
import '../../authentication/application/auth_providers.dart';
import '../../authentication/domain/session_state.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _draftKey = 'mento.onboarding_draft';
  final _pageController = PageController();
  final _name = TextEditingController();
  final _institution = TextEditingController();
  final _course = TextEditingController();
  final _year = TextEditingController(text: '1');
  final _semester = TextEditingController(text: '1');
  final _modules = TextEditingController();
  final _goal = TextEditingController();
  int _page = 0;
  double _studyHours = 3;
  double _sessionMinutes = 45;
  double _breakMinutes = 10;
  bool _notifications = true;
  bool _wellness = true;
  bool _location = false;
  bool _acceptedTerms = false;
  bool _saving = false;
  ThemeMode _theme = ThemeMode.system;
  final Set<String> _preferences = {'Structured plans', 'Gentle reminders'};

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in [
      _name,
      _institution,
      _course,
      _year,
      _semester,
      _modules,
      _goal,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_draftKey);
    final session = ref.read(sessionProvider);
    _name.text = session.displayName == 'Student' ? '' : session.displayName;
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _name.text = map['name'] as String? ?? _name.text;
        _institution.text = map['institution'] as String? ?? '';
        _course.text = map['course'] as String? ?? '';
        _year.text = map['year'] as String? ?? '1';
        _semester.text = map['semester'] as String? ?? '1';
        _modules.text = map['modules'] as String? ?? '';
        _goal.text = map['goal'] as String? ?? '';
        _studyHours = (map['studyHours'] as num?)?.toDouble() ?? 3;
        _sessionMinutes = (map['sessionMinutes'] as num?)?.toDouble() ?? 45;
        _breakMinutes = (map['breakMinutes'] as num?)?.toDouble() ?? 10;
        _notifications = map['notifications'] as bool? ?? true;
        _wellness = map['wellness'] as bool? ?? true;
        _location = map['location'] as bool? ?? false;
        _theme = ThemeMode.values.firstWhere(
          (mode) => mode.name == map['theme'],
          orElse: () => ThemeMode.system,
        );
        _preferences
          ..clear()
          ..addAll(
            (map['preferences'] as List<dynamic>? ?? const []).cast<String>(),
          );
      });
    } catch (_) {
      await prefs.remove(_draftKey);
    }
  }

  Map<String, dynamic> get _draft => {
    'name': _name.text.trim(),
    'institution': _institution.text.trim(),
    'course': _course.text.trim(),
    'year': _year.text.trim(),
    'semester': _semester.text.trim(),
    'modules': _modules.text.trim(),
    'goal': _goal.text.trim(),
    'studyHours': _studyHours,
    'sessionMinutes': _sessionMinutes,
    'breakMinutes': _breakMinutes,
    'notifications': _notifications,
    'wellness': _wellness,
    'location': _location,
    'theme': _theme.name,
    'preferences': _preferences.toList()..sort(),
  };

  Future<void> _saveDraft() => ref
      .read(sharedPreferencesProvider)
      .setString(_draftKey, jsonEncode(_draft));

  @override
  Widget build(BuildContext context) {
    final pages = [
      _IdentityStep(
        name: _name,
        institution: _institution,
        course: _course,
        year: _year,
        semester: _semester,
      ),
      _ModulesStep(modules: _modules),
      _RhythmStep(
        studyHours: _studyHours,
        sessionMinutes: _sessionMinutes,
        breakMinutes: _breakMinutes,
        onStudyHours: (value) => setState(() => _studyHours = value),
        onSessionMinutes: (value) => setState(() => _sessionMinutes = value),
        onBreakMinutes: (value) => setState(() => _breakMinutes = value),
      ),
      _GoalsStep(
        goal: _goal,
        preferences: _preferences,
        onToggle:
            (value) => setState(() {
              _preferences.contains(value)
                  ? _preferences.remove(value)
                  : _preferences.add(value);
            }),
      ),
      _PreferencesStep(
        notifications: _notifications,
        wellness: _wellness,
        location: _location,
        acceptedTerms: _acceptedTerms,
        theme: _theme,
        onNotifications: (value) => setState(() => _notifications = value),
        onWellness: (value) => setState(() => _wellness = value),
        onLocation: (value) => setState(() => _location = value),
        onAcceptedTerms: (value) => setState(() => _acceptedTerms = value),
        onTheme: (value) => setState(() => _theme = value),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set up Mento'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveDraft,
            child: const Text('Save progress'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Semantics(
              label: 'Onboarding step ${_page + 1} of ${pages.length}',
              child: LinearProgressIndicator(value: (_page + 1) / pages.length),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final page in pages)
                    MentoPage(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 700),
                          child: page,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 700),
                    child: Row(
                      children: [
                        if (_page > 0)
                          Expanded(
                            child: MentoButton(
                              label: 'Back',
                              variant: MentoButtonVariant.outlined,
                              onPressed: _saving ? null : _back,
                            ),
                          ),
                        if (_page > 0) const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: MentoButton(
                            label:
                                _page == pages.length - 1
                                    ? 'Finish setup'
                                    : 'Continue',
                            loading: _saving,
                            variant: MentoButtonVariant.gradient,
                            onPressed: _saving ? null : _next,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _back() async {
    final duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240);
    await _saveDraft();
    if (!mounted) return;
    setState(() => _page--);
    await _pageController.animateToPage(
      _page,
      duration: duration,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _next() async {
    if (_page == 0 &&
        (_name.text.trim().length < 2 || _course.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add your preferred name and course to continue.'),
        ),
      );
      return;
    }
    final consentError = validateOnboardingConsent(
      acceptedTerms: _acceptedTerms,
    );
    if (_page == 4 && consentError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(consentError)));
      return;
    }
    final duration =
        MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 240);
    await _saveDraft();
    if (!mounted) return;
    if (_page < 4) {
      setState(() => _page++);
      await _pageController.animateToPage(
        _page,
        duration: duration,
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await _complete();
  }

  Future<void> _complete() async {
    setState(() => _saving = true);
    try {
      if (_location) {
        final enabled = await Geolocator.isLocationServiceEnabled();
        if (enabled) await Geolocator.requestPermission();
      }
      await ref.read(themeModeProvider.notifier).setMode(_theme);
      final session = ref.read(sessionProvider);
      if (session.status != SessionStatus.demo && session.user != null) {
        final uid = session.user!.uid;
        final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
        final batch = FirebaseFirestore.instance.batch();
        final existingDoc = await userRef.get();
        final isUpdate = existingDoc.exists;
        final userData = <String, dynamic>{
          'uid': uid,
          'profile': {
            'preferredName': _name.text.trim(),
            'institution': _institution.text.trim(),
            'course': _course.text.trim(),
            'academicYear': int.tryParse(_year.text) ?? 1,
            'semester': int.tryParse(_semester.text) ?? 1,
          },
          'preferences': {
            'availableStudyHours': _studyHours,
            'studySessionMinutes': _sessionMinutes.round(),
            'breakMinutes': _breakMinutes.round(),
            'productivity': _preferences.toList(),
            'goal': _goal.text.trim(),
            'notificationsEnabled': _notifications,
            'wellnessEnabled': _wellness,
            'locationEnabled': _location,
            'themeMode': _theme.name,
            'publicAchievements': false,
          },
          'onboardingComplete': true,
          'termsAccepted': _acceptedTerms,
          'role':
              isUpdate
                  ? (existingDoc.data()?['role'] as String? ?? 'student')
                  : 'student',
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (isUpdate) {
          // Preserve the original createdAt on update.
          userData['createdAt'] =
              existingDoc.data()?['createdAt'] ?? FieldValue.serverTimestamp();
          batch.set(userRef, userData);
        } else {
          userData['createdAt'] = FieldValue.serverTimestamp();
          batch.set(userRef, userData);
        }
        final moduleNames =
            _modules.text
                .split(RegExp('[,\n]'))
                .map((name) => name.trim())
                .where((name) => name.isNotEmpty)
                .toSet();
        var index = 0;
        for (final name in moduleNames) {
          final moduleRef = userRef.collection('modules').doc();
          batch.set(moduleRef, {
            'id': moduleRef.id,
            'ownerId': uid,
            'name': name,
            'code': 'M${index + 1}',
            'semester': 'Semester ${int.tryParse(_semester.text) ?? 1}',
            'colorHex': ['#247CF8', '#7651F8', '#28B8FC', '#A966FB'][index % 4],
            'priorityWeight': 1.0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          index++;
        }
        await batch.commit();
      }
      await ref.read(sharedPreferencesProvider).remove(_draftKey);
      await ref.read(sessionProvider.notifier).onboardingCompleted();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Setup could not be saved. Your draft is safe; please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String? validateOnboardingConsent({required bool acceptedTerms}) =>
    acceptedTerms
        ? null
        : 'Accept the Terms and Privacy Notice to finish setup.';

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => MentoCard(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 40, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        Text(subtitle),
        const SizedBox(height: 24),
        ...children,
      ],
    ),
  );
}

class _IdentityStep extends StatelessWidget {
  const _IdentityStep({
    required this.name,
    required this.institution,
    required this.course,
    required this.year,
    required this.semester,
  });
  final TextEditingController name;
  final TextEditingController institution;
  final TextEditingController course;
  final TextEditingController year;
  final TextEditingController semester;

  @override
  Widget build(BuildContext context) => _StepCard(
    icon: Icons.school_outlined,
    title: 'Make Mento yours',
    subtitle:
        'We use this only to personalise your plan. Institution is optional.',
    children: [
      MentoTextField(
        label: 'Preferred name',
        controller: name,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      MentoTextField(
        label: 'University or institution (optional)',
        controller: institution,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      MentoTextField(
        label: 'Course or programme',
        controller: course,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: MentoTextField(
              label: 'Academic year',
              controller: year,
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: MentoTextField(
              label: 'Semester',
              controller: semester,
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    ],
  );
}

class _ModulesStep extends StatelessWidget {
  const _ModulesStep({required this.modules});
  final TextEditingController modules;

  @override
  Widget build(BuildContext context) => _StepCard(
    icon: Icons.menu_book_outlined,
    title: 'What are you studying?',
    subtitle:
        'Add module names separated by commas or new lines. You can edit details later.',
    children: [
      MentoTextField(
        label: 'Modules (optional)',
        controller: modules,
        hint: 'Mobile Development, Data Science, Research Methods',
        maxLines: 5,
        keyboardType: TextInputType.multiline,
      ),
    ],
  );
}

class _RhythmStep extends StatelessWidget {
  const _RhythmStep({
    required this.studyHours,
    required this.sessionMinutes,
    required this.breakMinutes,
    required this.onStudyHours,
    required this.onSessionMinutes,
    required this.onBreakMinutes,
  });
  final double studyHours;
  final double sessionMinutes;
  final double breakMinutes;
  final ValueChanged<double> onStudyHours;
  final ValueChanged<double> onSessionMinutes;
  final ValueChanged<double> onBreakMinutes;

  @override
  Widget build(BuildContext context) => _StepCard(
    icon: Icons.schedule_outlined,
    title: 'Find your sustainable rhythm',
    subtitle: 'These limits keep plans realistic and leave room for rest.',
    children: [
      _SliderField(
        label: 'Available study time per day',
        value: studyHours,
        min: 1,
        max: 8,
        divisions: 14,
        suffix: 'hours',
        onChanged: onStudyHours,
      ),
      _SliderField(
        label: 'Preferred focus session',
        value: sessionMinutes,
        min: 20,
        max: 90,
        divisions: 14,
        suffix: 'minutes',
        onChanged: onSessionMinutes,
      ),
      _SliderField(
        label: 'Preferred break',
        value: breakMinutes,
        min: 5,
        max: 30,
        divisions: 5,
        suffix: 'minutes',
        onChanged: onBreakMinutes,
      ),
    ],
  );
}

class _SliderField extends StatelessWidget {
  const _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.suffix,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$label: ${value.round()} $suffix',
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Slider(
        value: value,
        min: min,
        max: max,
        divisions: divisions,
        label: '${value.round()} $suffix',
        onChanged: onChanged,
      ),
      const SizedBox(height: 8),
    ],
  );
}

class _GoalsStep extends StatelessWidget {
  const _GoalsStep({
    required this.goal,
    required this.preferences,
    required this.onToggle,
  });
  final TextEditingController goal;
  final Set<String> preferences;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    const options = [
      'Structured plans',
      'Flexible suggestions',
      'Gentle reminders',
      'Early deadlines',
      'Balanced routines',
      'Short sessions',
    ];
    return _StepCard(
      icon: Icons.track_changes_outlined,
      title: 'What would better feel like?',
      subtitle:
          'Choose how Mento should support you. Nothing here is permanent.',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              MentoChip(
                label: option,
                selected: preferences.contains(option),
                onSelected: (_) => onToggle(option),
              ),
          ],
        ),
        const SizedBox(height: 18),
        MentoTextField(
          label: 'Main study goal (optional)',
          controller: goal,
          hint: 'Keep coursework on track without losing weekends',
          maxLines: 3,
        ),
      ],
    );
  }
}

class _PreferencesStep extends StatelessWidget {
  const _PreferencesStep({
    required this.notifications,
    required this.wellness,
    required this.location,
    required this.acceptedTerms,
    required this.theme,
    required this.onNotifications,
    required this.onWellness,
    required this.onLocation,
    required this.onAcceptedTerms,
    required this.onTheme,
  });
  final bool notifications;
  final bool wellness;
  final bool location;
  final bool acceptedTerms;
  final ThemeMode theme;
  final ValueChanged<bool> onNotifications;
  final ValueChanged<bool> onWellness;
  final ValueChanged<bool> onLocation;
  final ValueChanged<bool> onAcceptedTerms;
  final ValueChanged<ThemeMode> onTheme;

  @override
  Widget build(BuildContext context) => _StepCard(
    icon: Icons.tune_outlined,
    title: 'Choose what feels helpful',
    subtitle:
        'Permissions are requested only when needed. Public achievements remain off by default.',
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Study reminders'),
        subtitle: const Text('Choose categories and quiet hours later.'),
        value: notifications,
        onChanged: onNotifications,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Wellness check-ins'),
        subtitle: const Text('Non-clinical and fully deletable.'),
        value: wellness,
        onChanged: onWellness,
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Set up location access'),
        subtitle: const Text(
          'Only for nearby study spaces; no location history.',
        ),
        value: location,
        onChanged: onLocation,
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<ThemeMode>(
        value: theme,
        decoration: const InputDecoration(labelText: 'Theme'),
        items: const [
          DropdownMenuItem(
            value: ThemeMode.system,
            child: Text('Use device setting'),
          ),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Light')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark')),
        ],
        onChanged: (value) {
          if (value != null) onTheme(value);
        },
      ),
      const SizedBox(height: 12),
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: acceptedTerms,
        onChanged: (value) => onAcceptedTerms(value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text('I accept the Terms and Privacy Notice'),
        subtitle: const Text(
          'Required before Mento saves your completed account setup.',
        ),
      ),
    ],
  );
}
