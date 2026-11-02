import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';

/// Shared layout for sign-in and registration.
///
/// Mobile devices get a single, keyboard-safe column with no decorative card
/// around the form. Wide screens add a solid Deep Navy brand panel beside the
/// form. There are no gradients, glows or floating shapes.
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

  /// When null, a back button appears only if the route can be popped.
  final bool? showBack;

  @override
  Widget build(BuildContext context) {
    final bool canPop = showBack ?? (ModalRoute.of(context)?.canPop ?? false);
    final Widget form = _AuthForm(
      title: title,
      subtitle: subtitle,
      canPop: canPop,
      footer: footer,
      child: child,
    );

    return Scaffold(
      backgroundColor: AppColors.softGrey,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  const Expanded(flex: 5, child: _AuthBrandPanel()),
                  Expanded(
                    flex: 6,
                    child: ColoredBox(
                      color: AppColors.white,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(AppSpacing.xxxl),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: AppSizes.maxFormWidth,
                            ),
                            child: form,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl,
                canPop ? AppSpacing.xs : AppSpacing.xl,
                AppSpacing.xl,
                AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSizes.maxFormWidth,
                  ),
                  child: form,
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (canPop)
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const Spacer(),
              const BrandLockup(markSize: 28),
            ],
          )
        else
          const BrandLockup(markSize: 36),
        const SizedBox(height: AppSpacing.xxl),
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        child,
        if (footer != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xl),
          footer!,
        ],
        const SizedBox(height: AppSpacing.xxl),
        Text(
          AppConstants.tagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ColoredBox(
      color: AppColors.deepNavy,
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
            const _FeatureLine(
              icon: Icons.event_outlined,
              label: 'Keep your week and reminders in view',
            ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: AppSizes.iconMd, color: AppColors.white),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.white.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
