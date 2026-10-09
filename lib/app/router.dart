import '../features/attendance/routes.dart';
import '../features/auth/auth_screens.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/expenses/routes.dart';
import '../features/hiring/routes.dart';
import '../features/leave/routes.dart';
import '../features/payroll/routes.dart';
import '../features/people/routes.dart';
import '../features/settings/routes.dart';
import '../features/tasks/routes.dart';
import '../features/termination_letters/routes.dart';
import '../shell/app_shell.dart';
import '../widgets/ts.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellKey = GlobalKey<NavigatorState>(debugLabel: 'shell');

const _publicPaths = {'/login', '/forgot-password'};

/// Mirrors proxy.ts + app/(app)/layout.tsx: signed-out users go to /login,
/// signed-in users never see /login, and the first-login gates
/// (password change, onboarding documents) and suspension take over the
/// whole app until resolved.
String? _redirect(BuildContext context, GoRouterState state) {
  final path = state.uri.path;
  switch (session.status) {
    case AuthStatus.unknown:
      return path == '/splash' ? null : '/splash';
    case AuthStatus.signedOut:
      return _publicPaths.contains(path) ? null : '/login';
    case AuthStatus.signedIn:
      final me = session.me;
      if (session.suspendedReason != null) return path == '/suspended' ? null : '/suspended';
      if (me == null) return path == '/splash' ? null : '/splash';
      if (me.mustChangePassword) return path == '/change-password' ? null : '/change-password';
      if (me.needsOnboardingDocuments && path != '/onboarding/documents' && path != '/my-documents') {
        return '/onboarding/documents';
      }
      if (_publicPaths.contains(path) || path == '/splash' || path == '/' || path == '/suspended') {
        return me.homePath;
      }
      return null;
  }
}

final router = GoRouter(
  navigatorKey: _rootKey,
  initialLocation: '/splash',
  refreshListenable: session,
  redirect: _redirect,
  routes: [
    GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
    GoRoute(path: '/change-password', parentNavigatorKey: _rootKey, builder: (_, __) => const ChangePasswordScreen()),
    GoRoute(path: '/suspended', builder: (_, __) => const SuspendedScreen()),
    GoRoute(path: '/', redirect: (_, __) => session.me?.homePath ?? '/login'),
    ShellRoute(
      navigatorKey: _shellKey,
      builder: (context, state, child) => AppShell(location: state.uri, child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
        ...hiringRoutes,
        ...peopleRoutes,
        ...leaveRoutes,
        ...attendanceRoutes,
        ...payrollRoutes,
        ...expensesRoutes,
        ...tasksRoutes,
        ...settingsRoutes,
        ...terminationLettersRoutes,
      ],
    ),
  ],
  errorBuilder: (context, state) => _NotInApp(path: state.uri.toString()),
);

/// A web page that has no app screen (yet) - offers to open it on the web.
class _NotInApp extends StatelessWidget {
  const _NotInApp({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(LucideIcons.compass, size: 36, color: p.muted),
              const SizedBox(height: 16),
              Text(
                'Page not found',
                textAlign: TextAlign.center,
                style: tx(20, weight: FontWeight.w700, color: p.foreground),
              ),
              const SizedBox(height: 6),
              Text(path, textAlign: TextAlign.center, style: tx(13, color: p.muted)),
              const SizedBox(height: 24),
              Center(child: TsButton(label: 'Go Home', onPressed: () => context.go(session.me?.homePath ?? '/login'))),
            ],
          ),
        ),
      ),
    );
  }
}
