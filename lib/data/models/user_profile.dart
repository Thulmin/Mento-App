// Defines the student profile, preferences, onboarding draft, and saved goals.

import 'enums.dart';
import 'model_utils.dart';

final class UserPreferences {
  UserPreferences({
    this.preferredSessionMinutes = 50,
    this.preferredBreakMinutes = 10,
    this.maxDailyStudyMinutes = 240,
    Set<int> typicalStudyWeekdays = const {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    },
    this.remindersEnabled = true,
    this.wellnessTrackingEnabled = true,
    this.theme = ThemePreference.system,
    this.reducedMotion = false,
    this.timeZone = 'UTC',
  }) : typicalStudyWeekdays = Set.unmodifiable(typicalStudyWeekdays) {
    if (preferredSessionMinutes <= 0 ||
        preferredBreakMinutes < 0 ||
        maxDailyStudyMinutes <= 0) {
      throw ArgumentError('Study and break durations must be valid.');
    }
    if (typicalStudyWeekdays.any((day) => day < 1 || day > 7)) {
      throw ArgumentError('Study weekdays must be 1 through 7.');
    }
  }

  final int preferredSessionMinutes;
  final int preferredBreakMinutes;
  final int maxDailyStudyMinutes;
  final Set<int> typicalStudyWeekdays;
  final bool remindersEnabled;
  final bool wellnessTrackingEnabled;
  final ThemePreference theme;
  final bool reducedMotion;
  final String timeZone;

  factory UserPreferences.fromMap(Map<String, Object?> map) => UserPreferences(
    preferredSessionMinutes: ModelUtils.integer(
      map,
      'preferredSessionMinutes',
      fallback: 50,
    ),
    preferredBreakMinutes: ModelUtils.integer(
      map,
      'preferredBreakMinutes',
      fallback: 10,
    ),
    maxDailyStudyMinutes: ModelUtils.integer(
      map,
      'maxDailyStudyMinutes',
      fallback: 240,
    ),
    typicalStudyWeekdays:
        ModelUtils.list(
          map,
          'typicalStudyWeekdays',
          fallback: const [1, 2, 3, 4, 5],
        ).map((value) {
          if (value is! num) throw const FormatException('Invalid weekday.');
          return value.toInt();
        }).toSet(),
    remindersEnabled: ModelUtils.boolean(
      map,
      'remindersEnabled',
      fallback: true,
    ),
    wellnessTrackingEnabled: ModelUtils.boolean(
      map,
      'wellnessTrackingEnabled',
      fallback: true,
    ),
    theme: ModelUtils.enumValue(
      map,
      'theme',
      ThemePreference.values,
      fallback: ThemePreference.system,
    ),
    reducedMotion: ModelUtils.boolean(map, 'reducedMotion'),
    timeZone: ModelUtils.optionalString(map, 'timeZone') ?? 'UTC',
  );

  Map<String, Object?> toMap() => {
    'preferredSessionMinutes': preferredSessionMinutes,
    'preferredBreakMinutes': preferredBreakMinutes,
    'maxDailyStudyMinutes': maxDailyStudyMinutes,
    'typicalStudyWeekdays': typicalStudyWeekdays.toList()..sort(),
    'remindersEnabled': remindersEnabled,
    'wellnessTrackingEnabled': wellnessTrackingEnabled,
    'theme': theme.name,
    'reducedMotion': reducedMotion,
    'timeZone': timeZone,
  };
}

final class UserProfile {
  UserProfile({
    required this.id,
    required this.email,
    required this.preferredName,
    required this.programme,
    required this.academicYear,
    required this.semester,
    required this.preferences,
    required this.createdAt,
    required this.updatedAt,
    this.institution,
    this.photoUrl,
    this.photoSource,
    this.customPhotoPath,
    List<String> moduleIds = const [],
    List<String> studyGoals = const [],
    this.points = 0,
    this.currentStreak = 0,
    this.onboardingComplete = false,
  }) : moduleIds = List.unmodifiable(moduleIds),
       studyGoals = List.unmodifiable(studyGoals);

  final String id;
  final String email;
  final String preferredName;
  final String? institution;
  final String? photoUrl;
  final String? photoSource;
  final String? customPhotoPath;
  final String programme;
  final int academicYear;
  final String semester;
  final List<String> moduleIds;
  final List<String> studyGoals;
  final UserPreferences preferences;
  final int points;
  final int currentStreak;
  final bool onboardingComplete;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory UserProfile.fromMap(Map<String, Object?> map, {String? id}) {
    final preferences = map['preferences'];
    return UserProfile(
      id: id ?? ModelUtils.requiredString(map, 'id'),
      email: ModelUtils.requiredString(map, 'email'),
      preferredName: ModelUtils.requiredString(map, 'preferredName'),
      institution: ModelUtils.optionalString(map, 'institution'),
      photoUrl: ModelUtils.optionalString(map, 'photoUrl'),
      photoSource: ModelUtils.optionalString(map, 'photoSource'),
      customPhotoPath: ModelUtils.optionalString(map, 'customPhotoPath'),
      programme: ModelUtils.requiredString(map, 'programme'),
      academicYear: ModelUtils.integer(map, 'academicYear'),
      semester: ModelUtils.requiredString(map, 'semester'),
      moduleIds: ModelUtils.stringList(map, 'moduleIds'),
      studyGoals: ModelUtils.stringList(map, 'studyGoals'),
      preferences:
          preferences == null
              ? UserPreferences()
              : UserPreferences.fromMap(
                ModelUtils.objectMap(preferences, field: 'preferences'),
              ),
      points: ModelUtils.integer(map, 'points', fallback: 0),
      currentStreak: ModelUtils.integer(map, 'currentStreak', fallback: 0),
      onboardingComplete: ModelUtils.boolean(map, 'onboardingComplete'),
      createdAt: ModelUtils.dateTime(map, 'createdAt'),
      updatedAt: ModelUtils.dateTime(map, 'updatedAt'),
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'email': email,
    'preferredName': preferredName,
    'institution': institution,
    'photoUrl': photoUrl,
    'photoSource': photoSource,
    'customPhotoPath': customPhotoPath,
    'programme': programme,
    'academicYear': academicYear,
    'semester': semester,
    'moduleIds': moduleIds,
    'studyGoals': studyGoals,
    'preferences': preferences.toMap(),
    'points': points,
    'currentStreak': currentStreak,
    'onboardingComplete': onboardingComplete,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
  };
}

final class SavedLocation {
  SavedLocation({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.createdAt,
    this.address,
    this.isFavorite = false,
    this.notes,
  }) {
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'Must be -90 to 90.');
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError.value(longitude, 'longitude', 'Must be -180 to 180.');
    }
  }

  final String id;
  final String name;
  final String? address;
  final double latitude;
  final double longitude;
  final SavedLocationType type;
  final bool isFavorite;
  final String? notes;
  final DateTime createdAt;

  factory SavedLocation.fromMap(Map<String, Object?> map, {String? id}) =>
      SavedLocation(
        id: id ?? ModelUtils.requiredString(map, 'id'),
        name: ModelUtils.requiredString(map, 'name'),
        address: ModelUtils.optionalString(map, 'address'),
        latitude: ModelUtils.decimal(map, 'latitude'),
        longitude: ModelUtils.decimal(map, 'longitude'),
        type: ModelUtils.enumValue(
          map,
          'type',
          SavedLocationType.values,
          fallback: SavedLocationType.other,
        ),
        isFavorite: ModelUtils.boolean(map, 'isFavorite'),
        notes: ModelUtils.optionalString(map, 'notes'),
        createdAt: ModelUtils.dateTime(map, 'createdAt'),
      );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
    'type': type.name,
    'isFavorite': isFavorite,
    'notes': notes,
    'createdAt': createdAt,
  };
}

typedef Preferences = UserPreferences;
