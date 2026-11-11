import 'package:flutter/material.dart';
import 'package:frontend/core/constants/app_constants.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_video_background.dart';

/// Desktop/Web layout with split form (left) and brand panel (right).
/// Mobile devices collapse down to a single scrollable form.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showBack,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final bool? showBack;

  @override
  Widget build(BuildContext context) {
    final bool canPop = showBack ?? (ModalRoute.of(context)?.canPop ?? false);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 900;

            if (isWide) {
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: <Widget>[
                    // Left Form Panel
                    Expanded(
                      flex: 5,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xxl,
                            vertical: AppSpacing.xl,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 380),
                            child: _AuthForm(
                              title: title,
                              subtitle: subtitle,
                              canPop: canPop,
                              footer: footer,
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Right Graphic/Video Panel
                    const Expanded(
                      flex: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(28)),
                        child: _AuthBrandPanel(),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Mobile view (Single column centered form)
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                canPop ? AppSpacing.xs : AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: _AuthForm(
                    title: title,
                    subtitle: subtitle,
                    canPop: canPop,
                    footer: footer,
                    child: child,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AuthForm extends StatelessWidget {
  const _AuthForm({
    required this.title,
    required this.subtitle,
    required this.canPop,
    required this.child,
    this.footer,
  });

  final String title;
  final String subtitle;
  final bool canPop;
  final Widget child;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (canPop)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded),
            ),
          ),
        const BrandLockup(markSize: 28),
        const SizedBox(height: AppSpacing.xxxl),
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: AppSpacing.xxl),
        child,
        if (footer != null) ...[const SizedBox(height: AppSpacing.xl), footer!],
      ],
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppVideoBackground(
      assetPath: 'assets/videos/auth_bg.mp4',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const BrandLockup(onDark: true, markSize: 52, showTagline: true),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'A clear place for your responsibilities.',
              style: theme.textTheme.headlineLarge?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              AppConstants.shortDescription,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: AppColors.white.withValues(alpha: 0.74),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _FeatureLine(
              icon: Icons.checklist_rounded,
              label: 'Plan tasks, deadlines and priorities',
            ),
            const SizedBox(height: AppSpacing.md),
            const _FeatureLine(
              icon: Icons.event_outlined,
              label: 'Keep your week and reminders in view',
            ),
            const SizedBox(height: AppSpacing.md),
            const _FeatureLine(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Get help from the assistant when needed',
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureLine extends StatelessWidget {
  const _FeatureLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: AppColors.white, size: 20),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.white, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
