import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_typography.dart';

void main() {
  test('uses the vivid weather-inspired palette', () {
    expect(AppColors.pacific, const Color(0xFF0F7B7B));
    expect(AppColors.moss, const Color(0xFF556B2F));
    expect(AppColors.malachite, const Color(0xFF00C853));
    expect(AppColors.lichen, const Color(0xFFA8C686));
    expect(AppColors.saffron, const Color(0xFFE9C46A));
    expect(AppColors.persimmon, const Color(0xFFE76F51));
    expect(AppColors.blush, const Color(0xFFF4A261));
    expect(AppColors.darkestNavy, const Color(0xFF1A1A2E));
    expect(AppColors.cocoCream, const Color(0xFFFDF5E6));
  });

  test('builds a light theme with Roboto typography', () {
    final theme = AppTheme.light();

    expect(AppTypography.fontFamily, 'Roboto');
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Roboto');
    expect(theme.colorScheme.primary, AppColors.saffron);
    expect(theme.colorScheme.secondary, AppColors.pacific);
    expect(theme.scaffoldBackgroundColor, AppColors.cocoCream);
    expect(theme.cardTheme.elevation, 2);
  });
}
