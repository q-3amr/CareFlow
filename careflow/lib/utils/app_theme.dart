import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_tokens.dart';

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // LIGHT THEME (CareFlow default)
  // ---------------------------------------------------------------------------
  static ThemeData get lightTheme => _build(
        brightness: Brightness.light,
        scheme: _lightScheme,
        scaffold: AppColors.backgroundLight,
      );

  // ---------------------------------------------------------------------------
  // DARK THEME
  // ---------------------------------------------------------------------------
  static ThemeData get darkTheme => _build(
        brightness: Brightness.dark,
        scheme: _darkScheme,
        scaffold: AppColors.backgroundDark,
      );

  static final ColorScheme _lightScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryLight,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: const Color(0xFF475569),
    onSecondary: Colors.white,
    secondaryContainer: AppColors.cardTintLight,
    onSecondaryContainer: AppColors.textPrimaryLight,
    tertiary: AppColors.primary,
    onTertiary: Colors.white,
    error: AppColors.destructive,
    onError: Colors.white,
    errorContainer: AppColors.destructiveLight,
    onErrorContainer: AppColors.destructiveText,
    surface: AppColors.cardLight,
    onSurface: AppColors.textPrimaryLight,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFF9FAFD),
    surfaceContainer: AppColors.backgroundLight,
    surfaceContainerHigh: AppColors.cardTintLight,
    surfaceContainerHighest: const Color(0xFFE6EBF3),
    outline: const Color(0xFFB8C2D3),
    outlineVariant: AppColors.borderLight,
    inverseSurface: AppColors.textPrimaryLight,
    onInverseSurface: AppColors.backgroundLight,
    inversePrimary: const Color(0xFF93B4FF),
    shadow: const Color(0xFF0B1220),
    scrim: const Color(0xFF0B1220),
    surfaceTint: AppColors.primary,
  );

  static final ColorScheme _darkScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryContainerDark,
    onPrimaryContainer: const Color(0xFFBFDBFE),
    secondary: AppColors.textSecondaryDark,
    onSecondary: AppColors.backgroundDark,
    secondaryContainer: AppColors.cardTintDark,
    onSecondaryContainer: AppColors.textPrimaryDark,
    tertiary: AppColors.primaryStrong,
    onTertiary: Colors.white,
    error: const Color(0xFFF97066),
    onError: const Color(0xFF2A0A08),
    errorContainer: AppColors.destructiveSoftDark,
    onErrorContainer: const Color(0xFFFECDCA),
    surface: AppColors.cardDark,
    onSurface: AppColors.textPrimaryDark,
    surfaceContainerLowest: AppColors.backgroundDark,
    surfaceContainerLow: const Color(0xFF101827),
    surfaceContainer: AppColors.cardDark,
    surfaceContainerHigh: AppColors.cardTintDark,
    surfaceContainerHighest: const Color(0xFF222D40),
    outline: const Color(0xFF3B475C),
    outlineVariant: AppColors.borderDark,
    inverseSurface: AppColors.textPrimaryDark,
    onInverseSurface: AppColors.backgroundDark,
    inversePrimary: AppColors.primaryDark,
    shadow: const Color(0xFF000000),
    scrim: const Color(0xFF000000),
    surfaceTint: AppColors.primary,
  );

  static ThemeData _build({
    required Brightness brightness,
    required ColorScheme scheme,
    required Color scaffold,
  }) {
    final isDark = brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final surface = isDark ? AppColors.cardDark : AppColors.cardLight;
    final border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final softFill = isDark ? AppColors.cardTintDark : AppColors.surfaceSunken;

    final textTheme = TextTheme(
      displaySmall: AppTypography.display.copyWith(color: textPrimary),
      headlineSmall: AppTypography.title.copyWith(color: textPrimary),
      titleMedium: AppTypography.section.copyWith(color: textPrimary),
      bodyLarge: AppTypography.body.copyWith(color: textPrimary),
      bodyMedium: AppTypography.body.copyWith(color: textPrimary),
      bodySmall: AppTypography.caption.copyWith(color: textSecondary),
      labelLarge: AppTypography.label.copyWith(color: textPrimary),
      labelMedium: AppTypography.caption.copyWith(
        color: textSecondary,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: AppTypography.caption.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: textSecondary,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      canvasColor: scaffold,
      cardColor: surface,
      dividerColor: divider,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: textPrimary, size: AppIconSize.md),
      primaryIconTheme: const IconThemeData(color: Colors.white),

      // App bar: quiet surface, no shadow, one consistent title scale.
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.lg,
        toolbarHeight: 56,
        titleTextStyle: AppTypography.title.copyWith(color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary, size: AppIconSize.md),
        actionsIconTheme:
            IconThemeData(color: textPrimary, size: AppIconSize.md),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: scaffold,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
      ),

      // Cards default to a hairline border; elevation is opt-in and rare.
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.medium,
          side: BorderSide(color: border),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: 14,
        ),
        hintStyle: AppTypography.body.copyWith(color: textTertiary),
        labelStyle: AppTypography.label.copyWith(color: textSecondary),
        floatingLabelStyle: AppTypography.label.copyWith(color: AppColors.primary),
        errorStyle: AppTypography.caption.copyWith(color: AppColors.destructive),
        helperStyle: AppTypography.caption.copyWith(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        iconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: const BorderSide(color: AppColors.destructive),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide:
              const BorderSide(color: AppColors.destructive, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.medium,
          borderSide: BorderSide(color: border.withValues(alpha: 0.6)),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: softFill,
          disabledForegroundColor: textTertiary,
          minimumSize: const Size(0, AppMetrics.controlHeight),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, AppMetrics.controlHeight),
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
          textStyle: AppTypography.button,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(0, AppMetrics.minTarget),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
          textStyle: AppTypography.label,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
          minimumSize: const Size(
            AppMetrics.minTarget,
            AppMetrics.minTarget,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        extendedTextStyle: AppTypography.button,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: AppTypography.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: AppTypography.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surface,
        disabledColor: softFill,
        selectedColor: AppColors.primaryLight,
        secondarySelectedColor: AppColors.primaryLight,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        labelStyle: AppTypography.label.copyWith(color: textPrimary),
        secondaryLabelStyle:
            AppTypography.label.copyWith(color: AppColors.primaryDark),
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
        showCheckmark: false,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        insetPadding: const EdgeInsets.all(AppSpacing.xl),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        titleTextStyle: AppTypography.section.copyWith(
          fontSize: 16,
          color: textPrimary,
        ),
        contentTextStyle: AppTypography.body.copyWith(color: textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.cardTintDark : AppColors.textPrimaryLight,
        contentTextStyle: AppTypography.body.copyWith(
          fontSize: 13,
          color: isDark ? AppColors.textPrimaryDark : Colors.white,
        ),
        actionTextColor: AppColors.primaryStrong,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
      ),
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        iconColor: textSecondary,
        textColor: textPrimary,
        titleTextStyle: AppTypography.label.copyWith(color: textPrimary),
        subtitleTextStyle: AppTypography.caption.copyWith(color: textSecondary),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.small),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        circularTrackColor: AppColors.primaryLight,
        linearTrackColor: border,
        strokeWidth: 2.5,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.primary
              : border,
        ),
        trackOutlineColor:
            const WidgetStatePropertyAll<Color>(Colors.transparent),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
        textStyle: AppTypography.body.copyWith(color: textPrimary),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardTintDark : AppColors.textPrimaryLight,
          borderRadius: AppRadius.small,
        ),
        textStyle: AppTypography.caption.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.large),
        hourMinuteShape: RoundedRectangleBorder(borderRadius: AppRadius.medium),
      ),
    );
  }
}
