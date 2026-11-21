import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_typography.dart';

void main() {
  test('uses the Trust Blue palette', () {
    expect(AppColors.pacific, const Color(0xFF2563EB));
    expect(AppColors.moss, const Color(0xFF475569));
    expect(AppColors.malachite, const Color(0xFF059669));
    expect(AppColors.lichen, const Color(0xFFDBEAFE));
    expect(AppColors.saffron, const Color(0xFF1D4ED8));
    expect(AppColors.persimmon, const Color(0xFFDC2626));
    expect(AppColors.blush, const Color(0xFF64748B));
    expect(AppColors.darkestNavy, const Color(0xFF0F172A));
    expect(AppColors.cocoCream, const Color(0xFFF1F5F9));
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
