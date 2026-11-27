import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/admin/presentation/pages/admin_dashboard_page.dart';
import '../../features/assistant/presentation/pages/assistant_page.dart';
import '../../features/authentication/models/session.dart';
import '../../features/calendar/data/calendar_preferences_store.dart';
import '../../features/calendar/presentation/pages/calendar_page.dart';
import '../../features/groups/presentation/pages/groups_page.dart';
import '../../features/home/data/api_task_repository.dart';
import '../../features/home/data/task_store.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/data/avatar_store.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/projects/presentation/pages/projects_page.dart';
import '../../features/reminders/widgets/reminder_host.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/sync/data/background_sync_handler.dart';
import '../../features/sync/widgets/sync_center_dialog.dart';
import '../../features/task_management/presentation/pages/task_management_page.dart';
import '../design_system/ds_tokens.dart';
import '../theme/app_spacing.dart';
import '../widgets/app_navigation.dart';

/// The primary destinations of the application shell.
enum ShellDestination {
  home(
    label: 'Home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    mobile: true,
  ),
  tasks(
    label: 'Tasks',
    icon: Icons.checklist_outlined,
    selectedIcon: Icons.checklist_rounded,
    mobile: true,
  ),
  projects(
    label: 'Projects',
    icon: Icons.workspaces_outline,
    selectedIcon: Icons.workspaces_rounded,
  ),
  groups(
    label: 'Groups',
    icon: Icons.groups_outlined,
    selectedIcon: Icons.groups_rounded,
  ),
  calendar(
    label: 'Calendar',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today_rounded,
    mobile: true,
  ),
  assistant(
    label: 'AI Assistant',
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome_rounded,
    mobile: true,
  ),
  reports(
    label: 'Reports',
    icon: Icons.insights_outlined,
    selectedIcon: Icons.insights_rounded,
  ),
  profile(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    mobile: true,
  ),
  admin(
    label: 'Admin',
    icon: Icons.admin_panel_settings_outlined,
    selectedIcon: Icons.admin_panel_settings_rounded,
  );

  const ShellDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.mobile = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  /// Whether the destination appears in the compact bottom navigation.
  final bool mobile;

  AppNavDestination get navDestination => AppNavDestination(
    label: label,
    icon: icon,
    selectedIcon: selectedIcon,
    desktopOnly: !mobile,
  );

  /// Mobile labels are kept short so five destinations fit at 360 px.
  String get mobileLabel => switch (this) {
    ShellDestination.assistant => 'Assistant',
    _ => label,
  };
}

/// Responsive application frame shared by every signed-in surface.
///
/// * Phones use a five-destination bottom navigation.
/// * Tablets use a navigation rail so all seven destinations stay reachable.
/// * Desktops use the full sidebar.
///
/// Pages are created the first time they are visited and then kept alive in an
/// [IndexedStack]. This preserves scroll position and form state without firing
/// calendar or assistant requests for tabs the user never opens.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.ownerId,
    this.displayName,
    this.session,
    this.store,
  });

  final String ownerId;
  final String? displayName;
  final Session? session;
  final TaskStore? store;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const double _railBreakpoint = 600;
  static const double _sidebarBreakpoint = 1024;
  static const double _compactPhoneBreakpoint = 360;

  late final TaskStore _store;
  late final bool _ownsStore;
  late final AvatarStore _avatarStore;
  late final CalendarPreferencesStore _calendarPreferences;
  late final BackgroundSyncHandler _backgroundSync;
  final Map<ShellDestination, Widget> _pages = <ShellDestination, Widget>{};
  ShellDestination _selected = ShellDestination.home;

  String? get _displayName {
    final name = widget.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final sessionName = widget.session?.name?.trim();
    if (sessionName != null && sessionName.isNotEmpty) return sessionName;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _ownsStore = widget.store == null;
    _store =
        widget.store ??
        TaskStore(
          // Guest workspaces are local-only. Passing an empty token prevents
          // the repository from probing secure storage, which also keeps the
          // offline flow deterministic in tests and on platforms without a
          // secure-storage implementation.
          repository: ApiTaskRepository(token: widget.session?.token ?? ''),
          ownerId: widget.ownerId,
        );
    if (!_store.hasLoaded && !_store.isLoading) _store.load();
    _backgroundSync = BackgroundSyncHandler(store: _store)..start();
    _avatarStore = AvatarStore(ownerId: widget.ownerId);
    _avatarStore.load();
    _calendarPreferences = CalendarPreferencesStore(ownerId: widget.ownerId);
    _calendarPreferences.load();
    _pages[ShellDestination.home] = _buildPage(ShellDestination.home);
  }

  @override
  void dispose() {
    _backgroundSync.dispose();
    _avatarStore.dispose();
    _calendarPreferences.dispose();
    if (_ownsStore) _store.dispose();
    super.dispose();
  }

  Widget _buildPage(ShellDestination destination) {
    final displayName = _displayName;
    return switch (destination) {
      ShellDestination.home => HomeScreen(
        ownerId: widget.ownerId,
        displayName: displayName,
        session: widget.session,
        store: _store,
        avatarStore: _avatarStore,
        onOpenAssistant: () => _selectPage(ShellDestination.assistant),
        onOpenProfile: () => _selectPage(ShellDestination.profile),
      ),
      ShellDestination.tasks => TaskManagementPage(
        ownerId: widget.ownerId,
        store: _store,
      ),
      ShellDestination.projects => ProjectsPage(
        ownerId: widget.ownerId,
        store: _store,
      ),
      ShellDestination.groups => GroupsPage(
        store: _store,
        session: widget.session,
      ),
      ShellDestination.calendar => CalendarPage(
        ownerId: widget.ownerId,
        store: _store,
        session: widget.session,
        preferencesStore: _calendarPreferences,
      ),
      ShellDestination.assistant => AssistantPage(
        ownerId: widget.ownerId,
        session: widget.session,
        store: _store,
      ),
      ShellDestination.reports => ReportsPage(
        ownerId: widget.ownerId,
        store: _store,
      ),
      ShellDestination.profile => ProfilePage(
        store: _store,
        session: widget.session,
        displayName: displayName,
        avatarStore: _avatarStore,
        onOpenAssistant: () => _selectPage(ShellDestination.assistant),
        onOpenProjects: () => _selectPage(ShellDestination.projects),
        onOpenGroups: () => _selectPage(ShellDestination.groups),
        onOpenReports: () => _selectPage(ShellDestination.reports),
      ),
      ShellDestination.admin => _adminPage(),
    };
  }

  /// The administrative console is reachable only with an administrator
  /// session. Standard users never see the destination, and a forged deep
  /// link lands them on a sign-in placeholder instead of the console.
  Widget _adminPage() {
    final session = widget.session;
    if (session == null || !session.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Administration')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'This console requires an administrator account.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    return AdminDashboardPage(session: session);
  }

  void _selectPage(ShellDestination destination) {
    if (_selected == destination) return;
    _pages[destination] ??= _buildPage(destination);
    setState(() => _selected = destination);
  }

  /// Destinations visible to this session. The admin console is hidden for
  /// standard users — the server enforces authorisation either way.
  List<ShellDestination> get _visibleDestinations => ShellDestination.values
      .where(
        (destination) =>
            destination != ShellDestination.admin ||
            (widget.session?.isAdmin ?? false),
      )
      .toList(growable: false);

  List<AppNavDestination> get _sidebarDestinations => _visibleDestinations
      .map((destination) {
        final nav = destination.navDestination;
        return AppNavDestination(
          label: nav.label,
          icon: nav.icon,
          selectedIcon: nav.selectedIcon,
        );
      })
      .toList(growable: false);

  List<AppNavDestination> get _mobileDestinations => ShellDestination.values
      .where((destination) => destination.mobile)
      .map((destination) {
        final nav = destination.navDestination;
        return AppNavDestination(
          label: destination.mobileLabel,
          icon: nav.icon,
          selectedIcon: nav.selectedIcon,
        );
      })
      .toList(growable: false);

  int get _sidebarIndex => _visibleDestinations.indexOf(_selected);

  int get _mobileIndex {
    final mobile = _mobileDestinations;
    final label = _selected.mobileLabel;
    final index = mobile.indexWhere(
      (destination) => destination.label == label,
    );
    return index < 0 ? 0 : index;
  }

  void _onMobileSelected(int index) {
    final destinations = ShellDestination.values
        .where((destination) => destination.mobile)
        .toList(growable: false);
    if (index < 0 || index >= destinations.length) return;
    _selectPage(destinations[index]);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Desktop browsers never get the phone frame: a narrow window (or docked
    // DevTools) must not collapse the whole shell to a bottom navigation bar.
    // Mobile web/native keep the responsive phone behaviour.
    final bool isDesktopTarget =
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.fuchsia;
    final bool showSidebar = width >= _sidebarBreakpoint;
    final bool showRail =
        !showSidebar && (width >= _railBreakpoint || isDesktopTarget);
    final bool compactPhones = width < _compactPhoneBreakpoint;

    final pages = Column(
      children: <Widget>[
        _CompactShellHeader(
          title: _selected.label,
          store: _store,
          onRefresh: () {
            _store.load();
            _store.retrySync();
          },
        ),
        Expanded(
          child: IndexedStack(
            index: _selected.index,
            children: <Widget>[
              for (final destination in ShellDestination.values)
                _pages[destination] ?? const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    );

    return ReminderHost(
      store: _store,
      child: PopScope(
        canPop: _selected == ShellDestination.home,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selected != ShellDestination.home) {
            _selectPage(ShellDestination.home);
          }
        },
        child: showSidebar
            ? _desktopFrame(pages)
            : showRail
            ? _tabletFrame(pages)
            : _phoneFrame(pages, compact: compactPhones),
      ),
    );
  }

  Widget _desktopFrame(Widget pages) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: <Widget>[
          AnimatedBuilder(
            animation: _avatarStore,
            builder: (context, _) => AppSidebar(
              destinations: _sidebarDestinations,
              selectedIndex: _sidebarIndex,
              onSelected: (index) {
                if (index < 0 || index >= _visibleDestinations.length) {
                  return;
                }
                _selectPage(_visibleDestinations[index]);
              },
              userName: _displayName,
              userEmail: widget.session?.email,
              avatarStyle: _avatarStore.style,
              onProfile: () => _selectPage(ShellDestination.profile),
            ),
          ),
          VerticalDivider(
            width: 1,
            thickness: 1,
            color: theme.colorScheme.outlineVariant,
          ),
          Expanded(child: pages),
        ],
      ),
    );
  }

  Widget _tabletFrame(Widget pages) {
    return Scaffold(
      body: Row(
        children: <Widget>[
          AppNavigationRail(
            destinations: _sidebarDestinations,
            selectedIndex: _sidebarIndex,
            onSelected: (index) {
              if (index < 0 || index >= _visibleDestinations.length) {
                return;
              }
              _selectPage(_visibleDestinations[index]);
            },
          ),
          Expanded(child: pages),
        ],
      ),
    );
  }

  Widget _phoneFrame(Widget pages, {required bool compact}) {
    return Scaffold(
      body: pages,
      bottomNavigationBar: AppBottomNavigation(
        destinations: _mobileDestinations,
        selectedIndex: _mobileIndex,
        labelBehavior: compact
            ? NavigationDestinationLabelBehavior.onlyShowSelected
            : NavigationDestinationLabelBehavior.alwaysShow,
        onSelected: _onMobileSelected,
      ),
    );
  }
}

class _CompactShellHeader extends StatelessWidget {
  const _CompactShellHeader({
    required this.title,
    required this.store,
    required this.onRefresh,
  });

  final String title;
  final TaskStore store;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = scheme.brightness == Brightness.dark;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : scheme.outlineVariant;

    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final snapshot = store.syncSnapshot;
        final pending = snapshot?.pendingCount ?? 0;
        final hasConflict = snapshot?.phase.name == 'conflict';
        final hasSyncIssue =
            snapshot != null &&
            snapshot.phase.name != 'synced' &&
            snapshot.phase.name != 'localOnly';
        final reminders = store.dueReminders();
        final reminderCount = reminders.length;

        return Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : scheme.surface,
            border: Border(bottom: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (reminderCount > 0)
                _HeaderIconBadge(
                  icon: Icons.notifications_rounded,
                  tooltip:
                      '$reminderCount reminder${reminderCount == 1 ? '' : 's'}',
                  badge: '$reminderCount',
                  color: Ds.warningAmber,
                  onPressed: () => _showReminders(context),
                )
              else
                _HeaderIconButton(
                  icon: Icons.notifications_none_rounded,
                  tooltip: 'Notifications',
                  onPressed: () => _showReminders(context),
                ),
              const SizedBox(width: 4),
              _SyncIndicator(
                pending: pending,
                hasIssue: hasSyncIssue,
                hasConflict: hasConflict,
                onTap: () => showSyncCenterDialog(context, store),
              ),
              const SizedBox(width: 4),
              _HeaderIconButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Refresh',
                onPressed: onRefresh,
              ),
            ],
          ),
        );
      },
    );
  }

  void _showReminders(BuildContext context) {
    final reminders = store.upcomingReminders;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final scheme = theme.colorScheme;
        return AlertDialog(
          title: const Text('Reminders'),
          content: SizedBox(
            width: 360,
            child: reminders.isEmpty
                ? Text(
                    'No reminders scheduled.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: reminders.length > 8 ? 8 : reminders.length,
                      separatorBuilder: (_, separatorIndex) =>
                          const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final task = reminders[i];
                        final due = task.isReminderDue();
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            due
                                ? Icons.notifications_active_rounded
                                : Icons.schedule_rounded,
                            color: due ? scheme.error : scheme.primary,
                            size: 20,
                          ),
                          title: Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            due ? 'Due now' : 'Scheduled',
                            style: TextStyle(
                              color: due
                                  ? scheme.error
                                  : scheme.onSurfaceVariant,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: AppSizes.iconMd),
      constraints: const BoxConstraints(
        minWidth: AppSizes.touchTarget,
        minHeight: AppSizes.touchTarget,
      ),
      padding: const EdgeInsets.all(12),
    );
  }
}

class _HeaderIconBadge extends StatelessWidget {
  const _HeaderIconBadge({
    required this.icon,
    required this.tooltip,
    required this.badge,
    required this.color,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final String badge;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _HeaderIconButton(icon: icon, tooltip: tooltip, onPressed: onPressed),
        Positioned(
          right: 2,
          top: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(Ds.rSm),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({
    required this.pending,
    required this.hasIssue,
    required this.hasConflict,
    required this.onTap,
  });
  final int pending;
  final bool hasIssue;
  final bool hasConflict;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color = hasConflict
        ? Ds.warningAmber
        : hasIssue
        ? scheme.primary
        : scheme.onSurfaceVariant;
    final label = pending > 0
        ? '$pending changes waiting'
        : (hasIssue ? 'Sync status' : 'Synced');

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Ds.rSm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: AppSizes.touchTarget,
            minHeight: AppSizes.touchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasConflict ? Icons.cloud_sync_rounded : Icons.cloud_outlined,
                  size: AppSizes.iconMd,
                  color: color,
                ),
                if (pending > 0) ...[
                  const SizedBox(width: 6),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Ds.warningAmber,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(width: 6, height: 6),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
