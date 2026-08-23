// Presents account details, preferences, privacy controls, and the app version.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../app/responsive/breakpoints.dart';
import '../../../app/theme/theme_controller.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/mento_card.dart';
import '../../../core/widgets/mento_controls.dart';
import '../../../core/widgets/mento_states.dart';
import '../../authentication/application/auth_providers.dart';
import '../../authentication/data/auth_repository.dart';
import '../../authentication/domain/session_state.dart';
import '../application/profile_settings_controller.dart';
import '../data/profile_photo_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final settings = ref.watch(profileSettingsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const MentoScreenTitle(
          title: 'Profile & settings',
          semanticIdentifier: 'mento_screen_profile',
        ),
      ),
      body: settings.when(
        loading:
            () => const MentoPage(
              child: Column(
                children: [
                  MentoLoadingSkeleton(height: 120),
                  SizedBox(height: 16),
                  MentoLoadingSkeleton(height: 280),
                ],
              ),
            ),
        error:
            (_, __) => MentoErrorState(
              title: 'Settings are unavailable',
              message:
                  'Your local preferences are safe. Retry when your connection returns.',
              onRetry: () => ref.invalidate(profileSettingsProvider),
            ),
        data:
            (value) => MentoPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ProfileHeader(
                    session: session,
                    settings: value,
                    onEdit: () => _editProfile(context, ref, value),
                    onPhotoTap:
                        session.status == SessionStatus.demo
                            ? null
                            : () => _editProfilePhoto(context, ref, value),
                  ),
                  const SizedBox(height: 18),
                  _AppearanceCard(settings: value),
                  const SizedBox(height: 18),
                  _PreferencesCard(settings: value),
                  const SizedBox(height: 18),
                  _PrivacyCard(session: session),
                  const SizedBox(height: 18),
                  _AccountCard(session: session),
                  const SizedBox(height: 24),
                  const _VersionText(),
                ],
              ),
            ),
      ),
    );
  }

  Future<void> _editProfile(
    BuildContext context,
    WidgetRef ref,
    ProfileSettingsState settings,
  ) async {
    final name = TextEditingController(text: settings.preferredName);
    final course = TextEditingController(text: settings.course);
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                20 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit profile',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 18),
                  MentoTextField(label: 'Preferred name', controller: name),
                  const SizedBox(height: 12),
                  MentoTextField(
                    label: 'Course or programme',
                    controller: course,
                  ),
                  const SizedBox(height: 18),
                  MentoButton(
                    label: 'Save changes',
                    onPressed:
                        () => Navigator.pop(
                          context,
                          name.text.trim().length >= 2,
                        ),
                  ),
                ],
              ),
            ),
          ),
    );
    if (saved == true && context.mounted) {
      try {
        await ref
            .read(profileSettingsProvider.notifier)
            .updateProfile(name: name.text, course: course.text);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Profile changes could not be saved. Please retry.',
              ),
            ),
          );
        }
      }
    }
    name.dispose();
    course.dispose();
  }

  Future<void> _editProfilePhoto(
    BuildContext context,
    WidgetRef ref,
    ProfileSettingsState settings,
  ) async {
    final action = await showModalBottomSheet<_ProfilePhotoAction>(
      context: context,
      builder:
          (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(
                    settings.hasCustomPhoto
                        ? 'Replace profile photo'
                        : 'Choose profile photo',
                  ),
                  subtitle: const Text('JPEG, PNG or WebP · maximum 5 MB'),
                  onTap:
                      () => Navigator.pop(context, _ProfilePhotoAction.choose),
                ),
                if (settings.hasCustomPhoto)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      'Remove custom photo',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    subtitle: const Text(
                      'Your linked Google photo will be restored when available.',
                    ),
                    onTap:
                        () =>
                            Navigator.pop(context, _ProfilePhotoAction.remove),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
    );
    if (action == null || !context.mounted) return;
    try {
      final controller = ref.read(profileSettingsProvider.notifier);
      if (action == _ProfilePhotoAction.choose) {
        final uploaded = await controller.chooseAndUploadPhoto();
        if (uploaded && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated.')),
          );
        }
      } else {
        await controller.removeCustomPhoto();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Custom profile photo removed.')),
          );
        }
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is ProfilePhotoException
                  ? error.message
                  : 'The profile photo could not be changed. Please retry.',
            ),
          ),
        );
      }
    }
  }
}

enum _ProfilePhotoAction { choose, remove }

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.session,
    required this.settings,
    required this.onEdit,
    required this.onPhotoTap,
  });
  final SessionState session;
  final ProfileSettingsState settings;
  final VoidCallback onEdit;
  final VoidCallback? onPhotoTap;

  @override
  Widget build(BuildContext context) => MentoCard(
    child: Row(
      children: [
        ProfileAvatar(
          name: settings.preferredName,
          photoUrl: settings.photoUrl,
          busy: settings.photoOperationInProgress,
          onTap: onPhotoTap,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settings.preferredName,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (settings.course.isNotEmpty) Text(settings.course),
              Text(
                session.status == SessionStatus.demo
                    ? 'Safe demo — no cloud writes'
                    : session.user?.email ?? '',
              ),
            ],
          ),
        ),
        MentoIconButton(
          icon: Icons.edit_outlined,
          tooltip: 'Edit profile',
          onPressed: onEdit,
        ),
      ],
    ),
  );
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    required this.photoUrl,
    required this.busy,
    required this.onTap,
  });

  final String name;
  final String? photoUrl;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: 32,
      child: Text(name.characters.firstOrNull?.toUpperCase() ?? 'M'),
    );
    final avatar =
        photoUrl == null
            ? fallback
            : ClipOval(
              key: const Key('profile-photo-clip'),
              child: Image.network(
                photoUrl!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => fallback,
              ),
            );
    return Semantics(
      button: onTap != null,
      label: onTap == null ? 'Profile photo' : 'Change profile photo',
      child: InkResponse(
        onTap: busy ? null : onTap,
        radius: 38,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              avatar,
              if (busy)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else if (onTap != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(5),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard({required this.settings});
  final ProfileSettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MentoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Appearance & accessibility',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<ThemeMode>(
            value: themeMode,
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
              if (value != null) {
                ref.read(themeModeProvider.notifier).setMode(value);
              }
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Reduce motion'),
            subtitle: const Text(
              'Minimises non-essential transitions and celebration effects.',
            ),
            value: settings.reducedMotion,
            onChanged:
                (value) => _guard(
                  context,
                  () => ref
                      .read(profileSettingsProvider.notifier)
                      .setReducedMotion(value),
                ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesCard extends ConsumerWidget {
  const _PreferencesCard({required this.settings});
  final ProfileSettingsState settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MentoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Support preferences',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Local reminders'),
          subtitle: Text(
            'Quiet hours ${_hour(settings.quietStartHour)}–${_hour(settings.quietEndHour)}',
          ),
          value: settings.notificationsEnabled,
          onChanged: (value) async {
            if (value &&
                !await NotificationService.instance.requestPermission()) {
              return;
            }
            if (context.mounted) {
              await _guard(
                context,
                () => ref
                    .read(profileSettingsProvider.notifier)
                    .setNotifications(value),
              );
            }
          },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('AI planning and assistant'),
          subtitle: const Text(
            'Uses minimised context through the authenticated Mento proxy.',
          ),
          value: settings.aiEnabled,
          onChanged:
              (value) => _guard(
                context,
                () => ref.read(profileSettingsProvider.notifier).setAi(value),
              ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Location features'),
          subtitle: const Text(
            'Requested only when opening nearby study spaces; no history.',
          ),
          value: settings.locationEnabled,
          onChanged:
              (value) => _guard(
                context,
                () => ref
                    .read(profileSettingsProvider.notifier)
                    .setLocation(value),
              ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Wellness tracking'),
          subtitle: const Text(
            'Optional, non-clinical check-ins that you can delete.',
          ),
          value: settings.wellnessEnabled,
          onChanged:
              (value) => _guard(
                context,
                () => ref
                    .read(profileSettingsProvider.notifier)
                    .setWellness(value),
              ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Public achievement showcase'),
          subtitle: const Text(
            'Off by default. Never shares email, timetable, deadlines or wellness.',
          ),
          value: settings.publicAchievements,
          onChanged:
              (value) => _guard(
                context,
                () => ref
                    .read(profileSettingsProvider.notifier)
                    .setPublicAchievements(value),
              ),
        ),
      ],
    ),
  );

  static String _hour(int hour) => '${hour.toString().padLeft(2, '0')}:00';
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.session});
  final SessionState session;

  @override
  Widget build(BuildContext context) => MentoCard(
    child: Column(
      children: [
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.privacy_tip_outlined),
          title: Text('Privacy summary'),
          subtitle: Text(
            'Private user-scoped data, no continuous location tracking, and no AI provider keys in this app.',
          ),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.download_outlined),
          title: Text('Data export'),
          subtitle: Text(
            'A portable export can be requested after backend export configuration is enabled.',
          ),
        ),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.info_outline),
          title: Text('About Mento'),
          subtitle: Text(
            'A calm student lifestyle and study companion. AI output is advisory, not guaranteed.',
          ),
        ),
      ],
    ),
  );
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.session});
  final SessionState session;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MentoCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Account', style: Theme.of(context).textTheme.titleLarge),
        if (session.status != SessionStatus.demo) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.link),
            title: const Text('Link Google sign-in'),
            subtitle: const Text(
              'Keep one profile when using multiple providers.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _linkGoogle(context, ref),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.delete_forever_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              'Delete account and data',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('Permanent. Requires recent authentication.'),
            onTap: () => _deleteAccount(context, ref),
          ),
        ],
        const SizedBox(height: 8),
        MentoButton(
          label:
              session.status == SessionStatus.demo ? 'Exit demo' : 'Sign out',
          icon: Icons.logout,
          variant: MentoButtonVariant.outlined,
          onPressed: () => ref.read(sessionProvider.notifier).exitSession(),
        ),
      ],
    ),
  );

  Future<void> _linkGoogle(BuildContext context, WidgetRef ref) async {
    final success = await ref.read(authActionProvider.notifier).run((
      repo,
    ) async {
      await repo.linkGoogle();
    });
    if (success && context.mounted) {
      ref.invalidate(profileSettingsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Google sign-in linked.')));
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final passwordProvider =
        session.user?.providerData.any(
          (item) => item.providerId == 'password',
        ) ??
        false;
    final password = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete account and all data?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This permanently deletes private academic, focus, habit, wellness and AI-conversation records.',
                ),
                if (passwordProvider) ...[
                  const SizedBox(height: 16),
                  MentoPasswordField(
                    label: 'Password to confirm',
                    controller: password,
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.pop(
                      context,
                      !passwordProvider || password.text.isNotEmpty,
                    ),
                child: const Text('Delete permanently'),
              ),
            ],
          ),
    );
    if (confirmed == true && context.mounted) {
      final success = await ref.read(authActionProvider.notifier).run((
        repo,
      ) async {
        if (passwordProvider) {
          await repo.reauthenticateWithPassword(password.text);
        }
        await repo.deleteAccountAndData();
      });
      if (!success && context.mounted) {
        final error = ref.read(authActionProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is AuthFailure
                  ? error.message
                  : 'Account deletion could not complete.',
            ),
          ),
        );
      }
    }
    password.dispose();
  }
}

class _VersionText extends StatefulWidget {
  const _VersionText();

  @override
  State<_VersionText> createState() => _VersionTextState();
}

class _VersionTextState extends State<_VersionText> {
  String _version = 'Version information loading';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((value) {
      if (mounted) {
        // The build number is useful to app stores but not needed in this
        // user-facing label, so only the readable release version is shown.
        setState(() => _version = 'Mento ${value.version}');
      }
    });
  }

  @override
  Widget build(BuildContext context) => Text(
    _version,
    textAlign: TextAlign.center,
    style: Theme.of(context).textTheme.bodySmall,
  );
}

Future<void> _guard(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That preference could not be saved. Please retry.'),
        ),
      );
    }
  }
}

extension _FirstCharacter on Characters {
  String? get firstOrNull => isEmpty ? null : first;
}
