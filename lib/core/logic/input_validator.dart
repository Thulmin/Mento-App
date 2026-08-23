// Holds reusable validation rules for forms and user-entered values.

abstract final class InputValidator {
  static String? requiredText(
    String? value, {
    String fieldName = 'This field',
    int maxLength = 200,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$fieldName is required.';
    if (text.length > maxLength) {
      return '$fieldName must be $maxLength characters or fewer.';
    }
    return null;
  }

  static String? preferredName(String? value) {
    final required = requiredText(value, fieldName: 'Name', maxLength: 80);
    if (required != null) return required;
    if (!RegExp(
      r"^[\p{L}\p{M}][\p{L}\p{M} .'-]*$",
      unicode: true,
    ).hasMatch(value!.trim())) {
      return 'Enter a valid name.';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required.';
    if (text.length > 254 || text.contains('..')) {
      return 'Enter a valid email address.';
    }
    final parts = text.split('@');
    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      return 'Enter a valid email address.';
    }
    if (parts.first.length > 64 ||
        !RegExp(
          r'^[A-Za-z0-9.!#$%&\x27*+/=?^_`{|}~-]+$',
        ).hasMatch(parts.first) ||
        !RegExp(
          r'^(?=.{1,253}$)([A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,63}$',
        ).hasMatch(parts.last)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  static List<String> passwordRequirements(String? value) {
    final password = value ?? '';
    final errors = <String>[];
    if (password.length < 10) {
      errors.add('Use at least 10 characters.');
    }
    if (password.length > 128) {
      errors.add('Use no more than 128 characters.');
    }
    if (!RegExp('[a-z]').hasMatch(password)) {
      errors.add('Add a lowercase letter.');
    }
    if (!RegExp('[A-Z]').hasMatch(password)) {
      errors.add('Add an uppercase letter.');
    }
    if (!RegExp('[0-9]').hasMatch(password)) {
      errors.add('Add a number.');
    }
    if (!RegExp(r'[^A-Za-z0-9\s]').hasMatch(password)) {
      errors.add('Add a symbol.');
    }
    return List.unmodifiable(errors);
  }

  static String? password(String? value) {
    final requirements = passwordRequirements(value);
    return requirements.isEmpty ? null : requirements.first;
  }

  static String? confirmPassword(String? value, String? password) {
    if ((value ?? '').isEmpty) return 'Confirm your password.';
    if (value != password) return 'Passwords do not match.';
    return null;
  }

  static String? moduleCode(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Module code is required.';
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9 _-]{1,19}$').hasMatch(text)) {
      return 'Use 2–20 letters, numbers, spaces, hyphens, or underscores.';
    }
    return null;
  }

  static String? positiveMinutes(int? value, {int maximum = 1440}) {
    if (value == null) return 'Duration is required.';
    if (value <= 0) return 'Duration must be greater than zero.';
    if (value > maximum) return 'Duration cannot exceed $maximum minutes.';
    return null;
  }

  static String? dateRange(DateTime? start, DateTime? end) {
    if (start == null || end == null) {
      return 'Start and end times are required.';
    }
    if (!end.isAfter(start)) return 'End time must be after start time.';
    return null;
  }

  static String? coordinates(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'Latitude and longitude are required.';
    }
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      return 'Latitude must be between -90 and 90.';
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      return 'Longitude must be between -180 and 180.';
    }
    return null;
  }
}
