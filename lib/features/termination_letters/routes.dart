import '../../widgets/ts.dart';
import 'settlement_screen.dart';
import 'termination_letter_form.dart';
import 'termination_letters_screens.dart';

/// Routes for the Termination Letters module. Paths match the web app's
/// URLs exactly, so the server-driven drawer link (nav-links.ts's
/// "/termination-letters") and server-action redirects resolve to the
/// same screens. List static paths before parameterised ones (e.g.
/// /x/new before /x/:id).
final List<RouteBase> terminationLettersRoutes = [
  GoRoute(path: '/termination-letters', builder: (context, state) => const TerminationLettersScreen()),
  GoRoute(
    path: '/termination-letters/new',
    builder: (context, state) => TerminationLetterFormScreen(employeeId: state.uri.queryParameters['employeeId']),
  ),
  GoRoute(
    path: '/termination-letters/:id/edit',
    builder: (context, state) => TerminationLetterFormScreen(letterId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/termination-letters/:id/settlement',
    builder: (context, state) => SettlementScreen(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/termination-letters/:id',
    builder: (context, state) => TerminationLetterDetailScreen(id: state.pathParameters['id']!),
  ),
];
