import '../../widgets/ts.dart';
import 'documents_screens.dart';
import 'employee_detail_screen.dart';
import 'employee_form_screen.dart';
import 'employees_screen.dart';
import 'notice_form_screen.dart';
import 'notices_screens.dart';

/// Routes for the people module. Paths match the web app's URLs exactly, so
/// drawer links and server-action redirects resolve to the same screens.
/// List static paths before parameterised ones (e.g. /x/new before /x/:id).
final List<RouteBase> peopleRoutes = [
  GoRoute(path: '/employees', builder: (context, state) => const EmployeesScreen()),
  GoRoute(path: '/employees/new', builder: (context, state) => const EmployeeFormScreen()),
  GoRoute(
    path: '/employees/:id',
    builder: (context, state) => EmployeeDetailScreen(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/employees/:id/edit',
    builder: (context, state) => EmployeeFormScreen(employeeId: state.pathParameters['id']!),
  ),
  GoRoute(path: '/notices', builder: (context, state) => const NoticesScreen()),
  GoRoute(path: '/notices/new', builder: (context, state) => const NoticeFormScreen()),
  GoRoute(
    path: '/notices/:id',
    builder: (context, state) => NoticeDetailScreen(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/notices/:id/edit',
    builder: (context, state) => NoticeFormScreen(noticeId: state.pathParameters['id']!),
  ),
  GoRoute(path: '/my-documents', builder: (context, state) => const MyDocumentsScreen()),
  GoRoute(path: '/onboarding/documents', builder: (context, state) => const OnboardingDocumentsScreen()),
];
