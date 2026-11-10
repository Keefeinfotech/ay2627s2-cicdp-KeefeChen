import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

import 'package:frontend/core/widgets/app_avatar.dart';
import 'package:frontend/core/widgets/app_button.dart';

import '../data/onboarding_store.dart';

/// A dynamic, interactive onboarding tutorial that simulates mouse clicks and
/// taps to show the Auxilia app in action.
///
/// Each page presents a realistic mock of a core screen — tasks, schedule, and
/// AI assistant — with tappable elements that animate when interacted with.
/// The vivid weather-inspired palette (saffron, pacific teal, moss, malachite,
/// lichen, persimmon, blush, coco cream, darkest navy) makes the app feel
/// alive like sitting in a cosy cafe on a rainy day.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.store, this.onComplete});

  final OnboardingStore? store;

  /// Used by tests and by callers that want to route the completion themselves.
  /// When omitted, the screen replaces itself with the login route.
  final VoidCallback? onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late final OnboardingStore _store = widget.store ?? OnboardingStore();
  late final PageController _controller = PageController();
  int _index = 0;
  bool _finishing = false;
  String? _finishError;

  /// Drives the click/tap animation on interactive preview elements.
  late final AnimationController _clickController;

  static const int _pageCount = 4;

  @override
  void initState() {
    super.initState();
    _clickController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _clickController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() {
      _finishing = true;
      _finishError = null;
    });

    try {
      await _store.complete();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _finishing = false;
        _finishError = 'Could not save your progress. Check your device storage and try again.';
      });
      return;
    }

    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }

    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }

  void _next() {
    if (_index >= _pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _previous() {
    if (_index == 0) return;
    _controller.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _triggerClick() {
    _clickController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bool isLast = _index == _pageCount - 1;
    final List<_OnboardingPageData> pages = <_OnboardingPageData>[
      _OnboardingPageData(
        eyebrow: 'Organise your work',
        title: 'Everything you need, in one place.',
        body: 'Tap a task to mark it complete — your next step stays clear.',
        preview: _TaskDemo(onTap: _triggerClick),
      ),
      _OnboardingPageData(
        eyebrow: 'Stay ahead of deadlines',
        title: 'Keep important dates in view.',
        body: 'Tap a day to see its schedule and track your progress.',
        preview: _ScheduleDemo(onTap: _triggerClick),
      ),
      _OnboardingPageData(
        eyebrow: 'Your personal assistant',
        title: 'Turn ideas into clear next steps.',
        body: 'Tap the assistant to plan your week.',
        preview: _AssistantDemo(onTap: _triggerClick),
      ),
      const _OnboardingPageData(
        eyebrow: 'Collaborate with others',
        title: 'Stay in sync with the people who matter.',
        body:
            'Create groups, share tasks and track progress together so '
            'nothing falls through the cracks.',
        preview: _CollaborationPreview(),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.cocoCream,
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
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          AppConstants.tagline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
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
              errorMessage: _finishError,
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
  _OnboardingPageData({
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
    final scheme = theme.colorScheme;

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
              color: AppColors.pacific,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.title,
            style: theme.textTheme.headlineLarge?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            data.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
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
    required this.errorMessage,
    required this.onPrevious,
    required this.onNext,
  });

  final int pageCount;
  final int currentIndex;
  final bool isLast;
  final bool finishing;
  final String? errorMessage;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
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
          if (errorMessage != null) ...<Widget>[
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.error,
                  ),
                ),
              ),
            ),
          ],
          Semantics(
            label: 'Tutorial step ${currentIndex + 1} of $pageCount',
            liveRegion: true,
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
                          ? AppColors.saffron
                          : scheme.outline,
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
                    label: 'Back',
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
                  label: isLast ? 'Get Started' : 'Next',
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

/// A tappable element that shows a click animation (scale down then back up)
/// with a ripple, simulating a mouse click or tap.
class _Clickable extends StatefulWidget {
  const _Clickable({
    required this.child,
    required this.onTap,
    this.accentColor = AppColors.saffron,
  });

  final Widget child;
  final VoidCallback onTap;
  final Color accentColor;

  @override
  State<_Clickable> createState() => _ClickableState();
}

class _ClickableState extends State<_Clickable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTap() {
    _scaleController.forward().then((_) => _scaleController.reverse());
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Weather-inspired accent colours used across the interactive demos.
class _DemoWeather {
  static const Color pacific = AppColors.pacific; // teal — ocean
  static const Color moss = AppColors.moss; // earthy green — forest
  static const Color malachite =
      AppColors.malachite; // vivid green — new growth
  static const Color persimmon =
      AppColors.persimmon; // warm orange-red — sunset
  static const Color saffron = AppColors.saffron; // golden yellow — sunlight
  static const Color lichen = AppColors.lichen; // soft pale green — mist
  static const Color darkestNavy = AppColors.darkestNavy; // deep night
}

/// ---------------------------------------------------------------------------
/// Page 1: Task management demo
/// ---------------------------------------------------------------------------

class _TaskDemo extends StatefulWidget {
  const _TaskDemo({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_TaskDemo> createState() => _TaskDemoState();
}

class _TaskDemoState extends State<_TaskDemo> {
  int _tappedTask = -1;

  void _onTaskTapped(int index) {
    setState(() => _tappedTask = index);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return _PreviewShell(
      label: 'This week',
      meta: '3 tasks',
      child: Column(
        children: <Widget>[
          _DemoTaskRow(
            title: 'Finish research summary',
            meta: 'Due today',
            accent: _DemoWeather.persimmon,
            checked: _tappedTask == 0,
            onTap: () => _onTaskTapped(0),
          ),
          Divider(height: 20, color: scheme.outlineVariant),
          _DemoTaskRow(
            title: 'Read chapter 4',
            meta: 'Tomorrow',
            accent: _DemoWeather.pacific,
            checked: _tappedTask == 1,
            onTap: () => _onTaskTapped(1),
          ),
          Divider(height: 20, color: scheme.outlineVariant),
          _DemoTaskRow(
            title: 'Submit lab report',
            meta: 'Completed',
            accent: _DemoWeather.malachite,
            checked: true,
            onTap: () => _onTaskTapped(2),
          ),
        ],
      ),
    );
  }
}

class _DemoTaskRow extends StatelessWidget {
  const _DemoTaskRow({
    required this.title,
    required this.meta,
    required this.accent,
    required this.checked,
    required this.onTap,
  });

  final String title;
  final String meta;
  final Color accent;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    return _Clickable(
      accentColor: accent,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: checked ? accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: checked ? accent : scheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: checked ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.xs),
                border: Border.all(color: checked ? accent : scheme.outline),
              ),
              child: checked
                  ? const Icon(
                      Icons.check_rounded,
                      size: 13,
                      color: Colors.white,
                    )
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
                      color: checked
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
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
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Page 2: Schedule demo
/// ---------------------------------------------------------------------------

class _ScheduleDemo extends StatefulWidget {
  const _ScheduleDemo({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_ScheduleDemo> createState() => _ScheduleDemoState();
}

class _ScheduleDemoState extends State<_ScheduleDemo> {
  int _selectedDay = 2; // Wednesday selected by default

  final List<String> _days = <String>['M', 'T', 'W', 'T', 'F'];
  final List<int> _dates = <int>[12, 13, 14, 15, 16];

  void _onDayTapped(int index) {
    setState(() => _selectedDay = index);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    return _PreviewShell(
      label: 'Today',
      meta: 'Week 8',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              for (var index = 0; index < _days.length; index++) ...[
                Expanded(
                  child: _DemoDayChip(
                    day: _days[index],
                    date: _dates[index],
                    isSelected: _selectedDay == index,
                    color: index == _selectedDay ? _DemoWeather.moss : muted,
                    onTap: () => _onDayTapped(index),
                  ),
                ),
                if (index < _days.length - 1)
                  const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ..._scheduleRows(context),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Task progress',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
              Text(
                '${_selectedDay + 1} of 5 complete',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: (_selectedDay + 1) / 5,
              minHeight: 5,
              backgroundColor: _DemoWeather.lichen.withValues(alpha: 0.4),
              color: _DemoWeather.moss,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _scheduleRows(BuildContext context) {
    final rows = <Map<String, dynamic>>[
      <String, dynamic>{
        'time': '09:00',
        'title': 'Data structures',
        'color': _DemoWeather.pacific,
      },
      <String, dynamic>{
        'time': '13:00',
        'title': 'Assignment work',
        'color': _DemoWeather.malachite,
      },
      <String, dynamic>{
        'time': '16:30',
        'title': 'Revision block',
        'color': _DemoWeather.persimmon,
      },
    ];

    return <Widget>[
      for (var i = 0; i < rows.length; i++) ...[
        _DemoScheduleRow(
          time: rows[i]['time'] as String,
          title: rows[i]['title'] as String,
          color: rows[i]['color'] as Color,
          onTap: () => widget.onTap(),
        ),
        if (i < rows.length - 1) const SizedBox(height: AppSpacing.sm),
      ],
    ];
  }
}

class _DemoDayChip extends StatelessWidget {
  const _DemoDayChip({
    required this.day,
    required this.date,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String day;
  final int date;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _Clickable(
      accentColor: color,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Column(
          children: <Widget>[
            Text(
              day,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : color.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                date.toString(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DemoScheduleRow extends StatelessWidget {
  const _DemoScheduleRow({
    required this.time,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final String time;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _Clickable(
      accentColor: color,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 38,
              child: Text(
                time,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
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
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Page 3: AI assistant demo
/// ---------------------------------------------------------------------------

class _AssistantDemo extends StatefulWidget {
  const _AssistantDemo({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_AssistantDemo> createState() => _AssistantDemoState();
}

class _AssistantDemoState extends State<_AssistantDemo> {
  bool _assistantResponded = false;

  void _onAssistantTapped() {
    setState(() => _assistantResponded = true);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return _PreviewShell(
      label: 'Assistant',
      meta: 'Study help',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!_assistantResponded) ...[
            Align(
              alignment: Alignment.centerRight,
              child: _Clickable(
                accentColor: _DemoWeather.pacific,
                onTap: _onAssistantTapped,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 220),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: _DemoWeather.darkestNavy,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    'Help me plan my week.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 220),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: _DemoWeather.lichen.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  "Here's your plan: Data structures at 9, Assignment work at 1, Revision at 4:30.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _DemoWeather.pacific,
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
                    color: AppColors.cocoCream,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    _assistantResponded
                        ? 'Tap above to ask the assistant anything.'
                        : 'Start with the two deadlines this week, then block two study sessions.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _Clickable(
            accentColor: _DemoWeather.saffron,
            onTap: widget.onTap,
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: _DemoWeather.saffron.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: _DemoWeather.saffron.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _assistantResponded ? 'Try again' : 'Ask the assistant',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _DemoWeather.saffron,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.arrow_upward_rounded,
                    size: 16,
                    color: _DemoWeather.saffron,
                  ),
                ],
              ),
            ),
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
    final scheme = theme.colorScheme;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: scheme.outlineVariant),
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
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    meta,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
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

/// ---------------------------------------------------------------------------
/// Page 4: Collaboration preview
/// ---------------------------------------------------------------------------

/// Interactive preview of shared group work. Tapping a task toggles it
/// complete and advances the group progress bar.
class _CollaborationPreview extends StatefulWidget {
  const _CollaborationPreview();

  @override
  State<_CollaborationPreview> createState() => _CollaborationPreviewState();
}

class _CollaborationPreviewState extends State<_CollaborationPreview> {
  final Set<int> _completed = <int>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color muted = scheme.onSurfaceVariant;

    final rows = <Map<String, dynamic>>[
      <String, dynamic>{
        'title': 'Submit assignment draft',
        'meta': 'Assigned to Maya',
        'accent': _DemoWeather.pacific,
      },
      <String, dynamic>{
        'title': 'Review project plan',
        'meta': 'Due Friday',
        'accent': _DemoWeather.malachite,
      },
      <String, dynamic>{
        'title': 'Prepare presentation',
        'meta': 'In progress',
        'accent': _DemoWeather.saffron,
      },
    ];
    final double progress = _completed.length / rows.length;

    return _PreviewShell(
      label: 'Shared group',
      meta: '2 members · 5 tasks',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (var i = 0; i < rows.length; i++) ...[
            _DemoTaskRow(
              title: rows[i]['title'] as String,
              meta: rows[i]['meta'] as String,
              accent: rows[i]['accent'] as Color,
              checked: _completed.contains(i),
              onTap: () => setState(() {
                if (!_completed.add(i)) {
                  _completed.remove(i);
                }
              }),
            ),
            if (i < rows.length - 1)
              Divider(height: 20, color: scheme.outlineVariant),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Group progress',
                  style: theme.textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
              Text(
                '${_completed.length} of ${rows.length} complete',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: _DemoWeather.lichen.withValues(alpha: 0.4),
              color: _DemoWeather.pacific,
            ),
          ),
        ],
      ),
    );
  }
}
