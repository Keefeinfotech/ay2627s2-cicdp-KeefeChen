import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../models/chat_message.dart';

/// A single conversation bubble. User messages use Deep Navy, assistant
/// messages use a calm white surface, and failures remain visually distinct.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool isUser = message.isUser;
    final double maxWidth = MediaQuery.sizeOf(context).width >= 840
        ? 620
        : MediaQuery.sizeOf(context).width * 0.8;

    final Color background = isUser
        ? AppColors.deepNavy
        : message.isError
        ? scheme.errorContainer
        : scheme.surface;
    final Color foreground = isUser
        ? AppColors.white
        : message.isError
        ? scheme.onErrorContainer
        : scheme.onSurface;
    final Color border = isUser
        ? AppColors.deepNavy
        : message.isError
        ? scheme.error.withValues(alpha: 0.3)
        : scheme.outlineVariant;

    final Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppRadius.lg),
          topRight: const Radius.circular(AppRadius.lg),
          bottomLeft: Radius.circular(isUser ? AppRadius.lg : AppRadius.xs),
          bottomRight: Radius.circular(isUser ? AppRadius.xs : AppRadius.lg),
        ),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (message.isError) ...<Widget>[
                Icon(
                  Icons.error_outline_rounded,
                  size: AppSizes.iconSm,
                  color: foreground,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
              Text(
                isUser ? 'You' : 'Auxilia',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isUser
                      ? Colors.white.withValues(alpha: 0.7)
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            message.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground,
              height: 1.45,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          if (!isUser) ...<Widget>[
            const AppIconTile(
              icon: Icons.chat_bubble_outline_rounded,
              color: AppColors.deepNavy,
              size: 32,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Flexible(child: bubble),
        ],
      ),
    );
  }
}
