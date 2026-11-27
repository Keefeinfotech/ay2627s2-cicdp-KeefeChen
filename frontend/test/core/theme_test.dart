import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/design_system/ds_tokens.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_typography.dart';

void main() {
  test('uses the Trust Blue palette', () {
    expect(AppColors.pacific, Ds.trustBlue);
    expect(AppColors.moss, Ds.textSecondary);
    expect(AppColors.malachite, Ds.accentGreen);
    expect(AppColors.lichen, Ds.trustBlueLight);
    expect(AppColors.saffron, Ds.trustBlue);
    expect(AppColors.persimmon, Ds.dangerRed);
    expect(AppColors.blush, Ds.textSecondary);
    expect(AppColors.darkestNavy, Ds.textPrimary);
    expect(AppColors.cocoCream, Ds.bgPage);
  });

  test('builds a light theme with Roboto typography and Trust Blue', () {
    final theme = AppTheme.light();

    expect(AppTypography.fontFamily, 'Roboto');
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Roboto');
    expect(theme.colorScheme.primary, AppColors.saffron);
    expect(theme.colorScheme.secondary, AppColors.pacific);
    expect(theme.scaffoldBackgroundColor, AppColors.cocoCream);
    expect(theme.cardTheme.elevation, 0);
  });
}
