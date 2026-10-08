import '../../widgets/ts.dart';
import 'payslips.dart';
import 'returns.dart';
import 'runs.dart';
import 'settings.dart';
import 'tax.dart';
import 'templates.dart';

/// Routes for the payroll module. Paths match the web app's URLs exactly, so
/// drawer links and server-action redirects resolve to the same screens.
/// List static paths before parameterised ones (e.g. /x/new before /x/:id).
final List<RouteBase> payrollRoutes = [
  // Employee self-service
  GoRoute(path: '/payroll/payslips', builder: (context, state) => const MyPayslipsScreen()),
  GoRoute(
    path: '/payroll/payslips/:id',
    builder: (context, state) => PayslipScreen(id: state.pathParameters['id']!),
  ),
  GoRoute(path: '/payroll/tax-declarations', builder: (context, state) => const TaxDeclarationsScreen()),

  // HR
  GoRoute(path: '/payroll/runs', builder: (context, state) => const PayrollRunsScreen()),
  GoRoute(
    path: '/payroll/runs/:id',
    builder: (context, state) => PayrollRunScreen(id: state.pathParameters['id']!),
  ),
  GoRoute(
    path: '/payroll/tax-preview',
    builder: (context, state) => TaxPreviewScreen(
      employeeId: state.uri.queryParameters['employeeId'],
      month: state.uri.queryParameters['month'],
    ),
  ),
  GoRoute(path: '/payroll/returns', builder: (context, state) => const StatutoryReturnsScreen()),
  GoRoute(
    path: '/payroll/returns/pf',
    builder: (context, state) => PfReturnScreen(month: state.uri.queryParameters['month']),
  ),
  GoRoute(
    path: '/payroll/returns/esi',
    builder: (context, state) => EsiReturnScreen(month: state.uri.queryParameters['month']),
  ),
  GoRoute(
    path: '/payroll/returns/professional-tax',
    builder: (context, state) => PtReturnScreen(
      month: state.uri.queryParameters['month'],
      state: state.uri.queryParameters['state'],
      templateId: state.uri.queryParameters['templateId'],
    ),
  ),
  GoRoute(
    path: '/payroll/returns/tds',
    builder: (context, state) => TdsReturnScreen(
      period: state.uri.queryParameters['period'],
      fy: state.uri.queryParameters['fy'],
    ),
  ),

  // Payroll settings
  GoRoute(path: '/settings/pf', builder: (context, state) => const PfSettingsScreen()),
  GoRoute(path: '/settings/esi', builder: (context, state) => const EsiSettingsScreen()),
  GoRoute(path: '/settings/tax', builder: (context, state) => const TaxSettingsScreen()),
  GoRoute(path: '/settings/professional-tax', builder: (context, state) => const ProfessionalTaxScreen()),
  GoRoute(path: '/settings/statutory-returns', builder: (context, state) => const StatutoryReturnSettingsScreen()),
  GoRoute(path: '/settings/payout', builder: (context, state) => const PayoutSettingsScreen()),
  GoRoute(path: '/settings/bank-templates', builder: (context, state) => const BankTemplatesScreen()),
  GoRoute(
    path: '/settings/bank-templates/new',
    builder: (context, state) => const TemplateFormScreen(kind: TemplateKind.bank),
  ),
  GoRoute(
    path: '/settings/bank-templates/:id/edit',
    builder: (context, state) => TemplateFormScreen(kind: TemplateKind.bank, id: state.pathParameters['id']),
  ),
  GoRoute(path: '/settings/return-templates', builder: (context, state) => const ReturnTemplatesScreen()),
  GoRoute(
    path: '/settings/return-templates/new',
    builder: (context, state) => const TemplateFormScreen(kind: TemplateKind.ptReturn),
  ),
  GoRoute(
    path: '/settings/return-templates/:id/edit',
    builder: (context, state) => TemplateFormScreen(kind: TemplateKind.ptReturn, id: state.pathParameters['id']),
  ),
];
