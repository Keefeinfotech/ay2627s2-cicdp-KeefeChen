import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_typography.dart';

void main() {
  test('uses the Urban Slate palette', () {
    expect(AppColors.pacific, const Color(0xFF6B7C98));
    expect(AppColors.moss, const Color(0xFF7B7F8A));
    expect(AppColors.malachite, const Color(0xFF16A34A));
    expect(AppColors.lichen, const Color(0xFFDFE3EB));
    expect(AppColors.saffron, const Color(0xFF5E5653));
    expect(AppColors.persimmon, const Color(0xFFDC2626));
    expect(AppColors.blush, const Color(0xFFAB978C));
    expect(AppColors.darkestNavy, const Color(0xFF2B2724));
    expect(AppColors.cocoCream, const Color(0xFFE9E6E7));
  });

  test('builds a light theme with Inter typography and Urban Slate', () {
    final theme = AppTheme.light();

    expect(AppTypography.fontFamily, 'Inter');
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.colorScheme.primary, AppColors.saffron);
    expect(theme.colorScheme.secondary, AppColors.pacific);
    expect(theme.scaffoldBackgroundColor, AppColors.cocoCream);
    expect(theme.cardTheme.elevation, 2);
  });
}
