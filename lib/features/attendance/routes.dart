import '../../widgets/ts.dart';
import 'hr_screens.dart';
import 'my_attendance_screen.dart';
import 'policy_screen.dart';
import 'punch_screen.dart';
import 'setup_screens.dart';
import 'whatsapp_login_screen.dart';

/// Routes for the attendance module. Paths match the web app's URLs exactly, so
/// drawer links and server-action redirects resolve to the same screens.
/// List static paths before parameterised ones (e.g. /x/new before /x/:id).
final List<RouteBase> attendanceRoutes = [
  GoRoute(
    path: '/attendance',
    builder: (context, state) => AttendanceGridScreen(
      date: state.uri.queryParameters['date'],
      status: state.uri.queryParameters['status'],
      page: state.uri.queryParameters['page'],
    ),
  ),
  GoRoute(path: '/attendance/punch', builder: (context, state) => const PunchScreen()),
  GoRoute(path: '/attendance/my', builder: (context, state) => const MyAttendanceScreen()),
  GoRoute(
    path: '/attendance/override',
    builder: (context, state) => OverrideScreen(
      employeeId: state.uri.queryParameters['employeeId'],
      date: state.uri.queryParameters['date'],
      returnTo: state.uri.queryParameters['returnTo'],
    ),
  ),
  GoRoute(
    path: '/attendance/exceptions',
    builder: (context, state) => ExceptionsScreen(
      type: state.uri.queryParameters['type'],
      show: state.uri.queryParameters['show'],
    ),
  ),
  GoRoute(
    path: '/attendance/report',
    builder: (context, state) => AttendanceReportScreen(month: state.uri.queryParameters['month']),
  ),
  GoRoute(
    path: '/attendance/report/:employeeId',
    builder: (context, state) => AttendanceReportDaysScreen(
      employeeId: state.pathParameters['employeeId']!,
      month: state.uri.queryParameters['month'],
    ),
  ),
  GoRoute(path: '/locations', builder: (context, state) => const LocationsScreen()),
  GoRoute(path: '/shifts', builder: (context, state) => const ShiftsScreen()),
  GoRoute(path: '/devices', builder: (context, state) => const DevicesScreen()),
  GoRoute(path: '/devices/unmatched', builder: (context, state) => const UnmatchedPunchesScreen()),
  GoRoute(path: '/settings/attendance-policy', builder: (context, state) => const AttendancePolicyScreen()),
  GoRoute(path: '/whatsapp-login', builder: (context, state) => const WhatsAppLoginScreen()),
];
