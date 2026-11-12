import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_avatar.dart';

/// Shared authentication layout following the Auxilia wireframe: a dark top
/// app bar with a back arrow and centred title, a centred circular brand
/// avatar, the supporting subtitle, then the stacked form content and the
/// footer prompt with a link.
///
/// Screens supply their own constrained form column via [child] and the
/// footer via [footer], so the chrome stays identical across sign in, sign
/// up and the password reset flow.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.showBack,
  });

  /// Centred title shown in the dark top app bar.
  final String title;

  /// Supporting line rendered beneath the brand avatar.
  final String subtitle;

  /// The form contents: stacked fields plus the primary and secondary
  /// full-width buttons.
  final Widget child;

  /// Optional prompt with a link shown after the form.
  final Widget? footer;

  /// Overrides whether the back arrow appears. Defaults to whether the
  /// current route can pop.
  final bool? showBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool canPop = showBack ?? (ModalRoute.of(context)?.canPop ?? false);

    return Scaffold(
      backgroundColor: AppColors.cocoCream,
      appBar: AppBar(
        backgroundColor: AppColors.saffron,
        foregroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        leading: canPop
            ? IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            : null,
        // Large system text can push the title past the bar; clamp it so the
        // bar keeps a single, legible centred line.
        title: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.xxl + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.maxFormWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  const ClipOval(child: BrandMark(size: 72)),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  child,
                  if (footer != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    Center(child: footer),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
