import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_app_bar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../authentication/data/session_store.dart';
import '../data/assistant_service.dart';
import '../models/chat_message.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/chat_composer.dart';

/// Conversation UI for the Auxilia AI assistant.
///
/// The screen owns presentation and conversation state only. The HTTP contract
/// lives in [AssistantService] and remains `{ message }` -> `{ reply }`.
class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key, this.session, this.api});

  final Session? session;
  final ApiClient? api;

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final FocusNode _composerFocus = FocusNode();
  final List<ChatMessage> _messages = <ChatMessage>[];
  late final AssistantService _service = AssistantService(api: widget.api);
  bool _loading = false;

  Session? get _session => widget.session;

  Future<void> _send() async {
    final text = _controller.text.trim();
    final session = _session;
    if (text.isEmpty || session == null || _loading) return;

    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: text));
      _loading = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final reply = await _service.sendMessage(
        token: session.token,
        message: text,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: ChatRole.assistant, text: reply));
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            role: ChatRole.assistant,
            text: err.isUnauthorized
                ? 'Your session has expired. Please sign in again.'
                : err.message,
            isError: true,
          ),
        );
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          const ChatMessage(
            role: ChatRole.assistant,
            text: 'Something went wrong. Please try again.',
            isError: true,
          ),
        );
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _useSuggestion(String prompt) {
    _controller.text = prompt;
    _controller.selection = TextSelection.collapsed(offset: prompt.length);
    _composerFocus.requestFocus();
  }

  void _clearConversation() {
    setState(_messages.clear);
  }

  void _openLogin() {
    Navigator.pushNamed(context, AppRoutes.login);
  }

  void _continueOffline() {
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.home,
      arguments: const HomeArgs(ownerId: AppConstants.guestOwnerId),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return Scaffold(
      appBar: AuxiliaAppBar(
        title: 'Auxilia Assistant',
        subtitle: session == null
            ? 'Sign in to start a conversation'
            : 'Study help, on demand',
        actions: <Widget>[
          if (session != null && _messages.isNotEmpty)
            IconButton(
              tooltip: 'New conversation',
              onPressed: _loading ? null : _clearConversation,
              icon: const Icon(Icons.add_comment_outlined),
            ),
        ],
      ),
      body: session == null
          ? _SignInRequired(
              onSignIn: _openLogin,
              onContinueOffline: _continueOffline,
            )
          : Column(
              children: <Widget>[
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: AppSizes.maxChatWidth,
                      ),
                      child: _messages.isEmpty
                          ? _EmptyConversation(onSuggestion: _useSuggestion)
                          : ListView.builder(
                              controller: _scroll,
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                AppSpacing.xl,
                                AppSpacing.lg,
                                AppSpacing.sm,
                              ),
                              itemCount: _messages.length,
                              itemBuilder: (context, index) {
                                return ChatBubble(message: _messages[index]);
                              },
                            ),
                    ),
                  ),
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                ChatComposer(
                  controller: _controller,
                  focusNode: _composerFocus,
                  onSend: _send,
                  isSending: _loading,
                ),
              ],
            ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight > AppSpacing.xxl
                  ? constraints.maxHeight - AppSpacing.xxl
                  : 0,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const AppIconTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    color: AppColors.deepNavy,
                    size: 56,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Ask me anything',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Text(
                      'Get help breaking down an assignment, planning revision, '
                      'or understanding a topic. Your conversation is sent to '
                      'the Auxilia server only when you send a message.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _SuggestionPanel(
                      onSuggestion: onSuggestion,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionPanel extends StatelessWidget {
  const _SuggestionPanel({required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          _SuggestionTile(
            icon: Icons.event_note_outlined,
            label: 'Plan my week',
            onTap: () => onSuggestion(
              'Help me plan my study week around my upcoming deadlines.',
            ),
          ),
          const Divider(height: 1),
          _SuggestionTile(
            icon: Icons.account_tree_outlined,
            label: 'Break down an assignment',
            onTap: () => onSuggestion(
              'Help me break a large assignment into manageable steps.',
            ),
          ),
          const Divider(height: 1),
          _SuggestionTile(
            icon: Icons.school_outlined,
            label: 'Explain a concept',
            onTap: () => onSuggestion(
              'Explain a concept from my course in simple terms.',
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, size: AppSizes.iconMd, color: scheme.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Icon(
              Icons.chevron_right_rounded,
              size: AppSizes.iconMd,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInRequired extends StatelessWidget {
  const _SignInRequired({
    required this.onSignIn,
    required this.onContinueOffline,
  });

  final VoidCallback onSignIn;
  final VoidCallback onContinueOffline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.maxFormWidth),
          child: AppCard(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Center(
                  child: AppIconTile(
                    icon: Icons.lock_outline_rounded,
                    color: AppColors.deepNavy,
                    size: 56,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Sign in to use the assistant',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'The assistant sends messages to the Auxilia server, so it '
                  'needs an authenticated session. Your tasks stay on this '
                  'device.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Sign in',
                  icon: Icons.login_rounded,
                  onPressed: onSignIn,
                  expand: true,
                  size: AppButtonSize.large,
                ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Continue offline',
                  icon: Icons.dashboard_outlined,
                  onPressed: onContinueOffline,
                  variant: AppButtonVariant.ghost,
                  expand: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
