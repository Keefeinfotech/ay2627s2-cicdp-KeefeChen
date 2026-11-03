import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_app_bar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_error_state.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/responsive_page_layout.dart';
import '../../../home/data/task_repository.dart';
import 'package:frontend/features/home/data/api_task_repository.dart';
import '../../../home/data/task_store.dart';
import '../../data/models/report_snapshot.dart';
import '../controllers/reports_controller.dart';
import '../widgets/report_charts.dart';

/// Progress reporting surface built from live task data.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.ownerId, this.store});

  final String ownerId;
  final TaskStore? store;

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  late final TaskStore _store;
  late final bool _ownsStore;
  late final ReportsController _controller;

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store =
        widget.store ??
        TaskStore(
          repository: ApiTaskRepository(),
          ownerId: widget.ownerId,
        );
    _controller = ReportsController(store: _store);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsStore) _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AuxiliaAppBar(
            title: 'Reports',
            subtitle: 'Progress at a glance',
            actions: <Widget>[
              IconButton(
                tooltip: 'Refresh reports',
                onPressed: _controller.isLoading ? null : _controller.refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppSizes.maxContentWidth,
                ),
                child: RefreshIndicator(
                  onRefresh: _controller.refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    children: <Widget>[
                      _heading(context),
                      const SizedBox(height: AppSpacing.lg),
                      if (_controller.error != null) ...<Widget>[
                        AppErrorBanner(
                          message: _controller.error!,
                          onRetry: _controller.refresh,
                          onDismiss: _controller.clearError,
                        ),
                      ],
                      if (_controller.isLoading)
                        const TaskListSkeleton(itemCount: 4)
                      else if (!_controller.hasLoaded &&
                          _controller.error != null)
                        Container(
                          decoration: _cardDecoration(context),
                          child: AppErrorState(
                            title: 'Reports could not be loaded',
                            message: _controller.error!,
                            onRetry: _controller.refresh,
                          ),
                        )
                      else if (_controller.snapshot.isEmpty)
                        _emptyState(context)
                      else
                        ..._reportBody(context, _controller.snapshot),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _heading(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final selector = SegmentedButton<ReportPeriod>(
          segments: ReportPeriod.values
              .map(
                (period) => ButtonSegment<ReportPeriod>(
                  value: period,
                  label: Text(period.shortLabel),
                  icon: Icon(switch (period) {
                    ReportPeriod.week => Icons.view_week_outlined,
                    ReportPeriod.month => Icons.calendar_month_outlined,
                    ReportPeriod.all => Icons.all_inclusive_rounded,
                  }, size: AppSizes.iconSm),
                ),
              )
              .toList(growable: false),
          selected: <ReportPeriod>{_controller.period},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              _controller.setPeriod(selection.first),
        );

        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Your progress',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_controller.period.label} · generated '
              '${formatDateOnly(_controller.snapshot.generatedAt)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 640) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              title,
              const SizedBox(height: AppSpacing.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: selector,
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: title),
            const SizedBox(width: AppSpacing.md),
            selector,
          ],
        );
      },
    );
  }

  List<Widget> _reportBody(BuildContext context, ReportSnapshot snapshot) {
    return <Widget>[
      _kpiGrid(context, snapshot),
      const SizedBox(height: AppSpacing.xl),
      LayoutBuilder(
        builder: (context, constraints) {
          final activity = _activityCard(context, snapshot);
          final priority = _priorityCard(context, snapshot);
          if (constraints.maxWidth < 900) {
            return Column(
              children: <Widget>[
                activity,
                const SizedBox(height: AppSpacing.lg),
                priority,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 3, child: activity),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 2, child: priority),
            ],
          );
        },
      ),
      const SizedBox(height: AppSpacing.lg),
      _projectCard(context, snapshot),
      const SizedBox(height: AppSpacing.lg),
      _insightCard(context, snapshot),
    ];
  }

  Widget _kpiGrid(BuildContext context, ReportSnapshot snapshot) {
    final rate = snapshot.completionRate;
    final Color rateColor = rate >= 0.7
        ? AppColors.successGreen
        : AppColors.trustBlue;

    return ResponsiveGrid(
      minItemWidth: 168,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: <Widget>[
        _ReportKpiCard(
          icon: Icons.donut_large_outlined,
          label: 'Completion rate',
          value: '${(rate * 100).round()}%',
          caption: 'of ${snapshot.totalTasks} in view',
          color: rateColor,
        ),
        _ReportKpiCard(
          icon: Icons.task_alt_rounded,
          label: 'Completed',
          value: '${snapshot.completedTasks}',
          caption: '${snapshot.completedInPeriod} finished in period',
          color: AppColors.successGreen,
        ),
        _ReportKpiCard(
          icon: Icons.pending_actions_outlined,
          label: 'Still open',
          value: '${snapshot.pendingTasks}',
          caption: '${snapshot.createdInPeriod} created in period',
        ),
        _ReportKpiCard(
          icon: Icons.warning_amber_rounded,
          label: 'Overdue',
          value: '${snapshot.overdueTasks}',
          caption: snapshot.overdueTasks == 0
              ? 'nothing past due'
              : 'need attention',
          color: snapshot.overdueTasks > 0 ? AppColors.errorRed : null,
        ),
        _ReportKpiCard(
          icon: Icons.calendar_today_outlined,
          label: 'Focus days',
          value: '${snapshot.focusDays}',
          caption: 'active days in period',
        ),
        _ReportKpiCard(
          icon: Icons.local_fire_department_outlined,
          label: 'Current streak',
          value: '${snapshot.currentStreak}',
          caption: snapshot.currentStreak == 1
              ? 'day in a row'
              : 'days in a row',
          color: snapshot.currentStreak > 0 ? AppColors.warningAmber : null,
        ),
      ],
    );
  }

  Widget _activityCard(BuildContext context, ReportSnapshot snapshot) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Task activity',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Work created and completed across the selected period.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusBadge(
                label:
                    '${snapshot.focusDays} active '
                    '${snapshot.focusDays == 1 ? 'day' : 'days'}',
                color: scheme.primary,
                icon: Icons.timeline_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (snapshot.maxSeriesValue == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.bar_chart_rounded,
                    size: 36,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'No created or completed tasks in this window.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            ReportActivityChart(
              points: snapshot.series,
              maxValue: snapshot.maxSeriesValue,
            ),
        ],
      ),
    );
  }

  Widget _priorityCard(BuildContext context, ReportSnapshot snapshot) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Priority mix',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Where your workload sits and how much is complete.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          ReportPriorityDonut(slices: snapshot.priorities),
        ],
      ),
    );
  }

  Widget _projectCard(BuildContext context, ReportSnapshot snapshot) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Project breakdown',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Completion by course or project name.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(
                label:
                    '${snapshot.projects.length} '
                    '${snapshot.projects.length == 1 ? 'group' : 'groups'}',
                color: scheme.onSurfaceVariant,
                icon: Icons.workspaces_outline,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (snapshot.projects.isEmpty)
            Text(
              'No project grouping yet. Add a course or project to a task to '
              'see this breakdown.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            for (var index = 0; index < snapshot.projects.length; index++) ...[
              if (index > 0) const SizedBox(height: AppSpacing.lg),
              _ProjectReportRow(project: snapshot.projects[index]),
            ],
        ],
      ),
    );
  }

  Widget _insightCard(BuildContext context, ReportSnapshot snapshot) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.insights_outlined, color: scheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'What this means',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  snapshot.insight,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      child: AppEmptyState(
        icon: Icons.insights_outlined,
        title: 'No progress to report yet',
        message:
            'Complete or create a task and reports will summarise your '
            'completion rate, workload and focus streaks.',
        action: AppButton(
          label: 'Refresh reports',
          icon: Icons.refresh_rounded,
          variant: AppButtonVariant.outline,
          onPressed: _controller.refresh,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: scheme.outlineVariant),
    );
  }
}

class _ReportKpiCard extends StatelessWidget {
  const _ReportKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color accent = color ?? scheme.primary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: AppSizes.iconSm, color: accent),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectReportRow extends StatelessWidget {
  const _ProjectReportRow({required this.project});

  final ReportProjectSlice project;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Color accent = project.overdue > 0
        ? scheme.error
        : project.rate >= 1
        ? AppColors.successGreen
        : scheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                project.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (project.overdue > 0) ...<Widget>[
              StatusBadge(
                label: '${project.overdue} overdue',
                color: scheme.error,
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              '${project.completed}/${project.total}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${(project.rate * 100).round()}%',
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        CompletionBar(
          value: project.rate,
          color: accent,
          height: 5,
          label: '${project.name} completion',
        ),
      ],
    );
  }
}
