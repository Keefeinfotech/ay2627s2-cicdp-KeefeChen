import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Builds the light and dark Material 3 themes from Auxilia's design tokens.
///
/// Clear Blue is the action colour, Deep Navy is the brand surface, and the
/// rest of the interface stays on white and Soft Grey. Components use small
/// radii, thin borders and no decorative gradients.
abstract final class AppTheme {
  const AppTheme._();

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.clearBlue,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.blueTint,
    onPrimaryContainer: AppColors.deepNavy,
    secondary: AppColors.deepNavy,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.navyTint,
    onSecondaryContainer: AppColors.deepNavy,
    tertiary: AppColors.teal,
    onTertiary: AppColors.white,
    tertiaryContainer: AppColors.tealTint,
    onTertiaryContainer: Color(0xFF0B5F4F),
    error: AppColors.errorRed,
    onError: AppColors.white,
    errorContainer: AppColors.errorTint,
    onErrorContainer: Color(0xFF7F1D1D),
    surface: AppColors.white,
    onSurface: AppColors.darkText,
    onSurfaceVariant: AppColors.mutedText,
    surfaceContainerHighest: Color(0xFFEEF2F6),
    outline: AppColors.borderGrey,
    outlineVariant: Color(0xFFEDF1F5),
    shadow: Color(0x1A243B53),
    scrim: Color(0x66243B53),
    inverseSurface: AppColors.deepNavy,
    onInverseSurface: AppColors.white,
    inversePrimary: Color(0xFFA9C4E0),
    surfaceTint: AppColors.clearBlue,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.darkBlue,
    onPrimary: Color(0xFF08233F),
    primaryContainer: Color(0xFF1D3A5A),
    onPrimaryContainer: Color(0xFFD6E8FF),
    secondary: AppColors.darkPrimary,
    onSecondary: Color(0xFF0E1925),
    secondaryContainer: AppColors.deepNavy,
    onSecondaryContainer: AppColors.darkOnSurface,
    tertiary: AppColors.darkTeal,
    onTertiary: Color(0xFF04241D),
    tertiaryContainer: Color(0xFF0F3E34),
    onTertiaryContainer: Color(0xFFC9F5EA),
    error: Color(0xFFF87171),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFEE2E2),
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkOnSurface,
    onSurfaceVariant: AppColors.darkMuted,
    surfaceContainerHighest: AppColors.darkSurfaceAlt,
    outline: Color(0xFF3A526B),
    outlineVariant: AppColors.darkBorder,
    shadow: Color(0x66000000),
    scrim: Color(0x99000000),
    inverseSurface: AppColors.darkOnSurface,
    onInverseSurface: AppColors.darkCanvas,
    inversePrimary: AppColors.darkPrimary,
    surfaceTint: AppColors.darkBlue,
  );

  static ThemeData light() => _build(_lightScheme, AppColors.softGrey);

  static ThemeData dark() => _build(_darkScheme, AppColors.darkCanvas);

  static ThemeData _build(ColorScheme scheme, Color canvas) {
    final bool isLight = scheme.brightness == Brightness.light;
    final TextTheme textTheme = AppTypography.textTheme(scheme);

    final RoundedRectangleBorder buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final RoundedRectangleBorder fieldShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
    );
    final Color fieldFill = isLight
        ? AppColors.white
        : AppColors.darkSurfaceAlt;
    final Color fieldBorder = isLight
        ? AppColors.borderGrey
        : AppColors.darkBorder;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: AppTypography.fontFamily,
      scaffoldBackgroundColor: canvas,
      canvasColor: scheme.surface,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashColor: scheme.primary.withValues(alpha: 0.07),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
      hoverColor: scheme.primary.withValues(alpha: 0.04),
      focusColor: scheme.primary.withValues(alpha: 0.08),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(
          color: scheme.onSurface,
          size: AppSizes.iconMd,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.bodySmall?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w600,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        errorStyle: textTheme.bodySmall?.copyWith(color: scheme.error),
        counterStyle: textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(color: fieldBorder.withValues(alpha: 0.6)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surface,
        selectedColor: scheme.primary,
        disabledColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(borderRadius: fieldShape.borderRadius),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.35),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.75),
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(0, AppSizes.buttonHeight),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          side: BorderSide(color: scheme.outline),
          shape: buttonShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isLight
              ? AppColors.clearBlueText
              : AppColors.darkBlue,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurfaceVariant,
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        extendedTextStyle: textTheme.labelLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isLight
            ? AppColors.deepNavy
            : AppColors.darkSurfaceAlt,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w500,
        ),
        actionTextColor: isLight ? const Color(0xFF9CC7FF) : AppColors.darkTeal,
        elevation: 2,
        insetPadding: const EdgeInsets.all(AppSpacing.lg),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: scheme.surface,
        elevation: 6,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        side: BorderSide(color: scheme.outline, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll<Color>(scheme.onPrimary),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.outlineVariant,
        circularTrackColor: scheme.outlineVariant,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(AppRadius.xs),
        ),
        textStyle: textTheme.labelSmall?.copyWith(
          color: scheme.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll<Size>(
            Size(0, 44),
          ),
          padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
            EdgeInsets.symmetric(horizontal: AppSpacing.md),
          ),
          textStyle: WidgetStatePropertyAll<TextStyle?>(textTheme.labelMedium),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) return scheme.primary;
            return scheme.surface;
          }),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
            if (states.contains(WidgetState.selected)) return scheme.onPrimary;
            return scheme.onSurfaceVariant;
          }),
          side: WidgetStatePropertyAll<BorderSide>(
            BorderSide(color: scheme.outline),
          ),
          shape: WidgetStatePropertyAll<OutlinedBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: scheme.primary,
              size: AppSizes.iconMd,
            );
          }
          return IconThemeData(
            color: scheme.onSurfaceVariant,
            size: AppSizes.iconMd,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle?>((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelSmall?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w600,
            );
          }
          return textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
        }),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll<double>(8),
        radius: const Radius.circular(AppRadius.sm),
        thumbColor: WidgetStatePropertyAll<Color>(
          scheme.onSurfaceVariant.withValues(alpha: 0.3),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.18),
        selectionHandleColor: scheme.primary,
      ),
    );
  }
}

/// Backwards-compatible theme entry point for existing imports and tests.
abstract final class AuxiliaTheme {
  static ThemeData light() => AppTheme.light();

  static ThemeData dark() => AppTheme.dark();
}

/// Backwards-compatible colour names mapped onto the new palette.
///
/// New code should use [AppColors] directly. This class only exists so older
/// imports keep working while the codebase migrates.
abstract final class AuxiliaColors {
  static const Color indigo = AppColors.deepNavy;
  static const Color indigoDeep = AppColors.navyDeep;
  static const Color cyan = AppColors.clearBlue;
  static const Color cyanDeep = AppColors.clearBlue;
  static const Color violet = AppColors.teal;
  static const Color slate900 = AppColors.darkText;
  static const Color slate700 = AppColors.deepNavy;
  static const Color slate500 = AppColors.mutedText;
  static const Color slate300 = AppColors.borderGrey;
  static const Color slate200 = AppColors.borderGrey;
  static const Color slate100 = AppColors.softGrey;
  static const Color canvas = AppColors.softGrey;
  static const Color success = AppColors.teal;
  static const Color warning = AppColors.warningAmber;
  static const Color danger = AppColors.errorRed;
  static const Color darkCanvas = AppColors.darkCanvas;
  static const Color darkSurface = AppColors.darkSurface;
  static const Color darkSurfaceAlt = AppColors.darkSurfaceAlt;
  static const Color darkBorder = AppColors.darkBorder;
  static const Color darkText = AppColors.darkOnSurface;
  static const Color darkMuted = AppColors.darkMuted;
  static const Color darkPrimary = AppColors.darkPrimary;
  static const Color darkCyan = AppColors.darkBlue;
  static const LinearGradient brandGradient = AppColors.navyGradient;
}
