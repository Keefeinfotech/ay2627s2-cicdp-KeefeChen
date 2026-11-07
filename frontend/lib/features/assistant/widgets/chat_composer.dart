import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_text_field.dart';

/// Bottom message composer for the AI assistant.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.focusNode,
    this.enabled = true,
    this.isSending = false,
    this.onVoice,
    this.isListening = false,
    this.hintText = 'Type a message...',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final FocusNode? focusNode;
  final bool enabled;
  final bool isSending;
  final VoidCallback? onVoice;
  final bool isListening;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool canSend = enabled && !isSending;

    return Material(
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppSizes.maxChatWidth,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: AppTextField(
                      controller: controller,
                      focusNode: focusNode,
                      enabled: enabled,
                      useFormField: false,
                      hintText: hintText,
                      textInputAction: TextInputAction.send,
                      onFieldSubmitted: (_) {
                        if (canSend) onSend();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (onVoice != null)
                    SizedBox(
                      width: AppSizes.touchTarget,
                      height: AppSizes.touchTarget,
                      child: IconButton(
                        tooltip: isListening
                            ? 'Stop voice input'
                            : 'Start voice input',
                        onPressed: canSend ? onVoice : null,
                        style: IconButton.styleFrom(
                          backgroundColor: isListening
                              ? scheme.errorContainer
                              : scheme.surfaceContainerHighest,
                          foregroundColor: isListening
                              ? scheme.onErrorContainer
                              : scheme.onSurface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        icon: Icon(
                          isListening
                              ? Icons.stop_rounded
                              : Icons.mic_none_rounded,
                        ),
                      ),
                    ),
                  if (onVoice != null) const SizedBox(width: AppSpacing.xs),
                  SizedBox(
                    width: AppSizes.touchTarget,
                    height: AppSizes.touchTarget,
                    child: IconButton.filled(
                      tooltip: 'Send message',
                      onPressed: canSend ? onSend : null,
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
                        disabledBackgroundColor: scheme.surfaceContainerHighest,
                        disabledForegroundColor: scheme.onSurfaceVariant,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                      ),
                      icon: isSending
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: scheme.onPrimary,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
