import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'package:frontend/core/widgets/app_avatar.dart';
import 'package:frontend/core/widgets/app_button.dart';
import '../data/onboarding_store.dart';

/// A short, product-led introduction shown once before authentication.
///
/// The four pages describe capabilities that exist in the application today:
/// task planning, scheduling, the assistant, and progress tracking. Completion
/// and skipping are both persisted so the flow does not reappear on launch.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.store, this.onComplete});

  final OnboardingStore? store;

  /// Used by tests and by callers that want to route the completion themselves.
  /// When omitted, the screen replaces itself with the login route.
  final VoidCallback? onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingStore _store = widget.store ?? OnboardingStore();
  late final PageController _controller = PageController();
  int _index = 0;
  bool _finishing = false;

  static const int _pageCount = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);

    try {
      await _store.complete();
    } catch (_) {
      // Navigation should not be blocked if local preferences are unavailable.
    }

    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  void _next() {
    if (_index >= _pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isLast = _index == _pageCount - 1;
    final List<_OnboardingPageData> pages = <_OnboardingPageData>[
      const _OnboardingPageData(
        eyebrow: 'Stay organised',
        title: 'Your responsibilities, organised.',
        body:
            'Manage tasks, organise schedules and keep track of your '
            'responsibilities with one personal assistant.',
        preview: _TaskPreview(),
      ),
      const _OnboardingPageData(
        eyebrow: 'Plan your time',
        title: 'Make every deadline feel manageable.',
        body:
            'Add due dates and reminders, then focus on what needs your '
            'attention today.',
        preview: _SchedulePreview(),
      ),
      const _OnboardingPageData(
        eyebrow: 'Work smarter',
        title: 'Get help when you need it.',
        body:
            'Use the assistant to break down assignments, plan revision and '
            'think through problems in plain language.',
        preview: _AssistantPreview(),
      ),
      const _OnboardingPageData(
        eyebrow: 'Build momentum',
        title: 'See your progress add up.',
        body:
            'Track completed work, XP and achievements as you move through '
            'the week.',
        preview: _ProgressPreview(),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.softGrey,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Row(
                children: <Widget>[
                  const BrandMark(size: 32),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          AppConstants.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          AppConstants.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    TextButton(
                      onPressed: _finishing ? null : _finish,
                      child: const Text('Skip'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  return _OnboardingPage(data: pages[index]);
                },
              ),
            ),
            _OnboardingControls(
              pageCount: _pageCount,
              currentIndex: _index,
              isLast: isLast,
              finishing: _finishing,
              onPrevious: _index == 0 ? null : _previous,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.preview,
  });

  final String eyebrow;
  final String title;
  final String body;
  final Widget preview;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            data.eyebrow.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.clearBlueText,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.title,
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            data.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          data.preview,
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

class _OnboardingControls extends StatelessWidget {
  const _OnboardingControls({
    required this.pageCount,
    required this.currentIndex,
    required this.isLast,
    required this.finishing,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageCount;
  final int currentIndex;
  final bool isLast;
  final bool finishing;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Semantics(
            label: 'Page ${currentIndex + 1} of $pageCount',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                for (var index = 0; index < pageCount; index++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    width: index == currentIndex ? 20 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: index == currentIndex
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              if (onPrevious != null) ...[
                Expanded(
                  child: AppButton(
                    label: 'Previous',
                    onPressed: finishing ? null : onPrevious,
                    variant: AppButtonVariant.outline,
                    size: AppButtonSize.large,
                    expand: true,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                flex: onPrevious == null ? 1 : 2,
                child: AppButton(
                  label: isLast ? 'Get Started' : 'Continue',
                  onPressed: finishing ? null : onNext,
                  size: AppButtonSize.large,
                  expand: true,
                  isLoading: finishing,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shared chrome for the restrained, product-focused previews.
class _PreviewShell extends StatelessWidget {
  const _PreviewShell({
    required this.label,
    required this.meta,
    required this.child,
  });

  final String label;
  final String meta;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    meta,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskPreview extends StatelessWidget {
  const _TaskPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _PreviewShell(
      label: 'This week',
      meta: '3 tasks',
      child: Column(
        children: <Widget>[
          const _PreviewTaskRow(
            title: 'Finish research summary',
            meta: 'Due today',
            accent: AppColors.warningAmber,
          ),
          Divider(height: 20, color: theme.colorScheme.outlineVariant),
          const _PreviewTaskRow(
            title: 'Read chapter 4',
            meta: 'Tomorrow',
            accent: AppColors.clearBlue,
          ),
          Divider(height: 20, color: theme.colorScheme.outlineVariant),
          const _PreviewTaskRow(
            title: 'Submit lab report',
            meta: 'Completed',
            accent: AppColors.teal,
            checked: true,
          ),
        ],
      ),
    );
  }
}

class _PreviewTaskRow extends StatelessWidget {
  const _PreviewTaskRow({
    required this.title,
    required this.meta,
    required this.accent,
    this.checked = false,
  });

  final String title;
  final String meta;
  final Color accent;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;

    return Row(
      children: <Widget>[
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: checked ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: checked ? accent : theme.colorScheme.outline,
            ),
          ),
          child: checked
              ? const Icon(Icons.check_rounded, size: 13, color: Colors.white)
              : null,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: checked ? muted : theme.colorScheme.onSurface,
                  decoration: checked ? TextDecoration.lineThrough : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                meta,
                style: theme.textTheme.labelSmall?.copyWith(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

class _SchedulePreview extends StatelessWidget {
  const _SchedulePreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;

    return _PreviewShell(
      label: 'Today',
      meta: 'Week 8',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (final day in <String>['M', 'T', 'W', 'T', 'F'])
                Expanded(
                  child: Column(
                    children: <Widget>[
                      Text(
                        day,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: day == 'W'
                              ? AppColors.clearBlue
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          day == 'M'
                              ? '12'
                              : day == 'T'
                              ? '13'
                              : day == 'W'
                              ? '14'
                              : day == 'T'
                              ? '15'
                              : '16',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: day == 'W' ? Colors.white : muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _ScheduleRow(
            time: '09:00',
            title: 'Data structures',
            color: AppColors.clearBlue,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ScheduleRow(
            time: '13:00',
            title: 'Assignment work',
            color: AppColors.teal,
          ),
          const SizedBox(height: AppSpacing.sm),
          const _ScheduleRow(
            time: '16:30',
            title: 'Revision block',
            color: AppColors.warningAmber,
          ),
        ],
      ),
    );
  }
}

class _ScheduleRow extends StatelessWidget {
  const _ScheduleRow({
    required this.time,
    required this.title,
    required this.color,
  });

  final String time;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        SizedBox(
          width: 38,
          child: Text(
            time,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          width: 3,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _AssistantPreview extends StatelessWidget {
  const _AssistantPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _PreviewShell(
      label: 'Assistant',
      meta: 'Study help',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.deepNavy,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Text(
                'Help me plan my week.',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.deepNavy,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  'A',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.softGrey,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    'Start with the two deadlines this week, then block two '
                    'study sessions.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Ask the assistant',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_upward_rounded,
                  size: 16,
                  color: AppColors.clearBlue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressPreview extends StatelessWidget {
  const _ProgressPreview();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _PreviewShell(
      label: 'Progress',
      meta: 'This week',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Level 3',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '180 / 300 XP',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: const LinearProgressIndicator(
              value: 0.6,
              minHeight: 6,
              color: AppColors.teal,
              backgroundColor: AppColors.borderGrey,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _ProgressRow(
            icon: Icons.check_circle_outline_rounded,
            title: 'First step',
            meta: 'Unlocked',
            color: AppColors.teal,
          ),
          Divider(height: 20, color: theme.colorScheme.outlineVariant),
          const _ProgressRow(
            icon: Icons.emoji_events_outlined,
            title: 'Week warrior',
            meta: '3 of 5',
            color: AppColors.warningAmber,
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.icon,
    required this.title,
    required this.meta,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String meta;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(meta, style: theme.textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}
