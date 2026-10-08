import '../../widgets/ts.dart';
import 'assign_task_screen.dart';
import 'kpi_screens.dart';
import 'task_detail_screen.dart';
import 'task_lists.dart';
import 'task_policy_screen.dart';

/// Routes for the tasks module. Paths match the web app's URLs exactly, so
/// drawer links and server-action redirects resolve to the same screens.
/// List static paths before parameterised ones (e.g. /x/new before /x/:id).
final List<RouteBase> tasksRoutes = [
  GoRoute(path: '/tasks', builder: (context, state) => const MyTasksScreen()),
  GoRoute(path: '/tasks/assign', builder: (context, state) => const AssignTaskScreen()),
  GoRoute(path: '/tasks/queue', builder: (context, state) => const TaskQueueScreen()),
  GoRoute(path: '/tasks/approvals', builder: (context, state) => const TaskApprovalsScreen()),
  GoRoute(path: '/tasks/:id', builder: (context, state) => TaskDetailScreen(id: state.pathParameters['id']!)),
  GoRoute(path: '/kpi', builder: (context, state) => MyKpiScreen(month: state.uri.queryParameters['month'])),
  GoRoute(
    path: '/kpi/report',
    builder: (context, state) => KpiReportScreen(month: state.uri.queryParameters['month']),
  ),
  GoRoute(path: '/settings/task-policy', builder: (context, state) => const TaskPolicyScreen()),
];
