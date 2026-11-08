import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/core/theme/app_typography.dart';

void main() {
  test('keeps the approved Trust Blue palette', () {
    expect(AppColors.deepNavy, const Color(0xFF1D4ED8));
    expect(AppColors.clearBlue, const Color(0xFF2563EB));
    expect(AppColors.softGrey, const Color(0xFFF8FAFC));
    expect(AppColors.white, const Color(0xFFFFFFFF));
    expect(AppColors.teal, const Color(0xFF16A34A));
    expect(AppColors.darkText, const Color(0xFF0F172A));
    expect(AppColors.mutedText, const Color(0xFF64748B));
    expect(AppColors.borderGrey, const Color(0xFFE2E8F0));
    expect(AppColors.errorRed, const Color(0xFFDC2626));
    expect(AppColors.warningAmber, const Color(0xFFD97706));
  });

  test('builds a flat light theme with Inter typography', () {
    final theme = AppTheme.light();

    expect(AppTypography.fontFamily, 'Inter');
    expect(theme.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(theme.colorScheme.primary, AppColors.clearBlue);
    expect(theme.colorScheme.secondary, AppColors.deepNavy);
    expect(theme.scaffoldBackgroundColor, AppColors.softGrey);
    expect(theme.cardTheme.elevation, 0);
  });
}
