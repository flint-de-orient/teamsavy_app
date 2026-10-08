import '../../widgets/ts.dart';
import 'apply_expense.dart';
import 'disbursement.dart';
import 'expense_detail.dart';
import 'expense_lists.dart';

/// Routes for the expenses module. Paths match the web app's URLs exactly, so
/// drawer links and server-action redirects resolve to the same screens.
/// List static paths before parameterised ones (e.g. /x/new before /x/:id).
final List<RouteBase> expensesRoutes = [
  GoRoute(path: '/expenses', builder: (context, state) => const MyExpensesScreen()),
  GoRoute(path: '/expenses/new', builder: (context, state) => const ApplyExpenseScreen()),
  GoRoute(path: '/expenses/approvals', builder: (context, state) => const ExpenseApprovalsScreen()),
  GoRoute(path: '/expenses/queue', builder: (context, state) => const ExpenseQueueScreen()),
  GoRoute(
    path: '/expenses/history',
    builder: (context, state) => ExpenseHistoryScreen(status: state.uri.queryParameters['status']),
  ),
  GoRoute(path: '/expenses/disbursement', builder: (context, state) => const DisbursementQueueScreen()),
  GoRoute(
    path: '/expenses/:id',
    builder: (context, state) => ExpenseDetailScreen(id: state.pathParameters['id']!),
  ),
];
