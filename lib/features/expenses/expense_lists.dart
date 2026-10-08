import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/expenses/page.tsx - the employee's own claims, newest first.
class MyExpensesScreen extends StatelessWidget {
  const MyExpensesScreen({super.key});

  static PageHeader _header(BuildContext context) => PageHeader(
        title: 'My Expenses',
        description: 'Your expense claim history.',
        actions: [
          TsButton(label: 'Submit a Claim', icon: LucideIcons.plus, onPressed: () => context.push('/expenses/new')),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/expenses',
      header: _header(context),
      builder: (context, data, reload) {
        final claims = data.l('claims');
        return [
          _header(context),
          if (!data.b('hasManager'))
            const StatusMessage(
              'No reporting manager is linked to your record yet — your claims go straight to HR.',
              kind: StatusKind.warning,
            ),
          if (claims.isEmpty) const EmptyState('No expense claims yet.'),
          for (final c in claims)
            MobileCard(
              onTap: () => context.push('/expenses/${c.s('id')}'),
              children: [
                MobileCardHeader(
                  title: c.s('categoryLabel'),
                  action: TsBadge(c.s('statusLabel'), tone: badgeToneFrom(c.sn('statusTone'))),
                ),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Description', child: ClampedValue(c.s('description'))),
                  MobileCardRow(label: 'Amount', value: rupee(c.at('amount'))),
                  MobileCardRow(label: 'Date', value: fmtDate(c.at('expenseDate'))),
                ]),
              ],
            ),
        ];
      },
    );
  }
}

/// app/(app)/expenses/approvals/page.tsx - direct reports' claims waiting
/// on the manager, oldest first.
class ExpenseApprovalsScreen extends StatelessWidget {
  const ExpenseApprovalsScreen({super.key});

  static const _header = PageHeader(
    title: 'Expense Approvals',
    description: "Your direct reports' pending expense claims.",
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/expenses/approvals',
      header: _header,
      builder: (context, data, reload) {
        final claims = data.l('claims');
        return [
          _header,
          if (claims.isEmpty) const EmptyState('Nothing pending your approval.'),
          for (final c in claims)
            MobileCard(
              onTap: () => context.push('/expenses/${c.s('id')}'),
              children: [
                MobileCardHeader(title: c.s('employeeName')),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Category', value: c.s('categoryLabel')),
                  MobileCardRow(label: 'Amount', value: rupee(c.at('amount'))),
                  MobileCardRow(label: 'Date', value: fmtDate(c.at('expenseDate'))),
                ]),
              ],
            ),
        ];
      },
    );
  }
}

/// app/(app)/expenses/queue/page.tsx - every pending claim company-wide,
/// then the approved claims awaiting a Disbursement Officer.
class ExpenseQueueScreen extends StatelessWidget {
  const ExpenseQueueScreen({super.key});

  static const _header = PageHeader(
    title: 'Expense Queue',
    description: 'Every claim currently pending, company-wide.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/expenses/queue',
      header: _header,
      builder: (context, data, reload) {
        final claims = data.l('claims');
        return [
          _header,
          if (claims.isEmpty) const EmptyState('Nothing pending.'),
          for (final c in claims)
            MobileCard(
              onTap: () => context.push('/expenses/${c.s('id')}'),
              children: [
                MobileCardHeader(
                  title: c.s('employeeName'),
                  action: TsBadge(c.s('statusLabel'), tone: badgeToneFrom(c.sn('statusTone'))),
                ),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Category', value: c.s('categoryLabel')),
                  MobileCardRow(label: 'Amount', value: rupee(c.at('amount'))),
                  MobileCardRow(label: 'Date', value: fmtDate(c.at('expenseDate'))),
                ]),
              ],
            ),
          BorderedSection(
            title: 'Awaiting Disbursement Assignment',
            description: 'Approved claims not yet assigned to a Disbursement Officer for payment.',
            child: _AssignDisbursementForm(
              claims: data.l('unassignedApproved'),
              officers: data.l('officers'),
            ),
          ),
        ];
      },
    );
  }
}

/// queue/assign-disbursement-form.tsx.
class _AssignDisbursementForm extends StatefulWidget {
  const _AssignDisbursementForm({required this.claims, required this.officers});
  final List<Json> claims;
  final List<Json> officers;

  @override
  State<_AssignDisbursementForm> createState() => _AssignDisbursementFormState();
}

class _AssignDisbursementFormState extends State<_AssignDisbursementForm> {
  final Set<String> _selected = {};
  String? _officerId;
  bool _pending = false;
  String? _error;
  String? _success;

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
      _success = null;
    });
    // Only ids still on the (possibly reloaded) list are posted.
    final ids = widget.claims.map((c) => c.s('id')).where(_selected.contains).toList();
    final r = await runAction(
      context,
      () => api.action(
        'expenses.assignDisbursementOfficer',
        fields: {'claimIds': ids, 'disbursementOfficerId': _officerId ?? ''},
      ),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      if (r.ok) {
        _success = 'Assigned ${r.data?.i('count') ?? ids.length} claim(s).';
        _selected.clear();
        _officerId = null;
      }
    });
    if (r.ok) toast(context, _success!);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.claims.isEmpty) {
      return const Muted('No approved claims are waiting for disbursement assignment.');
    }
    return TsCard(
      child: Gap(
        gap: 12,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final c in widget.claims)
                TsCheckbox(
                  label: '${c.s('employeeName')} — ${c.s('amount')}',
                  value: _selected.contains(c.s('id')),
                  onChanged: (v) => setState(() {
                    if (v) {
                      _selected.add(c.s('id'));
                    } else {
                      _selected.remove(c.s('id'));
                    }
                  }),
                ),
            ],
          ),
          TsSelect<String>(
            label: 'Disbursement Officer',
            value: _officerId,
            placeholder: 'Choose...',
            options: [for (final o in widget.officers) SelectOption(o.s('id'), o.s('name'))],
            onChanged: (v) => setState(() => _officerId = v),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton(
              label: 'Assign Disbursement Officer',
              pendingLabel: 'Assigning...',
              pending: _pending,
              onPressed: _submit,
            ),
          ),
          if (_error != null) StatusMessage.error(_error),
          if (_success != null) StatusMessage.success(_success),
          if (widget.officers.isEmpty)
            const Muted(
              'No employees are tagged as a Disbursement Officer yet - tag one from their employee record first.',
            ),
        ],
      ),
    );
  }
}

/// app/(app)/expenses/history/page.tsx - every claim ever submitted, with
/// the web's GET status filter (applied on "Filter", not on change).
class ExpenseHistoryScreen extends StatefulWidget {
  const ExpenseHistoryScreen({super.key, this.status});
  final String? status;

  @override
  State<ExpenseHistoryScreen> createState() => _ExpenseHistoryScreenState();
}

class _ExpenseHistoryScreenState extends State<ExpenseHistoryScreen> {
  static const _header = PageHeader(
    title: 'Expense History',
    description: 'Every claim ever submitted, company-wide - including already-paid ones.',
  );

  late String _applied = widget.status ?? 'ALL';
  late String _choice = _applied;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/expenses/history',
      query: {'status': _applied == 'ALL' ? null : _applied},
      header: _header,
      builder: (context, data, reload) {
        final claims = data.l('claims');
        return [
          _header,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TsSelect<String>(
                  label: 'Status',
                  value: _choice,
                  options: [for (final o in data.l('statusOptions')) SelectOption(o.s('value'), o.s('label'))],
                  onChanged: (v) => setState(() => _choice = v ?? 'ALL'),
                ),
              ),
              const SizedBox(width: 12),
              TsButton.secondary(label: 'Filter', onPressed: () => setState(() => _applied = _choice)),
            ],
          ),
          if (claims.isEmpty) const EmptyState('No claims match this filter.'),
          for (final c in claims)
            MobileCard(
              onTap: () => context.push('/expenses/${c.s('id')}'),
              children: [
                MobileCardHeader(
                  title: c.s('employeeName'),
                  action: TsBadge(c.s('statusLabel'), tone: badgeToneFrom(c.sn('statusTone'))),
                ),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Category', value: c.s('categoryLabel')),
                  MobileCardRow(label: 'Amount', value: rupee(c.at('amount'))),
                  MobileCardRow(label: 'Date', value: fmtDate(c.at('expenseDate'))),
                  MobileCardRow(label: 'Reimbursement', value: c.sn('reimbursementLabel') ?? '—'),
                ]),
              ],
            ),
        ];
      },
    );
  }
}
