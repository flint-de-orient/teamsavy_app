import '../../widgets/ts.dart';
import 'encashment_screens.dart';
import 'leave_screens.dart';
import 'regularization_screens.dart';

/// Routes for the leave module. Paths match the web app's URLs exactly, so
/// drawer links and server-action redirects resolve to the same screens.
/// List static paths before parameterised ones (e.g. /x/new before /x/:id).
final List<RouteBase> leaveRoutes = [
  GoRoute(path: '/leave', builder: (context, state) => const MyLeaveScreen()),
  GoRoute(path: '/leave/new', builder: (context, state) => const ApplyLeaveScreen()),
  GoRoute(path: '/leave/approvals', builder: (context, state) => const LeaveApprovalsScreen()),
  GoRoute(path: '/leave/queue', builder: (context, state) => const LeaveQueueScreen()),
  GoRoute(
    path: '/leave/report',
    builder: (context, state) => LeaveReportScreen(month: state.uri.queryParameters['month']),
  ),
  GoRoute(path: '/leave/:id', builder: (context, state) => LeaveDetailScreen(id: state.pathParameters['id']!)),

  GoRoute(path: '/leave-encashment', builder: (context, state) => const MyEncashmentScreen()),
  GoRoute(path: '/leave-encashment/new', builder: (context, state) => const ApplyEncashmentScreen()),
  GoRoute(path: '/leave-encashment/approvals', builder: (context, state) => const EncashmentApprovalsScreen()),
  GoRoute(path: '/leave-encashment/queue', builder: (context, state) => const EncashmentQueueScreen()),
  GoRoute(
    path: '/leave-encashment/:id',
    builder: (context, state) => EncashmentDetailScreen(id: state.pathParameters['id']!),
  ),

  GoRoute(path: '/regularization', builder: (context, state) => const MyRegularizationScreen()),
  GoRoute(
    path: '/regularization/new',
    builder: (context, state) => ApplyRegularizationScreen(
      attendanceDayId: state.uri.queryParameters['attendanceDayId'],
      type: state.uri.queryParameters['type'],
    ),
  ),
  GoRoute(path: '/regularization/approvals', builder: (context, state) => const RegularizationApprovalsScreen()),
  GoRoute(path: '/regularization/queue', builder: (context, state) => const RegularizationQueueScreen()),
  GoRoute(
    path: '/regularization/:id',
    builder: (context, state) => RegularizationDetailScreen(id: state.pathParameters['id']!),
  ),
];
