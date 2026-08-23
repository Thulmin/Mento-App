// Builds Mento's matching Material 3 light and dark themes.

import 'package:flutter/material.dart';

import 'mento_colors.dart';

abstract final class MentoTheme {
  static const _radius = 18.0;

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: dark ? MentoColors.cyan : MentoColors.electricBlue,
      onPrimary: dark ? MentoColors.midnight : Colors.white,
      primaryContainer:
          dark ? MentoColors.mutedIndigo : const Color(0xFFDCE8FF),
      onPrimaryContainer: dark ? Colors.white : MentoColors.deepNavy,
      secondary: dark ? const Color(0xFFBBA8FF) : MentoColors.indigoViolet,
      onSecondary: dark ? MentoColors.midnight : Colors.white,
      secondaryContainer:
          dark ? const Color(0xFF332C65) : const Color(0xFFE9E2FF),
      onSecondaryContainer: dark ? Colors.white : MentoColors.deepNavy,
      tertiary: dark ? const Color(0xFFE5A9FF) : MentoColors.premiumPurple,
      onTertiary: dark ? MentoColors.midnight : Colors.white,
      error: dark ? const Color(0xFFFFB2BA) : MentoColors.error,
      onError: dark ? const Color(0xFF650019) : Colors.white,
      surface: dark ? MentoColors.darkSurface : MentoColors.lightSurface,
      onSurface: dark ? const Color(0xFFF4F3FF) : MentoColors.deepNavy,
      surfaceContainerHighest:
          dark ? MentoColors.darkElevated : MentoColors.lightElevated,
      onSurfaceVariant:
          dark ? const Color(0xFFC6C7DE) : const Color(0xFF586078),
      outline: dark ? const Color(0xFF555979) : const Color(0xFFC8CDE0),
      outlineVariant: dark ? const Color(0xFF343854) : const Color(0xFFE1E5F0),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: dark ? const Color(0xFFF4F3FF) : MentoColors.deepNavy,
      onInverseSurface: dark ? MentoColors.deepNavy : Colors.white,
      inversePrimary: dark ? MentoColors.electricBlue : MentoColors.cyan,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          dark ? MentoColors.darkBackground : MentoColors.lightBackground,
      visualDensity: VisualDensity.standard,
    );

    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
      ),
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.4),
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: [
        MentoSemanticColors(
          success: dark ? const Color(0xFF66D8A6) : MentoColors.success,
          onSuccess: dark ? MentoColors.midnight : Colors.white,
          warning: dark ? const Color(0xFFFFC36B) : MentoColors.warning,
          onWarning: MentoColors.midnight,
          information: dark ? const Color(0xFF6CC7FF) : MentoColors.information,
          onInformation: dark ? MentoColors.midnight : Colors.white,
          elevatedSurface:
              dark ? MentoColors.darkElevated : MentoColors.lightElevated,
          border: scheme.outlineVariant,
          focusIndicator: dark ? MentoColors.cyan : MentoColors.indigoViolet,
          textSecondary: scheme.onSurfaceVariant,
        ),
      ],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
      ),
      cardTheme: CardTheme(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(_radius),
        ),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? MentoColors.darkElevated : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size.square(48)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        minWidth: 80,
        labelType: NavigationRailLabelType.all,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        circularTrackColor: scheme.surfaceContainerHighest,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      focusColor: dark ? MentoColors.cyan : MentoColors.indigoViolet,
    );
  }
}
