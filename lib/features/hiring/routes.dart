import '../../widgets/ts.dart';
import 'appointment_form.dart';
import 'appointments_screens.dart';
import 'candidates_screens.dart';
import 'interview_panel_screens.dart';
import 'job_form.dart';
import 'jobs_screens.dart';
import 'rounds_screens.dart';

/// Routes for the hiring module. Paths match the web app's URLs exactly, so
/// drawer links and server-action redirects resolve to the same screens.
/// List static paths before parameterised ones (e.g. /x/new before /x/:id).
final List<RouteBase> hiringRoutes = [
  GoRoute(
    path: '/appointments',
    builder: (context, state) => AppointmentsScreen(
      q: state.uri.queryParameters['q'] ?? '',
      status: state.uri.queryParameters['status'] ?? '',
      page: int.tryParse(state.uri.queryParameters['page'] ?? '') ?? 1,
    ),
  ),
  GoRoute(
    path: '/appointments/new',
    builder: (context, state) => NewAppointmentScreen(
      regularizeEmployeeId: state.uri.queryParameters['regularizeEmployeeId'],
      candidateId: state.uri.queryParameters['candidateId'],
    ),
  ),
  GoRoute(
    path: '/appointments/:id',
    builder: (context, state) => AppointmentDetailScreen(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/appointments/:id/edit',
    builder: (context, state) => EditAppointmentScreen(id: state.pathParameters['id']!),
  ),
  GoRoute(path: '/jobs', builder: (context, state) => const JobsScreen()),
  GoRoute(path: '/jobs/new', builder: (context, state) => const NewJobScreen()),
  GoRoute(path: '/jobs/:id', builder: (context, state) => JobDetailScreen(id: state.pathParameters['id']!)),
  GoRoute(path: '/jobs/:id/edit', builder: (context, state) => EditJobScreen(id: state.pathParameters['id']!)),
  GoRoute(
    path: '/jobs/:id/candidates',
    builder: (context, state) => CandidatesScreen(jobId: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/jobs/:id/candidates/:candidateId',
    builder: (context, state) => CandidateDetailScreen(
      jobId: state.pathParameters['id']!,
      candidateId: state.pathParameters['candidateId']!,
    ),
  ),
  GoRoute(
    path: '/jobs/:id/rounds/:roundId/questions',
    builder: (context, state) =>
        McqQuestionsScreen(jobId: state.pathParameters['id']!, roundId: state.pathParameters['roundId']!),
  ),
  GoRoute(
    path: '/jobs/:id/rounds/:roundId/schedule',
    builder: (context, state) =>
        RoundScheduleScreen(jobId: state.pathParameters['id']!, roundId: state.pathParameters['roundId']!),
  ),
  GoRoute(path: '/interview-panel', builder: (context, state) => const InterviewPanelScreen()),
  GoRoute(
    path: '/interview-panel/:panelScoreId',
    builder: (context, state) => PanelScoreScreen(panelScoreId: state.pathParameters['panelScoreId']!),
  ),
];
