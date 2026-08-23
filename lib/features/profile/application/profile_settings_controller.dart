// Loads and saves profile details, preferences, and profile-photo operations.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/theme_controller.dart';
import '../../authentication/application/auth_providers.dart';
import '../../authentication/domain/session_state.dart';
import '../data/profile_photo_repository.dart';

final profilePhotoRepositoryProvider = Provider<ProfilePhotoRepository>((ref) {
  return ProfilePhotoRepository();
});

class ProfileSettingsState {
  const ProfileSettingsState({
    required this.preferredName,
    required this.course,
    required this.studySessionMinutes,
    required this.breakMinutes,
    required this.quietStartHour,
    required this.quietEndHour,
    required this.notificationsEnabled,
    required this.aiEnabled,
    required this.locationEnabled,
    required this.wellnessEnabled,
    required this.publicAchievements,
    required this.reducedMotion,
    this.photoUrl,
    this.hasCustomPhoto = false,
    this.photoOperationInProgress = false,
  });

  factory ProfileSettingsState.defaults(String name) => ProfileSettingsState(
    preferredName: name,
    course: '',
    studySessionMinutes: 45,
    breakMinutes: 10,
    quietStartHour: 22,
    quietEndHour: 7,
    notificationsEnabled: true,
    aiEnabled: true,
    locationEnabled: false,
    wellnessEnabled: true,
    publicAchievements: false,
    reducedMotion: false,
    photoUrl: null,
    hasCustomPhoto: false,
    photoOperationInProgress: false,
  );

  final String preferredName;
  final String course;
  final int studySessionMinutes;
  final int breakMinutes;
  final int quietStartHour;
  final int quietEndHour;
  final bool notificationsEnabled;
  final bool aiEnabled;
  final bool locationEnabled;
  final bool wellnessEnabled;
  final bool publicAchievements;
  final bool reducedMotion;
  final String? photoUrl;
  final bool hasCustomPhoto;
  final bool photoOperationInProgress;

  ProfileSettingsState copyWith({
    String? preferredName,
    String? course,
    int? studySessionMinutes,
    int? breakMinutes,
    int? quietStartHour,
    int? quietEndHour,
    bool? notificationsEnabled,
    bool? aiEnabled,
    bool? locationEnabled,
    bool? wellnessEnabled,
    bool? publicAchievements,
    bool? reducedMotion,
    Object? photoUrl = _notProvided,
    bool? hasCustomPhoto,
    bool? photoOperationInProgress,
  }) => ProfileSettingsState(
    preferredName: preferredName ?? this.preferredName,
    course: course ?? this.course,
    studySessionMinutes: studySessionMinutes ?? this.studySessionMinutes,
    breakMinutes: breakMinutes ?? this.breakMinutes,
    quietStartHour: quietStartHour ?? this.quietStartHour,
    quietEndHour: quietEndHour ?? this.quietEndHour,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    aiEnabled: aiEnabled ?? this.aiEnabled,
    locationEnabled: locationEnabled ?? this.locationEnabled,
    wellnessEnabled: wellnessEnabled ?? this.wellnessEnabled,
    publicAchievements: publicAchievements ?? this.publicAchievements,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    photoUrl:
        identical(photoUrl, _notProvided) ? this.photoUrl : photoUrl as String?,
    hasCustomPhoto: hasCustomPhoto ?? this.hasCustomPhoto,
    photoOperationInProgress:
        photoOperationInProgress ?? this.photoOperationInProgress,
  );
}

const Object _notProvided = Object();

final profileSettingsProvider =
    AsyncNotifierProvider<ProfileSettingsController, ProfileSettingsState>(
      ProfileSettingsController.new,
    );

class ProfileSettingsController extends AsyncNotifier<ProfileSettingsState> {
  @override
  Future<ProfileSettingsState> build() async {
    final session = ref.watch(sessionProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final user = session.user;
    var result = ProfileSettingsState.defaults(session.displayName).copyWith(
      reducedMotion: prefs.getBool('mento.reduced_motion') ?? false,
      photoUrl:
          user == null
              ? null
              : ProfilePhotoRepository.linkedGooglePhotoUrl(user) ??
                  _nullableString(user.photoURL),
    );
    if (session.status == SessionStatus.demo || session.user == null) {
      return result;
    }
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(session.user!.uid)
              .get();
      final data = snapshot.data() ?? const <String, dynamic>{};
      final profile =
          (data['profile'] as Map?)?.cast<String, dynamic>() ?? const {};
      final settings =
          (data['preferences'] as Map?)?.cast<String, dynamic>() ?? const {};
      final storedPhotoUrl = _nullableString(profile['photoUrl']);
      final photoSource = _nullableString(profile['photoSource']);
      final linkedGooglePhoto = ProfilePhotoRepository.linkedGooglePhotoUrl(
        session.user!,
      );
      final hasCustomPhoto =
          photoSource == 'custom' &&
          storedPhotoUrl != null &&
          storedPhotoUrl.isNotEmpty;
      result = result.copyWith(
        preferredName: _string(profile['preferredName'], result.preferredName),
        course: _string(profile['course'], ''),
        studySessionMinutes: _integer(settings['studySessionMinutes'], 45),
        breakMinutes: _integer(settings['breakMinutes'], 10),
        quietStartHour: _integer(settings['quietStartHour'], 22),
        quietEndHour: _integer(settings['quietEndHour'], 7),
        notificationsEnabled: _boolean(settings['notificationsEnabled'], true),
        aiEnabled: _boolean(settings['aiEnabled'], true),
        locationEnabled: _boolean(settings['locationEnabled'], false),
        wellnessEnabled: _boolean(settings['wellnessEnabled'], true),
        publicAchievements: _boolean(settings['publicAchievements'], false),
        reducedMotion: _boolean(
          settings['reducedMotion'],
          result.reducedMotion,
        ),
        photoUrl:
            hasCustomPhoto
                ? storedPhotoUrl
                : linkedGooglePhoto ??
                    storedPhotoUrl ??
                    _nullableString(session.user!.photoURL),
        hasCustomPhoto: hasCustomPhoto,
      );
    } catch (_) {
      // Firestore's cached settings remain optional; local accessibility
      // preferences still load and writes will retry through the SDK.
    }
    return result;
  }

  Future<void> updateProfile({
    required String name,
    required String course,
  }) async {
    final current = state.requireValue;
    final next = current.copyWith(
      preferredName: name.trim(),
      course: course.trim(),
    );
    state = AsyncData(next);
    final session = ref.read(sessionProvider);
    if (session.status == SessionStatus.demo || session.user == null) return;
    await session.user!.updateDisplayName(name.trim());
    await FirebaseFirestore.instance
        .collection('users')
        .doc(session.user!.uid)
        .set({
          'profile': {'preferredName': name.trim(), 'course': course.trim()},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> updateStudyRhythm({
    required int sessionMinutes,
    required int breakMinutes,
  }) => _update(
    state.requireValue.copyWith(
      studySessionMinutes: sessionMinutes,
      breakMinutes: breakMinutes,
    ),
    {'studySessionMinutes': sessionMinutes, 'breakMinutes': breakMinutes},
  );

  Future<void> updateQuietHours({
    required int startHour,
    required int endHour,
  }) => _update(
    state.requireValue.copyWith(
      quietStartHour: startHour,
      quietEndHour: endHour,
    ),
    {'quietStartHour': startHour, 'quietEndHour': endHour},
  );

  Future<void> setNotifications(bool value) => _update(
    state.requireValue.copyWith(notificationsEnabled: value),
    {'notificationsEnabled': value},
  );
  Future<void> setAi(bool value) => _update(
    state.requireValue.copyWith(aiEnabled: value),
    {'aiEnabled': value},
  );
  Future<void> setLocation(bool value) => _update(
    state.requireValue.copyWith(locationEnabled: value),
    {'locationEnabled': value},
  );
  Future<void> setWellness(bool value) => _update(
    state.requireValue.copyWith(wellnessEnabled: value),
    {'wellnessEnabled': value},
  );
  Future<void> setPublicAchievements(bool value) => _update(
    state.requireValue.copyWith(publicAchievements: value),
    {'publicAchievements': value},
  );

  Future<void> setReducedMotion(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool('mento.reduced_motion', value);
    await _update(state.requireValue.copyWith(reducedMotion: value), {
      'reducedMotion': value,
    });
  }

  Future<bool> chooseAndUploadPhoto() async {
    final current = state.requireValue;
    final session = ref.read(sessionProvider);
    final user = session.user;
    if (session.status == SessionStatus.demo || user == null) {
      throw const ProfilePhotoException(
        'Sign in to upload a private profile photo.',
      );
    }
    state = AsyncData(current.copyWith(photoOperationInProgress: true));
    try {
      final repository = ref.read(profilePhotoRepositoryProvider);
      final selection = await repository.pickFromGallery();
      if (selection == null) {
        state = AsyncData(current);
        return false;
      }
      final photoUrl = await repository.upload(uid: user.uid, photo: selection);
      state = AsyncData(
        current.copyWith(
          photoUrl: photoUrl,
          hasCustomPhoto: true,
          photoOperationInProgress: false,
        ),
      );
      return true;
    } catch (error, stackTrace) {
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> removeCustomPhoto() async {
    final current = state.requireValue;
    final session = ref.read(sessionProvider);
    final user = session.user;
    if (session.status == SessionStatus.demo || user == null) {
      throw const ProfilePhotoException(
        'Sign in to change your profile photo.',
      );
    }
    state = AsyncData(current.copyWith(photoOperationInProgress: true));
    try {
      final fallback = await ref
          .read(profilePhotoRepositoryProvider)
          .remove(uid: user.uid);
      state = AsyncData(
        current.copyWith(
          photoUrl: fallback,
          hasCustomPhoto: false,
          photoOperationInProgress: false,
        ),
      );
    } catch (error, stackTrace) {
      state = AsyncData(current);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<void> _update(
    ProfileSettingsState next,
    Map<String, Object?> changed,
  ) async {
    final previous = state;
    state = AsyncData(next);
    final session = ref.read(sessionProvider);
    if (session.status == SessionStatus.demo || session.user == null) return;
    try {
      final updates = <String, Object?>{
        for (final entry in changed.entries)
          'preferences.${entry.key}': entry.value,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(session.user!.uid)
          .update(updates);
    } catch (error, stackTrace) {
      state = previous;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static String _string(Object? value, String fallback) =>
      value is String && value.trim().isNotEmpty ? value : fallback;
  static String? _nullableString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;
  static int _integer(Object? value, int fallback) =>
      value is num ? value.toInt() : fallback;
  static bool _boolean(Object? value, bool fallback) =>
      value is bool ? value : fallback;
}
