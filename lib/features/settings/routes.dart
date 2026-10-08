import '../../widgets/ts.dart';
import 'company_settings_screen.dart';
import 'id_card_screen.dart';
import 'policy_settings_screen.dart';

/// Routes for the settings module. Paths match the web app's URLs exactly, so
/// drawer links and server-action redirects resolve to the same screens.
/// List static paths before parameterised ones (e.g. /x/new before /x/:id).
final List<RouteBase> settingsRoutes = [
  GoRoute(path: '/settings/company', builder: (context, state) => const CompanySettingsScreen()),
  GoRoute(path: '/settings/policy', builder: (context, state) => const PolicySettingsScreen()),
  GoRoute(path: '/settings/id-card', builder: (context, state) => const IdCardSettingsScreen()),
];
