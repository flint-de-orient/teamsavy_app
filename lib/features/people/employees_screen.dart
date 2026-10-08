import '../../widgets/ts.dart';

const _description = 'Everyone on staff, whether onboarded via an offer letter or added directly.';

/// Portal Access badge: user linked -> Active, invite out -> Invited.
TsBadge portalAccessBadge(String access) => switch (access) {
      'ACTIVE' => const TsBadge('Active', tone: BadgeTone.green),
      'INVITED' => const TsBadge('Invited', tone: BadgeTone.amber),
      _ => const TsBadge('Not invited'),
    };

/// app/(app)/employees/page.tsx - HR's staff list with search, status and
/// employment-type filters, 20 per page.
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _q = TextEditingController();
  String _status = '';
  String _employmentType = '';

  // What the list is currently loaded with (the web's GET form applies on
  // "Filter", not on every keystroke).
  Map<String, Object?> _query = const {};

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _apply({int page = 1}) {
    FocusScope.of(context).unfocus();
    setState(() {
      _query = {
        'q': _q.text.trim(),
        'status': _status,
        'employmentType': _employmentType,
        if (page > 1) 'page': page,
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(
      title: 'Employees',
      description: _description,
      actions: [TsButton(label: 'Add Employee', onPressed: () => context.push('/employees/new'))],
    );
    return ApiScreen(
      path: '/employees',
      query: _query,
      header: header,
      builder: (context, data, reload) {
        final employees = data.l('employees');
        return [
          header,
          Gap(
            gap: 12,
            children: [
              TsInput(
                controller: _q,
                placeholder: 'Search by name, email or department',
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _apply(),
                prefix: Icon(LucideIcons.search, size: 16, color: Ts.of(context).muted),
              ),
              TsSelect<String>(
                value: _status,
                options: const [
                  SelectOption('', 'All statuses'),
                  SelectOption('ACTIVE', 'Active'),
                  SelectOption('INACTIVE', 'Inactive'),
                ],
                onChanged: (v) => setState(() => _status = v ?? ''),
              ),
              TsSelect<String>(
                value: _employmentType,
                options: const [
                  SelectOption('', 'All employment types'),
                  SelectOption('PERMANENT', 'Permanent'),
                  SelectOption('INTERN', 'Intern'),
                ],
                onChanged: (v) => setState(() => _employmentType = v ?? ''),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TsButton.secondary(label: 'Filter', icon: LucideIcons.listFilter, onPressed: _apply),
              ),
            ],
          ),
          if (employees.isEmpty) const EmptyState('No employees found.', icon: LucideIcons.users),
          for (final e in employees) _EmployeeCard(e),
          Pagination(
            page: data.i('page', 1),
            pageCount: data.i('totalPages', 1),
            onChanged: (p) => _apply(page: p),
          ),
        ];
      },
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard(this.e);
  final Json e;

  @override
  Widget build(BuildContext context) {
    final active = e.s('status') == 'ACTIVE';
    final intern = e.sn('internBadge');
    return MobileCard(
      onTap: () => context.push('/employees/${e.s('id')}'),
      children: [
        MobileCardHeader(
          title: e.s('name'),
          action: TsBadge(active ? 'Active' : 'Inactive', tone: active ? BadgeTone.green : BadgeTone.slate),
        ),
        if (intern != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Align(alignment: Alignment.centerLeft, child: TsBadge(intern, tone: BadgeTone.purple)),
          ),
        MobileCardRows(rows: [
          MobileCardRow(label: 'Designation', value: e.s('designation')),
          MobileCardRow(label: 'Department', value: e.s('department')),
          MobileCardRow(label: 'Portal Access', child: portalAccessBadge(e.s('portalAccess'))),
        ]),
      ],
    );
  }
}
