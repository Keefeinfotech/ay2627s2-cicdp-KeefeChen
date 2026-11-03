import 'package:flutter/material.dart';

import '../../features/assistant/presentation/pages/assistant_page.dart';
import '../../features/authentication/models/session.dart';
import '../../features/calendar/presentation/pages/calendar_page.dart';
import '../../features/home/data/task_repository.dart';
import 'package:frontend/features/home/data/api_task_repository.dart';
import '../../features/home/data/task_store.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/projects/presentation/pages/projects_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/task_management/presentation/pages/task_management_page.dart';
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
          repository: ApiTaskRepository(),
          ownerId: widget.ownerId,
        );
    if (!_store.hasLoaded && !_store.isLoading) _store.load();
    _pages[ShellDestination.home] = _buildPage(ShellDestination.home);
  }

  @override
  void dispose() {
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
      ShellDestination.calendar => CalendarPage(
        ownerId: widget.ownerId,
        store: _store,
        session: widget.session,
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
        onOpenAssistant: () => _selectPage(ShellDestination.assistant),
        onOpenProjects: () => _selectPage(ShellDestination.projects),
        onOpenReports: () => _selectPage(ShellDestination.reports),
      ),
    };
  }

  void _selectPage(ShellDestination destination) {
    if (_selected == destination) return;
    _pages[destination] ??= _buildPage(destination);
    setState(() => _selected = destination);
  }

  List<AppNavDestination> get _sidebarDestinations => ShellDestination.values
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

  int get _sidebarIndex => ShellDestination.values.indexOf(_selected);

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
    final bool showSidebar = width >= _sidebarBreakpoint;
    final bool showRail = !showSidebar && width >= _railBreakpoint;
    final bool compactPhones = width < _compactPhoneBreakpoint;

    final pages = IndexedStack(
      index: _selected.index,
      children: <Widget>[
        for (final destination in ShellDestination.values)
          _pages[destination] ?? const SizedBox.shrink(),
      ],
    );

    return PopScope(
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
    );
  }

  Widget _desktopFrame(Widget pages) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Row(
        children: <Widget>[
          AppSidebar(
            destinations: _sidebarDestinations,
            selectedIndex: _sidebarIndex,
            onSelected: (index) {
              if (index < 0 || index >= ShellDestination.values.length) return;
              _selectPage(ShellDestination.values[index]);
            },
            userName: _displayName,
            userEmail: widget.session?.email,
            onProfile: () => _selectPage(ShellDestination.profile),
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
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        right: false,
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  right: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
              ),
              child: NavigationRail(
                selectedIndex: _sidebarIndex,
                onDestinationSelected: (index) {
                  if (index < 0 || index >= ShellDestination.values.length) {
                    return;
                  }
                  _selectPage(ShellDestination.values[index]);
                },
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.92,
                leading: const Padding(
                  padding: EdgeInsets.only(
                    top: AppSpacing.md,
                    bottom: AppSpacing.lg,
                  ),
                  child: NavigationBrandMark(size: 36),
                ),
                destinations: <NavigationRailDestination>[
                  for (final destination in ShellDestination.values)
                    NavigationRailDestination(
                      icon: Icon(destination.icon),
                      selectedIcon: Icon(destination.selectedIcon),
                      label: Text(destination.label),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xxs,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: pages),
          ],
        ),
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
