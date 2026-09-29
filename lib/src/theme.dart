import 'package:flutter/material.dart';

/// Colours named after traditional Chinese ones. The moon is the app's
/// motif: 月 means both moon and month, and 月经 is the word for a period.
abstract final class LunaPalette {
  static const moonWhite = Color(0xFFF1F6F8); // 月白, lightened for the page
  static const moonWhiteDeep = Color(0xFFD6ECF0); // 月白
  static const ink = Color(0xFF2E3446); // 黛
  static const rouge = Color(0xFFA8323E); // 胭脂
  static const celadon = Color(0xFF2F7A84); // 天水碧, deepened for contrast
  static const gamboge = Color(0xFFE2A93B); // 藤黄
  static const night = Color(0xFF151923); // 玄青, the dark theme's page
}

/// Colours for the cycle itself, shared by the dial, calendar and records.
@immutable
class CycleColors extends ThemeExtension<CycleColors> {
  const CycleColors({
    required this.period,
    required this.onPeriod,
    required this.predicted,
    required this.fertile,
    required this.ovulation,
    required this.onOvulation,
    required this.moon,
    required this.moonShadow,
    required this.today,
    required this.track,
  });

  /// Recorded period days.
  final Color period;
  final Color onPeriod;

  /// Background of predicted period days; their text uses [period]. Opaque,
  /// like [fertile], so neighbouring days can overlap without a seam.
  final Color predicted;

  /// Background of the fertile window.
  final Color fertile;

  /// Predicted ovulation day.
  final Color ovulation;
  final Color onOvulation;

  /// The lit and unlit parts of the moon.
  final Color moon;
  final Color moonShadow;

  /// Today's marker on the dial and calendar.
  final Color today;

  /// Ordinary days on the dial and timeline.
  final Color track;

  static CycleColors of(BuildContext context) =>
      Theme.of(context).extension<CycleColors>()!;

  @override
  CycleColors copyWith({
    Color? period,
    Color? onPeriod,
    Color? predicted,
    Color? fertile,
    Color? ovulation,
    Color? onOvulation,
    Color? moon,
    Color? moonShadow,
    Color? today,
    Color? track,
  }) => CycleColors(
    period: period ?? this.period,
    onPeriod: onPeriod ?? this.onPeriod,
    predicted: predicted ?? this.predicted,
    fertile: fertile ?? this.fertile,
    ovulation: ovulation ?? this.ovulation,
    onOvulation: onOvulation ?? this.onOvulation,
    moon: moon ?? this.moon,
    moonShadow: moonShadow ?? this.moonShadow,
    today: today ?? this.today,
    track: track ?? this.track,
  );

  @override
  CycleColors lerp(CycleColors? other, double t) {
    if (other == null) return this;
    return CycleColors(
      period: Color.lerp(period, other.period, t)!,
      onPeriod: Color.lerp(onPeriod, other.onPeriod, t)!,
      predicted: Color.lerp(predicted, other.predicted, t)!,
      fertile: Color.lerp(fertile, other.fertile, t)!,
      ovulation: Color.lerp(ovulation, other.ovulation, t)!,
      onOvulation: Color.lerp(onOvulation, other.onOvulation, t)!,
      moon: Color.lerp(moon, other.moon, t)!,
      moonShadow: Color.lerp(moonShadow, other.moonShadow, t)!,
      today: Color.lerp(today, other.today, t)!,
      track: Color.lerp(track, other.track, t)!,
    );
  }
}

/// Day counts are set in Cormorant, the app's one typographic accent; all
/// other text uses the system font.
TextStyle numeralStyle(
  BuildContext context,
  double size, {
  Color? color,
  FontWeight weight = FontWeight.w600,
}) => TextStyle(
  fontFamily: 'Cormorant',
  fontSize: size,
  fontWeight: weight,
  height: 1,
  color: color ?? Theme.of(context).colorScheme.onSurface,
  fontFeatures: const [FontFeature.liningFigures()],
);

abstract final class LunaTheme {
  static ThemeData light() => _build(
    const ColorScheme(
      brightness: Brightness.light,
      primary: LunaPalette.rouge,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFF6DADD),
      onPrimaryContainer: Color(0xFF5A1420),
      secondary: LunaPalette.celadon,
      onSecondary: Colors.white,
      secondaryContainer: LunaPalette.moonWhiteDeep,
      onSecondaryContainer: LunaPalette.ink,
      tertiary: Color(0xFF8A6116),
      onTertiary: Colors.white,
      error: Color(0xFFB3261E),
      onError: Colors.white,
      surface: LunaPalette.moonWhite,
      onSurface: LunaPalette.ink,
      onSurfaceVariant: Color(0xFF5C6477),
      outline: Color(0xFF8C93A3),
      outlineVariant: Color(0xFFD3DCE2),
      surfaceContainerLowest: Colors.white,
      surfaceContainerLow: Color(0xFFEAF2F5),
      surfaceContainer: Color(0xFFE4EEF2),
      surfaceContainerHigh: Color(0xFFDEEAEF),
      surfaceContainerHighest: Color(0xFFD6E5EB),
      inverseSurface: LunaPalette.ink,
      onInverseSurface: LunaPalette.moonWhite,
      inversePrimary: Color(0xFFF2A3AE),
      surfaceTint: Colors.transparent,
    ),
    const CycleColors(
      period: LunaPalette.rouge,
      onPeriod: Colors.white,
      predicted: Color(0xFFE7DBDE), // rouge at 14% on the page
      fertile: Color(0xFFD2E2E5), // celadon at 16% on the page
      ovulation: LunaPalette.celadon,
      onOvulation: Colors.white,
      moon: Color(0xFFEFD48E),
      moonShadow: Color(0x142E3446),
      today: LunaPalette.gamboge,
      track: Color(0x332E3446),
    ),
  );

  static ThemeData dark() => _build(
    const ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFE07A87),
      onPrimary: Color(0xFF3A0B14),
      primaryContainer: Color(0xFF6E2330),
      onPrimaryContainer: Color(0xFFFFD9DE),
      secondary: Color(0xFF6DB8C1),
      onSecondary: Color(0xFF0B2024),
      secondaryContainer: Color(0xFF26303F),
      onSecondaryContainer: LunaPalette.moonWhiteDeep,
      tertiary: Color(0xFFF0C565),
      onTertiary: Color(0xFF2A2006),
      error: Color(0xFFF2B8B5),
      onError: Color(0xFF601410),
      surface: LunaPalette.night,
      onSurface: Color(0xFFE4ECF1),
      onSurfaceVariant: Color(0xFFA7B1BF),
      outline: Color(0xFF6D7788),
      outlineVariant: Color(0xFF2F3746),
      surfaceContainerLowest: Color(0xFF0F121A),
      surfaceContainerLow: Color(0xFF1A1F2A),
      surfaceContainer: Color(0xFF1E2430),
      surfaceContainerHigh: Color(0xFF252C39),
      surfaceContainerHighest: Color(0xFF2D3543),
      inverseSurface: Color(0xFFE4ECF1),
      onInverseSurface: LunaPalette.night,
      inversePrimary: LunaPalette.rouge,
      surfaceTint: Colors.transparent,
    ),
    const CycleColors(
      period: Color(0xFFE07A87),
      onPeriod: Color(0xFF3A0B14),
      predicted: Color(0xFF3E2C37),
      fertile: Color(0xFF25363F),
      ovulation: Color(0xFF6DB8C1),
      onOvulation: Color(0xFF0B2024),
      moon: Color(0xFFF3DFA8),
      moonShadow: Color(0x1AFFFFFF),
      today: Color(0xFFF0C565),
      track: Color(0x40E4ECF1),
    ),
  );

  static ThemeData _build(ColorScheme scheme, CycleColors cycle) {
    final base = ThemeData(colorScheme: scheme, useMaterial3: true);
    final text = base.textTheme;
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      extensions: [cycle],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 68,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 28),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 24),
      ),
    );
  }
}
