import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runner_flutter/app_colors.dart';
import 'package:runner_flutter/design/app_design.dart';

void main() {
  group('Moneyfy design tokens', () {
    test('uses the Moneyfy brand palette', () {
      expect(AppColors.primary, const Color(0xFF3A6DFF));
      expect(AppColors.primaryDark, const Color(0xFF2DA4FF));
      expect(AppColors.accent, const Color(0xFF00D47E));
      expect(AppColors.warning, const Color(0xFFFFB800));
      expect(AppColors.destructive, const Color(0xFFFF4554));
      expect(AppColors.background, Colors.white);
      expect(AppColors.surfaceSoft, const Color(0xFFF7F7F7));
      expect(AppColors.border, const Color(0xFFDEE1E6));
      expect(AppColors.text, const Color(0xFF0A0B0D));
      expect(AppColors.secondaryText, const Color(0xFF5B616E));
    });

    test('uses Moneyfy spacing, radius, and typography scale', () {
      expect(AppSpacing.page, const EdgeInsets.fromLTRB(16, 24, 16, 24));
      expect(
        AppSpacing.pageWithBottomNav,
        const EdgeInsets.fromLTRB(16, 24, 16, 132),
      );
      expect(AppSpacing.card, const EdgeInsets.all(20));
      expect(AppSpacing.cardDense, const EdgeInsets.all(12));
      expect(AppRadii.control, 100);
      expect(AppRadii.card, 16);
      expect(AppRadii.sheet, 24);
      expect(AppTextStyles.sectionTitle.fontSize, 18);
      expect(AppTextStyles.sectionTitle.fontWeight, FontWeight.w600);
      expect(AppTextStyles.label.fontSize, 14);
      expect(AppTextStyles.metric.fontSize, 36);
      expect(AppTextStyles.metric.fontWeight, FontWeight.w500);
    });
  });
}
