// Converts loosely typed stored values into safe values for domain models.

/// Shared, dependency-free decoding helpers for persisted Mento models.
///
/// Firestore accepts [DateTime] values directly. Decoders also accept epoch
/// milliseconds and ISO-8601 strings so the domain layer can be tested without
/// importing `cloud_firestore`.
abstract final class ModelUtils {
  static String requiredString(
    Map<String, Object?> map,
    String key, {
    String? fallback,
  }) {
    final value = map[key] ?? fallback;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw FormatException('Expected a non-empty string for "$key".');
  }

  static String? optionalString(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Expected a string for "$key".');
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool boolean(
    Map<String, Object?> map,
    String key, {
    bool fallback = false,
  }) {
    final value = map[key];
    if (value == null) return fallback;
    if (value is bool) return value;
    throw FormatException('Expected a boolean for "$key".');
  }

  static int integer(Map<String, Object?> map, String key, {int? fallback}) {
    final value = map[key];
    if (value == null && fallback != null) return fallback;
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw FormatException('Expected an integer for "$key".');
  }

  static double decimal(
    Map<String, Object?> map,
    String key, {
    double? fallback,
  }) {
    final value = map[key];
    if (value == null && fallback != null) return fallback;
    if (value is num && value.isFinite) return value.toDouble();
    throw FormatException('Expected a finite number for "$key".');
  }

  static DateTime dateTime(
    Map<String, Object?> map,
    String key, {
    DateTime? fallback,
  }) {
    final value = map[key];
    if (value == null && fallback != null) return fallback;
    return dateTimeValue(value, field: key);
  }

  static DateTime? optionalDateTime(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    return dateTimeValue(value, field: key);
  }

  static DateTime dateTimeValue(Object? value, {String field = 'date'}) {
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
    }
    if (value is num && value.isFinite) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    if (value is Map) {
      final seconds = value['seconds'];
      final nanoseconds = value['nanoseconds'] ?? 0;
      if (seconds is num && nanoseconds is num) {
        return DateTime.fromMicrosecondsSinceEpoch(
          seconds.toInt() * Duration.microsecondsPerSecond +
              nanoseconds.toInt() ~/ 1000,
          isUtc: true,
        );
      }
    }
    throw FormatException(
      'Expected DateTime, epoch milliseconds, or ISO-8601 text for "$field".',
    );
  }

  static List<Object?> list(
    Map<String, Object?> map,
    String key, {
    List<Object?> fallback = const [],
  }) {
    final value = map[key];
    if (value == null) return fallback;
    if (value is List) return List<Object?>.from(value);
    throw FormatException('Expected a list for "$key".');
  }

  static List<String> stringList(
    Map<String, Object?> map,
    String key, {
    List<String> fallback = const [],
  }) {
    final values = list(map, key, fallback: fallback);
    if (values.any((value) => value is! String)) {
      throw FormatException('Expected only strings in "$key".');
    }
    return values.cast<String>().map((value) => value.trim()).toList();
  }

  static Map<String, Object?> objectMap(Object? value, {String field = 'map'}) {
    if (value is Map) {
      return value.map((key, entry) => MapEntry(key.toString(), entry));
    }
    throw FormatException('Expected an object for "$field".');
  }

  static T enumValue<T extends Enum>(
    Map<String, Object?> map,
    String key,
    List<T> values, {
    T? fallback,
  }) {
    final raw = map[key];
    if (raw == null && fallback != null) return fallback;
    if (raw is String) {
      for (final value in values) {
        if (value.name == raw) return value;
      }
    }
    throw FormatException('Unknown value "$raw" for "$key".');
  }

  static double clampUnit(double value) => value.clamp(0.0, 1.0);

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
