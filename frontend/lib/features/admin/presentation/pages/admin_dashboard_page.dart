import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../authentication/models/session.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';
import 'admin_users_page.dart';

/// Public Grafana URL for the local monitoring stack (never a secret).
const String grafanaBaseUrl = String.fromEnvironment(
  'GRAFANA_BASE_URL',
  defaultValue: 'http://localhost:3001',
);

/// Administrative overview: platform statistics, analytics trends and system
/// monitoring entry points. Visible to administrators only — every figure is
/// served by `/api/admin/*` with server-side authorisation behind it.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, required this.session, this.repository});

  final Session session;
  final AdminRepository? repository;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late final AdminRepository _repository =
      widget.repository ?? AdminRepository(session: widget.session);

  Future<AdminStats>? _stats;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final future = _repository.fetchStats();
    setState(() {
      _stats = future;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administration'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh statistics',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<AdminStats>(
        future: _stats,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ErrorState(
              message: _friendlyMessage(snapshot.error),
              onRetry: _reload,
            );
          }
          final stats = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return ListView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: <Widget>[
                    const AppSectionHeader(
                      title: 'Overview',
                      subtitle: 'Live platform statistics from MongoDB.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StatGrid(stats: stats, wide: wide),
                    const SizedBox(height: AppSpacing.lg),
                    const AppSectionHeader(
                      title: 'Task activity',
                      subtitle:
                          'Tasks created vs completed over the last 14 days.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      child: SizedBox(
                        height: 260,
                        child: _TrendChart(
                          created: stats.taskCreationTrend,
                          completed: stats.taskCompletionTrend,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AppSectionHeader(
                      title: 'User accounts',
                      subtitle: 'Registration and account status breakdown.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(child: _UserStatusRow(stats: stats)),
                    const SizedBox(height: AppSpacing.lg),
                    const AppSectionHeader(
                      title: 'User management',
                      subtitle: 'Search, inspect and activate or deactivate accounts.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppCard(
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminUsersPage(
                            session: widget.session,
                            repository: widget.repository,
                          ),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.trustBlue.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(
                              Icons.group_rounded,
                              color: AppColors.trustBlue,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'Manage registered users',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${stats.users.total} accounts · '
                                  '${stats.users.active} active · '
                                  '${stats.users.disabled} disabled',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const AppSectionHeader(
                      title: 'System monitoring',
                      subtitle:
                          'Backend observability with Prometheus and Grafana.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _MonitorRow(
                            icon: Icons.query_stats_rounded,
                            label: 'Metrics endpoint',
                            value: '/metrics',
                            hint:
                                'Protected by METRICS_TOKEN or administrator auth. '
                                'Scraped by Prometheus at an interval.',
                          ),
                          Divider(height: AppSpacing.lg),
                          _MonitorRow(
                            icon: Icons.insights_rounded,
                            label: 'Grafana (local stack)',
                            value: grafanaBaseUrl,
                            hint:
                                'Run: docker compose --profile monitoring up -d. '
                                'The Render free tier cannot host Grafana; the '
                                'documented demo runs locally.',
                          ),
                          Divider(height: AppSpacing.lg),
                          _MonitorRow(
                            icon: Icons.health_and_safety_rounded,
                            label: 'Backend availability',
                            value: '/api/health',
                            hint:
                                'Every Prometheus scrape also records service '
                                'uptime via the synthetic probe dashboard.',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Personal data policy: this console shows aggregated '
                      'platform metrics only. Administrators cannot read '
                      'individual tasks, notes or message contents.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _friendlyMessage(Object? error) {
    if (error is AdminException) return error.message;
    return 'Could not load statistics. Please try again.';
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats, required this.wide});

  final AdminStats stats;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final items = <_StatItem>[
      _StatItem(
        icon: Icons.people_alt_outlined,
        label: 'Registered users',
        value: '${stats.users.total}',
        tone: AppColors.trustBlue,
      ),
      _StatItem(
        icon: Icons.task_alt_rounded,
        label: 'Tasks created',
        value: '${stats.tasks.total}',
        tone: AppColors.trustBlue,
      ),
      _StatItem(
        icon: Icons.pie_chart_outline_rounded,
        label: 'Task completion rate',
        value: '${(stats.tasks.completionRate * 100).toStringAsFixed(1)}%',
        tone: AppColors.trustBlue,
      ),
      _StatItem(
        icon: Icons.person_add_alt_rounded,
        label: 'New users (7 days)',
        value: '${stats.users.newLast7Days}',
        tone: AppColors.trustBlue,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = wide ? 4 : 2;
        final spacing = AppSpacing.md.toDouble();
        final itemWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: <Widget>[
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(item.icon, color: item.tone, size: 20),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        item.value,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: item.tone,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.tone,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tone;
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.created, required this.completed});

  final List<AdminTrendPoint> created;
  final List<AdminTrendPoint> completed;

  @override
  Widget build(BuildContext context) {
    if (created.isEmpty && completed.isEmpty) {
      return Center(
        child: Text(
          'No task activity recorded yet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final days = created.length >= completed.length ? created : completed;
    final maxCount = days
        .map((p) => p.count)
        .fold<int>(1, (peak, count) => count > peak ? count : peak);

    return BarChart(
      BarChartData(
        maxY: (maxCount + 1).toDouble(),
        alignment: BarChartAlignment.spaceBetween,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 11),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= days.length) {
                  return const SizedBox.shrink();
                }
                final label = days[index].date.length >= 5
                    ? days[index].date.substring(5)
                    : days[index].date;
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label, style: const TextStyle(fontSize: 9)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        barGroups: <BarChartGroupData>[
          for (var i = 0; i < days.length; i += 1)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: i < created.length ? created[i].count.toDouble() : 0,
                  color: AppColors.trustBlue,
                  width: 7,
                  borderRadius: BorderRadius.circular(3),
                ),
                BarChartRodData(
                  toY: i < completed.length ? completed[i].count.toDouble() : 0,
                  color: AppColors.malachite,
                  width: 7,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _UserStatusRow extends StatelessWidget {
  const _UserStatusRow({required this.stats});

  final AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget stat(String label, int value, Color tone) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$value',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    return Row(
      children: <Widget>[
        stat('Active', stats.users.active, AppColors.malachite),
        stat('Disabled', stats.users.disabled, AppColors.persimmon),
        stat('Pending', stats.users.pending, AppColors.warningAmber),
        stat('Total', stats.users.total, AppColors.trustBlue),
      ],
    );
  }
}

class _MonitorRow extends StatelessWidget {
  const _MonitorRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.hint,
  });

  final IconData icon;
  final String label;
  final String value;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.trustBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 18, color: AppColors.trustBlue),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.trustBlue,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.cloud_off_rounded, size: 42),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
