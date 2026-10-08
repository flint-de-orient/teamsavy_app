import 'dart:ui';

import '../widgets/ts.dart';
import 'background.dart';
import 'logo.dart';

/// components/app-shell/AppShell.tsx for phones: the sticky glass Topbar,
/// the sectioned sidebar as an off-canvas drawer, the colour-wash
/// backdrop, plus a floating bottom tab bar for the most-used pages.
class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.location, required this.child});
  final Uri location;
  final Widget child;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final me = session.me;
    final tabs = me == null ? <_Tab>[] : _tabsFor(me);
    final path = widget.location.path;
    final canPop = GoRouter.of(context).canPop();

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: p.background,
      drawer: _SidebarDrawer(currentPath: path),
      drawerScrimColor: Colors.black.withValues(alpha: 0.5),
      body: WashBackground(
        child: Column(
          children: [
            _Topbar(canPop: canPop, path: path, onMenu: () => _scaffoldKey.currentState?.openDrawer(), onBack: () => context.pop()),
            Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: widget.child)),
          ],
        ),
      ),
      bottomNavigationBar:
          tabs.isEmpty
              ? null
              : _BottomBar(tabs: tabs, currentPath: path, onMenu: () => _scaffoldKey.currentState?.openDrawer()),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom tabs

class _Tab {
  const _Tab(this.href, this.label, this.icon);
  final String href;
  final String label;
  final IconData icon;
}

const _hrPriority = [
  _Tab('/dashboard', 'Home', LucideIcons.layoutDashboard),
  _Tab('/employees', 'People', LucideIcons.users),
  _Tab('/leave/queue', 'Leave', LucideIcons.clipboardList),
  _Tab('/attendance', 'Attendance', LucideIcons.fingerprint),
  _Tab('/notices', 'Notices', LucideIcons.megaphone),
];

const _employeePriority = [
  _Tab('/leave', 'Leave', LucideIcons.calendarDays),
  _Tab('/attendance/punch', 'Punch', LucideIcons.fingerprint),
  _Tab('/tasks', 'Tasks', LucideIcons.listTodo),
  _Tab('/payroll/payslips', 'Payslips', LucideIcons.receipt),
  _Tab('/expenses', 'Expenses', LucideIcons.receipt),
  _Tab('/notices', 'Notices', LucideIcons.megaphone),
  _Tab('/my-documents', 'Documents', LucideIcons.fileText),
];

List<_Tab> _tabsFor(Me me) {
  final source = me.isHr ? _hrPriority : _employeePriority;
  return source.where((t) => me.canSee(t.href)).take(4).toList();
}

/// The tab that owns [path]: the longest tab href that prefixes it.
String? _activeHref(List<_Tab> tabs, String path) {
  String? best;
  for (final t in tabs) {
    if (path == t.href || path.startsWith('${t.href}/')) {
      if (best == null || t.href.length > best.length) best = t.href;
    }
  }
  // /leave/queue belongs to "Leave Queue", never to an employee's /leave.
  return best;
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.tabs, required this.currentPath, required this.onMenu});
  final List<_Tab> tabs;
  final String currentPath;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final active = _activeHref(tabs, currentPath);
    final bottom = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottom > 0 ? bottom : 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: p.surface.withValues(alpha: p.dark ? 0.82 : 0.86),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: p.glassBorder),
              boxShadow: p.shadowCardHover,
            ),
            child: Row(
              children: [
                for (final t in tabs)
                  Expanded(
                    child: _TabButton(
                      icon: t.icon,
                      label: t.label,
                      active: t.href == active,
                      onTap: () => context.go(t.href),
                    ),
                  ),
                Expanded(child: _TabButton(icon: LucideIcons.menu, label: 'Menu', active: false, onTap: onMenu)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: active ? 48 : 36,
            height: 30,
            decoration: BoxDecoration(
              gradient: active ? p.gradientPrimary : null,
              borderRadius: BorderRadius.circular(999),
              boxShadow: active ? p.shadowButton : null,
            ),
            child: Icon(icon, size: 18, color: active ? p.primaryForeground : p.muted),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tx(11, weight: active ? FontWeight.w700 : FontWeight.w500, color: active ? p.foreground : p.muted),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Topbar

class _Topbar extends StatelessWidget {
  const _Topbar({required this.canPop, required this.path, required this.onMenu, required this.onBack});
  final bool canPop;
  final String path;
  final VoidCallback onMenu;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final top = MediaQuery.of(context).padding.top;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: EdgeInsets.only(top: top),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: p.border)),
          ),
          child: SizedBox(
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  TsIconButton(
                    icon: canPop ? LucideIcons.arrowLeft : LucideIcons.panelLeft,
                    tooltip: canPop ? 'Back' : 'Open menu',
                    onTap: canPop ? onBack : onMenu,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(child: BrandMark()),
                  const Spacer(),
                  NotificationBell(path: path),
                  const SizedBox(width: 6),
                  const ThemeToggle(),
                  const SizedBox(width: 6),
                  const _UserButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// ThemeToggle.tsx: bordered square, moon in Day mode, sun in Night mode.
class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Ts.of(context).dark;
    return TsIconButton(
      icon: dark ? LucideIcons.sun : LucideIcons.moon,
      bordered: true,
      tooltip: dark ? 'Switch to Day mode' : 'Switch to Night mode',
      onTap: () => session.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
    );
  }
}

class _UserButton extends StatelessWidget {
  const _UserButton();

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final me = session.me;
    return GestureDetector(
      onTap: () => _showUserSheet(context),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(gradient: p.gradientPrimary, shape: BoxShape.circle, boxShadow: p.shadowXs),
        child: Text(initialsOf(me?.name ?? '?'), style: tx(12, weight: FontWeight.w700, color: p.primaryForeground)),
      ),
    );
  }
}

void _showUserSheet(BuildContext context) {
  final p = Ts.of(context);
  final me = session.me;
  if (me == null) return;
  showModalBottomSheet(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    builder:
        (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: p.gradientPrimary,
                      shape: BoxShape.circle,
                      boxShadow: p.shadowButton,
                    ),
                    child: Text(
                      initialsOf(me.name),
                      style: tx(16, weight: FontWeight.w700, color: p.primaryForeground),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me.name, style: tx(16, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
                        Text(me.email, style: tx(13, color: p.muted)),
                        const SizedBox(height: 6),
                        TsBadge(me.roleLabel, tone: BadgeTone.purple),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: p.border, height: 1),
              const SizedBox(height: 8),
              _SheetItem(
                icon: LucideIcons.keyRound,
                label: 'Change Password',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/change-password');
                },
              ),
              _SheetItem(
                icon: LucideIcons.messageCircle,
                label: 'WhatsApp Login',
                onTap: () {
                  Navigator.pop(ctx);
                  context.go('/whatsapp-login');
                },
              ),
              _SheetItem(
                icon: LucideIcons.logOut,
                label: 'Sign out',
                danger: true,
                onTap: () async {
                  Navigator.pop(ctx);
                  TenantLogo.clear();
                  await session.signOut();
                },
              ),
            ],
          ),
        ),
  );
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({required this.icon, required this.label, required this.onTap, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(Ts.r2xl),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: danger ? p.danger : p.muted),
            const SizedBox(width: 12),
            Text(label, style: tx(14, weight: FontWeight.w500, color: danger ? p.danger : p.foreground)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notifications

/// NotificationBell.tsx: bordered bell with a red unread count; opens the
/// panel of internship-ending alerts and notices. Refetches whenever the
/// page changes, like the web's pathname effect.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key, required this.path});

  /// The current page; a change triggers a refetch.
  final String path;

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  Json? _notices;
  List<Json>? _internships;

  @override
  void initState() {
    super.initState();
    refreshBus.addListener(_load);
    _load();
  }

  @override
  void didUpdateWidget(covariant NotificationBell old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) _load();
  }

  @override
  void dispose() {
    refreshBus.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      api.action('core.noticeNotifications'),
      api.action('core.internshipEndingNotifications'),
    ]);
    if (!mounted) return;
    setState(() {
      _notices = results[0].data;
      _internships = results[1].ok ? _listFrom(results[1]) : const [];
    });
  }

  List<Json> _listFrom(ActionResult r) => r.data == null ? const [] : asJsonList(r.data!['items']);

  int get _unread => (_notices?.i('unreadCount') ?? 0) + (_internships?.length ?? 0);

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final count = _unread;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        TsIconButton(
          icon: LucideIcons.bell,
          bordered: true,
          tooltip: count > 0 ? 'Notifications, $count unread' : 'Notifications',
          onTap: () => _open(context),
        ),
        if (count > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.danger, borderRadius: BorderRadius.circular(999)),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: tx(10, weight: FontWeight.w600, color: Colors.white, height: 1),
              ),
            ),
          ),
      ],
    );
  }

  void _open(BuildContext context) {
    final p = Ts.of(context);
    final top = MediaQuery.of(context).padding.top + 64 + 8;
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close notifications',
      barrierColor: Colors.black.withValues(alpha: 0.08),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, _, __) {
        final notices = _notices?.l('items') ?? const <Json>[];
        final internships = _internships ?? const <Json>[];
        final loaded = _notices != null && _internships != null;
        return Stack(
          children: [
            Positioned(
              top: top,
              right: 16,
              left: 16,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(Ts.r2xl),
                    border: Border.all(color: p.border),
                    boxShadow: p.shadowCardHover,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
                        child: Text('Notifications', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
                      ),
                      Flexible(
                        child:
                            !loaded
                                ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Text('Loading...', textAlign: TextAlign.center, style: tx(14, color: p.muted)),
                                )
                                : (notices.isEmpty && internships.isEmpty)
                                ? Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 24),
                                  child: Text(
                                    'No notices yet.',
                                    textAlign: TextAlign.center,
                                    style: tx(14, color: p.muted),
                                  ),
                                )
                                : ListView(
                                  shrinkWrap: true,
                                  padding: EdgeInsets.zero,
                                  children: [
                                    for (final item in internships)
                                      _NotifRow(
                                        dot: p.purple,
                                        title: item.s('name'),
                                        bold: true,
                                        subtitle: _internshipLabel(item.i('daysLeft')),
                                        subtitleColor: p.purple,
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          context.push('/employees/${item.s('employeeId')}');
                                        },
                                      ),
                                    for (final item in notices)
                                      _NotifRow(
                                        dot: item.b('isUnread') ? p.primary : Colors.transparent,
                                        title: item.s('subject'),
                                        bold: item.b('isUnread'),
                                        subtitle: '${item.s('typeLabel')} · ${timeAgo(item.at('publishedAt'))}',
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          context.push('/notices/${item.s('noticeId')}');
                                        },
                                      ),
                                  ],
                                ),
                      ),
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx);
                          context.go('/notices');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
                          child: Text(
                            'View all',
                            textAlign: TextAlign.center,
                            style: tx(12, weight: FontWeight.w500, color: p.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder:
          (ctx, anim, _, child) => FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, -0.02), end: Offset.zero).animate(anim),
              child: child,
            ),
          ),
    );
  }

  String _internshipLabel(int daysLeft) {
    if (daysLeft < 0) return 'Internship overdue';
    if (daysLeft == 0) return 'Internship ends today';
    return 'Internship ends in ${daysLeft}d';
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({
    required this.dot,
    required this.title,
    required this.bold,
    required this.subtitle,
    required this.onTap,
    this.subtitleColor,
  });
  final Color dot;
  final String title;
  final bool bold;
  final String subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 6),
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx(
                      14,
                      weight: bold ? FontWeight.w600 : FontWeight.w500,
                      color: bold ? p.foreground : p.muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, style: tx(12, color: subtitleColor ?? p.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sidebar

/// Sidebar.tsx + SidebarNav.tsx as a drawer: logo, then each section's
/// coloured-dot heading and its links; the active link is the gradient pill.
class _SidebarDrawer extends StatelessWidget {
  const _SidebarDrawer({required this.currentPath});
  final String currentPath;

  bool _isActive(String href) => currentPath == href || currentPath.startsWith('$href/');

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final me = session.me;
    final links = me?.nav ?? const <NavLink>[];

    // Only the most specific matching link is active (/leave vs /leave/queue).
    String? activeHref;
    for (final l in links) {
      if (_isActive(l.href) && (activeHref == null || l.href.length > activeHref.length)) activeHref = l.href;
    }

    final sections = <(String?, List<NavLink>)>[];
    for (final l in links) {
      if (sections.isNotEmpty && sections.last.$1 == l.group) {
        sections.last.$2.add(l);
      } else {
        sections.add((l.group, [l]));
      }
    }

    return Drawer(
      width: 288,
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(Ts.r3xl))),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(Ts.r3xl)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: p.dark ? p.surface.withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.9),
              boxShadow: p.shadowCardHover,
            ),
            child: SafeArea(
              right: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Align(alignment: Alignment.centerLeft, child: const BrandMark(large: true)),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                      children: [
                        for (final (title, items) in sections) ...[
                          if (title != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 20, 14, 6),
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: p.sectionColor(title), shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    title.toUpperCase(),
                                    style: tx(11, weight: FontWeight.w700, color: p.sidebarMuted, tracking: 0.12),
                                  ),
                                ],
                              ),
                            ),
                          for (final link in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: _NavItem(
                                link: link,
                                active: link.href == activeHref,
                                onTap: () {
                                  Navigator.of(context).pop();
                                  context.go(link.href);
                                },
                              ),
                            ),
                        ],
                      ],
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

class _NavItem extends StatelessWidget {
  const _NavItem({required this.link, required this.active, required this.onTap});
  final NavLink link;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: active ? p.gradientPrimary : null,
          borderRadius: BorderRadius.circular(999),
          boxShadow: active ? p.shadowButton : null,
        ),
        child: Row(
          children: [
            Icon(lucide(link.icon), size: 16, color: active ? p.primaryForeground : p.sidebarMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                link.label,
                overflow: TextOverflow.ellipsis,
                style: tx(14, weight: FontWeight.w500, color: active ? p.primaryForeground : p.sidebarMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
