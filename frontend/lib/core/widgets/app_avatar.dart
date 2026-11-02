import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// User avatar with initials and a consistent 48px touch target.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.name,
    this.email,
    this.size = 36,
    this.onDark = false,
    this.onTap,
    this.tooltip = 'Account',
  });

  final String? name;
  final String? email;
  final double size;
  final bool onDark;
  final VoidCallback? onTap;
  final String tooltip;

  String get _initials {
    final String source = (name?.trim().isNotEmpty ?? false)
        ? name!.trim()
        : (email?.trim() ?? '');
    if (source.isEmpty) return '';

    final parts = source
        .split(RegExp(r'[\s@._-]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return source.characters.first.toUpperCase();
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color background = onDark
        ? Colors.white.withValues(alpha: 0.16)
        : scheme.primary;
    final Color foreground = onDark ? Colors.white : scheme.onPrimary;
    final String initials = _initials;

    final Widget avatar = CircleAvatar(
      radius: size / 2,
      backgroundColor: background,
      child: initials.isEmpty
          ? Icon(
              Icons.person_outline_rounded,
              size: size * 0.5,
              color: foreground,
            )
          : Text(
              initials,
              style: TextStyle(
                color: foreground,
                fontSize: size * 0.34,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
    );

    final Widget wrapped = SizedBox(
      width: AppSizes.touchTarget,
      height: AppSizes.touchTarget,
      child: Center(
        child: Container(
          decoration: onDark
              ? BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                )
              : null,
          child: avatar,
        ),
      ),
    );

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: onTap != null,
        label: tooltip,
        child: onTap == null
            ? wrapped
            : InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: wrapped,
              ),
      ),
    );
  }
}

/// A small brand-consistent tile used for logos and feature icons.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 48, this.onDark = false});

  final double size;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color background = onDark ? Colors.white : AppColors.deepNavy;
    final Color foreground = onDark ? AppColors.deepNavy : Colors.white;

    return Semantics(
      label: 'Auxilia',
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(size * 0.24),
        ),
        child: Text(
          'A',
          style: theme.textTheme.titleLarge?.copyWith(
            color: foreground,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );
  }
}

/// Brand mark plus the Auxilia wordmark.
class BrandLockup extends StatelessWidget {
  const BrandLockup({
    super.key,
    this.onDark = false,
    this.markSize = 52,
    this.showTagline = false,
    this.alignment = CrossAxisAlignment.start,
  });

  final bool onDark;
  final double markSize;
  final bool showTagline;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color titleColor = onDark
        ? Colors.white
        : theme.colorScheme.onSurface;
    final Color muted = onDark
        ? Colors.white.withValues(alpha: 0.72)
        : theme.colorScheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        BrandMark(size: markSize, onDark: onDark),
        const SizedBox(width: AppSpacing.md),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: alignment,
          children: <Widget>[
            Text(
              'Auxilia',
              style: theme.textTheme.titleLarge?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            if (showTagline) ...<Widget>[
              const SizedBox(height: AppSpacing.xxs),
              Text(
                AppConstants.tagline,
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
