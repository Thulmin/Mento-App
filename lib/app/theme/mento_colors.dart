// Keeps brand and meaning-based colours consistent throughout the app.

import 'package:flutter/material.dart';

abstract final class MentoColors {
  static const midnight = Color(0xFF01011C);
  static const deepNavy = Color(0xFF030832);
  static const deepIndigo = Color(0xFF0D1044);
  static const mutedIndigo = Color(0xFF243574);

  static const cyan = Color(0xFF28B8FC);
  static const electricBlue = Color(0xFF247CF8);
  static const indigoViolet = Color(0xFF7651F8);
  static const premiumPurple = Color(0xFFA966FB);

  static const lightBackground = Color(0xFFF7F9FF);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightElevated = Color(0xFFF0F3FF);
  static const darkBackground = Color(0xFF05071A);
  static const darkSurface = Color(0xFF0D1035);
  static const darkElevated = Color(0xFF171A4A);

  static const success = Color(0xFF1FA971);
  static const warning = Color(0xFFF4A338);
  static const error = Color(0xFFE05263);
  static const information = Color(0xFF2699E6);

  static const primaryGradient = LinearGradient(
    colors: [cyan, electricBlue, indigoViolet, premiumPurple],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

@immutable
class MentoSemanticColors extends ThemeExtension<MentoSemanticColors> {
  const MentoSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.information,
    required this.onInformation,
    required this.elevatedSurface,
    required this.border,
    required this.focusIndicator,
    required this.textSecondary,
  });

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color information;
  final Color onInformation;
  final Color elevatedSurface;
  final Color border;
  final Color focusIndicator;
  final Color textSecondary;

  @override
  MentoSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? information,
    Color? onInformation,
    Color? elevatedSurface,
    Color? border,
    Color? focusIndicator,
    Color? textSecondary,
  }) {
    return MentoSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      information: information ?? this.information,
      onInformation: onInformation ?? this.onInformation,
      elevatedSurface: elevatedSurface ?? this.elevatedSurface,
      border: border ?? this.border,
      focusIndicator: focusIndicator ?? this.focusIndicator,
      textSecondary: textSecondary ?? this.textSecondary,
    );
  }

  @override
  MentoSemanticColors lerp(covariant MentoSemanticColors? other, double t) {
    if (other == null) return this;
    return MentoSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      information: Color.lerp(information, other.information, t)!,
      onInformation: Color.lerp(onInformation, other.onInformation, t)!,
      elevatedSurface: Color.lerp(elevatedSurface, other.elevatedSurface, t)!,
      border: Color.lerp(border, other.border, t)!,
      focusIndicator: Color.lerp(focusIndicator, other.focusIndicator, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
    );
  }
}

extension MentoThemeColors on BuildContext {
  MentoSemanticColors get mentoColors =>
      Theme.of(this).extension<MentoSemanticColors>()!;
}
