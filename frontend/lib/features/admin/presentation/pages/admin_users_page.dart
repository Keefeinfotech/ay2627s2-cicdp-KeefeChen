import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../authentication/models/session.dart';
import '../../data/admin_repository.dart';
import '../../data/models.dart';

/// Administrative user-management console: searchable, filterable,
/// paginated view of registered accounts with activate/deactivate actions.
class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key, required this.session, this.repository});

  final Session session;
  final AdminRepository? repository;

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  late final AdminRepository _repository =
      widget.repository ?? AdminRepository(session: widget.session);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String _search = '';
  String? _statusFilter; // null = all
  int _page = 1;
  static const int _pageSize = 10;

  Future<AdminUsersPageData>? _future;
  String? _busyUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = _repository.fetchUsers(
        search: _search,
        status: _statusFilter,
        page: _page,
        limit: _pageSize,
      );
    });
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _search = value;
        _page = 1;
      });
      _load();
    });
  }

  Future<void> _toggleStatus(AdminUserSummary user) async {
    final next = user.status == 'active' ? 'disabled' : 'active';
    setState(() => _busyUserId = user.id);
    try {
      await _repository.updateUserStatus(user.id, next);
      if (!mounted) return;
      AppSnackBar.success(
        context,
        next == 'disabled' ? 'Account deactivated' : 'Account activated',
      );
      _load();
    } on AdminException catch (error) {
      if (!mounted) return;
      AppSnackBar.error(context, error.message);
    } finally {
      if (mounted) setState(() => _busyUserId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User management'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name or email',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _search = '';
                                _page = 1;
                              });
                              _load();
                            },
                          ),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: <Widget>[
                    _statusChip('All', null),
                    _statusChip('Active', 'active'),
                    _statusChip('Disabled', 'disabled'),
                    _statusChip('Pending', 'pending'),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Expanded(
                  child: FutureBuilder<AdminUsersPageData>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        final error = snapshot.error;
                        final message = error is AdminException
                            ? error.message
                            : 'Could not load users. Please try again.';
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(message, textAlign: TextAlign.center),
                                const SizedBox(height: AppSpacing.md),
                                FilledButton.tonal(
                                  onPressed: _load,
                                  child: const Text('Try again'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final page = snapshot.data!;
                      if (page.items.isEmpty) {
                        return const Center(
                          child: Text('No users match this filter.'),
                        );
                      }
                      return ListView.separated(
                        itemCount: page.items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppSpacing.xs),
                        itemBuilder: (context, index) {
                          final user = page.items[index];
                          return _UserRow(
                            user: user,
                            wide: wide,
                            busy: _busyUserId == user.id,
                            onToggle: () => _toggleStatus(user),
                          );
                        },
                      );
                    },
                  ),
                ),
                FutureBuilder<AdminUsersPageData>(
                  future: _future,
                  builder: (context, snapshot) {
                    final page = snapshot.data;
                    if (page == null) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              '${page.total} users · page ${page.page}'
                              '${page.totalPages > 0 ? ' of ${page.totalPages}' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Previous page',
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: _page > 1
                                ? () {
                                    setState(() => _page -= 1);
                                    _load();
                                  }
                                : null,
                          ),
                          IconButton(
                            tooltip: 'Next page',
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed:
                                snapshot.data != null && _page < page.totalPages
                                ? () {
                                    setState(() => _page += 1);
                                    _load();
                                  }
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statusChip(String label, String? value) {
    final selected = _statusFilter == value;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() {
          _statusFilter = value;
          _page = 1;
        });
        _load();
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.wide,
    required this.busy,
    required this.onToggle,
  });

  final AdminUserSummary user;
  final bool wide;
  final bool busy;
  final VoidCallback onToggle;

  Color _statusColor(String status) => switch (status) {
    'active' => AppColors.malachite,
    'disabled' => AppColors.persimmon,
    _ => AppColors.warningAmber,
  };

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  Widget _avatar() => CircleAvatar(
    radius: 20,
    backgroundColor: AppColors.trustBlue.withValues(alpha: 0.12),
    child: Text(
      user.name.isNotEmpty ? user.name.characters.first.toUpperCase() : '?',
      style: const TextStyle(
        color: AppColors.trustBlue,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _info(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Flexible(
              child: Text(
                user.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            _Pill(
              label: user.role.toUpperCase(),
              tone: user.isAdmin ? AppColors.trustBlue : AppColors.moss,
            ),
            const SizedBox(width: AppSpacing.xs),
            _Pill(
              label: user.status.toUpperCase(),
              tone: _statusColor(user.status),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          user.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Joined ${_formatDate(user.createdAt)} · '
          'Last login ${_formatDate(user.lastLoginAt)}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _action() {
    final isActive = user.status == 'active';
    return OutlinedButton(
      onPressed: busy ? null : onToggle,
      style: OutlinedButton.styleFrom(
        foregroundColor: isActive ? AppColors.persimmon : AppColors.malachite,
        side: BorderSide(
          color: isActive ? AppColors.persimmon : AppColors.malachite,
        ),
        padding: EdgeInsets.zero,
      ),
      child: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(isActive ? 'Deactivate' : 'Activate'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (wide) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            _avatar(),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: _info(context)),
            if (!user.isAdmin) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              SizedBox(width: 122, child: _action()),
            ],
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _avatar(),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _info(context)),
            ],
          ),
          if (!user.isAdmin) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(width: double.infinity, child: _action()),
          ],
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.tone});

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: tone,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
