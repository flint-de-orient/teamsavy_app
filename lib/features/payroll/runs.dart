import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/payroll/runs/page.tsx
class PayrollRunsScreen extends StatelessWidget {
  const PayrollRunsScreen({super.key});

  static const _header = PageHeader(
    title: 'Payroll Runs',
    description:
        "Process a month's payroll for every eligible employee at once, generating a Payslip each. Re-processing a run that isn't locked yet safely recomputes everything from scratch.",
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/payroll/runs',
      header: _header,
      builder: (context, data, reload) {
        final runs = data.l('runs');
        return [
          _header,
          Block(
            child: ProcessRunForm(
              key: const ValueKey('process-runs-page'),
              defaultMonth: data.s('currentMonth', currentMonthValue()),
              employees: data.l('employees'),
            ),
          ),
          const Block(child: SendTaxRegimeRemindersButton()),
          if (runs.isEmpty) const EmptyState('No payroll runs yet.', icon: LucideIcons.banknote),
          for (final r in runs)
            MobileCard(
              onTap: () => context.push('/payroll/runs/${r.s('id')}'),
              children: [
                MobileCardHeader(
                  title: r.s('month'),
                  subtitle: monthLabel(r.s('month')),
                  action: runStatusBadge(r.s('status')),
                ),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Employees', value: r.sn('employeeCount') ?? '—'),
                  MobileCardRow(label: 'Total Gross', value: inrOrDash(r.at('totalGross'))),
                  MobileCardRow(label: 'Total Net', value: inrOrDash(r.at('totalNet'))),
                ]),
              ],
            ),
        ];
      },
    );
  }
}

/// run-actions.tsx's ProcessRunForm: month picker, the optional "exclude
/// from this run" checklist (unchecked by default, or pre-checked from a
/// run's saved exclusions), Process button and the result box.
class ProcessRunForm extends StatefulWidget {
  const ProcessRunForm({
    super.key,
    required this.defaultMonth,
    required this.employees,
    this.buttonLabel = 'Process Run',
    this.defaultExcludedIds = const [],
  });

  final String defaultMonth;
  final List<Json> employees;
  final String buttonLabel;
  final List<String> defaultExcludedIds;

  @override
  State<ProcessRunForm> createState() => _ProcessRunFormState();
}

class _ProcessRunFormState extends State<ProcessRunForm> {
  late String _month = widget.defaultMonth;
  late final Set<String> _excluded = {...widget.defaultExcludedIds};
  bool _showEmployees = false;
  bool _pending = false;
  ActionResult? _result;

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _result = null;
    });
    final r = await runAction(
      context,
      () => api.action('payroll.processPayrollRun', fields: {'month': _month, 'excludedEmployeeIds': _excluded.toList()}),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _result = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final r = _result;
    return Gap(
      gap: 12,
      children: [
        TsMonthField(label: 'Month', value: _month, onChanged: (v) => setState(() => _month = v)),
        TsButton(
          label: widget.buttonLabel,
          pendingLabel: 'Processing...',
          pending: _pending,
          icon: LucideIcons.play,
          expand: true,
          onPressed: _submit,
        ),
        if (widget.employees.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TsLink(
              '${_excluded.isNotEmpty ? '${_excluded.length} excluded - ' : ''}'
              '${_showEmployees ? 'Hide employees' : 'Exclude employees...'}',
              onTap: () => setState(() => _showEmployees = !_showEmployees),
            ),
          ),
        if (_showEmployees)
          TsPanel(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Check anyone to exclude from this run - they'll get no payslip this month.",
                    style: tx(12, color: p.muted, height: 1.5)),
                const SizedBox(height: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final e in widget.employees)
                          TsCheckbox(
                            label: e.s('name'),
                            value: _excluded.contains(e.s('id')),
                            onChanged: (v) => setState(() => v ? _excluded.add(e.s('id')) : _excluded.remove(e.s('id'))),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (r != null && !r.ok) StatusMessage.error(r.error),
        if (r != null && r.ok && r.data != null)
          SkippedResult(
            headline: 'Processed ${r.data!.i('processedCount')} payslip${r.data!.i('processedCount') == 1 ? '' : 's'}.',
            skipped: r.data!.l('skipped'),
          ),
      ],
    );
  }
}

/// run-actions.tsx's SendTaxRegimeRemindersButton.
class SendTaxRegimeRemindersButton extends StatefulWidget {
  const SendTaxRegimeRemindersButton({super.key});

  @override
  State<SendTaxRegimeRemindersButton> createState() => _SendTaxRegimeRemindersButtonState();
}

class _SendTaxRegimeRemindersButtonState extends State<SendTaxRegimeRemindersButton> {
  bool _pending = false;
  ActionResult? _result;

  Future<void> _send() async {
    setState(() {
      _pending = true;
      _result = null;
    });
    final r = await api.action('payroll.sendTaxRegimeReminders');
    if (!mounted) return;
    setState(() {
      _pending = false;
      _result = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return Gap(
      gap: 10,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TsButton.secondary(
          label: 'Send Tax Regime Reminders',
          pendingLabel: 'Checking...',
          pending: _pending,
          icon: LucideIcons.messageCircle,
          onPressed: _send,
        ),
        const Muted(
          "WhatsApps anyone who hasn't confirmed their Tax Regime for this FY and would owe tax either way. Doesn't block payroll processing.",
          size: 12,
        ),
        if (r != null && !r.ok) StatusMessage.error(r.error),
        if (r != null && r.ok && r.data != null)
          SkippedResult(
            headline: 'Sent ${r.data!.i('sentCount')} reminder${r.data!.i('sentCount') == 1 ? '' : 's'}.',
            skipped: r.data!.l('skipped'),
          ),
      ],
    );
  }
}

/// app/(app)/payroll/runs/[id]/page.tsx
class PayrollRunScreen extends StatelessWidget {
  const PayrollRunScreen({super.key, required this.id});
  final String id;

  static const _description =
      "One Payslip per eligible employee, computed from Attendance, Leave Encashment, PF/ESI/Professional Tax/Tax settings, and each employee's Pay Band.";

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/payroll/runs/$id',
      header: const PageHeader(title: 'Payroll Run', description: _description),
      builder: (context, data, reload) {
        final run = data.m('run');
        final status = run.s('status');
        final payslips = data.l('payslips');
        final canExport = data.b('canExportBankFile');
        final payoutActive = data.b('payoutActive');
        final count = run.i('employeeCount');
        return [
          PageHeader(
            title: 'Payroll Run — ${run.s('month')}',
            description: _description,
            actions: [runStatusBadge(status)],
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.75,
            children: [
              _RunStat(label: 'Employees', value: run.sn('employeeCount') ?? '—', icon: LucideIcons.users, tone: CardTone.info),
              _RunStat(label: 'Total Gross', value: inrOrDash(run.at('totalGross')), icon: LucideIcons.trendingUp, tone: CardTone.success),
              _RunStat(
                label: 'Total Deductions',
                value: inrOrDash(run.at('totalDeductions')),
                icon: LucideIcons.trendingDown,
                tone: CardTone.warning,
              ),
              _RunStat(label: 'Total Net', value: inrOrDash(run.at('totalNet')), icon: LucideIcons.wallet, tone: CardTone.purple),
            ],
          ),
          if (status != 'LOCKED')
            Block(
              title: status == 'DRAFT' ? 'Process this run' : 'Re-process this run',
              child: ProcessRunForm(
                key: ValueKey('process-$id'),
                defaultMonth: run.s('month'),
                buttonLabel: status == 'DRAFT' ? 'Process Run' : 'Re-process Run',
                employees: data.l('activeEmployees'),
                defaultExcludedIds: run.list<String>('excludedEmployeeIds'),
              ),
            ),
          if (status == 'PROCESSED')
            NoticeBox(
              kind: StatusKind.error,
              title: 'Reverse this run',
              text:
                  "Deletes all $count payslip${count == 1 ? '' : 's'} and returns this run to Draft so you can fix the underlying data (attendance, pay bands, tax declarations) before processing again. Doesn't affect any other month's run.",
              child: ActionButton(
                label: 'Reverse Run',
                pendingLabel: 'Reversing...',
                variant: TsButtonVariant.danger,
                icon: LucideIcons.undo2,
                followRedirects: false,
                run: () => api.action('payroll.reversePayrollRun', args: [id]),
              ),
            ),
          if (status == 'PROCESSED')
            NoticeBox(
              title: 'Lock this run',
              text:
                  "Locking makes every payslip in this run permanent - it can no longer be re-processed. Corrections after locking must go into a later month's run instead.",
              child: ActionButton(
                label: 'Lock Run',
                pendingLabel: 'Locking...',
                variant: TsButtonVariant.danger,
                icon: LucideIcons.lock,
                followRedirects: false,
                run: () => api.action('payroll.lockPayrollRun', args: [id]),
              ),
            ),
          if (payslips.isNotEmpty && canExport)
            Block(
              title: 'Payslips',
              child: Align(
                alignment: Alignment.centerLeft,
                child: TsButton.secondary(
                  label: 'Download All Payslips (PDF)',
                  icon: LucideIcons.fileDown,
                  onPressed: () => openPayrollFile(context, '/api/payroll/runs/$id/payslips-pdf'),
                ),
              ),
            ),
          if (status == 'LOCKED' && canExport && payoutActive)
            Block(
              title: 'Pay via Cashfree',
              child: data.i('payableCount') == 0
                  ? const Muted('Every payslip in this run has already been paid or is in progress.')
                  : Gap(
                      gap: 12,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Muted(
                          'Pays directly from your connected Cashfree account instead of a manual bank-file upload - see the Payout Status column below for each employee.',
                        ),
                        _PayAllButton(runId: id, count: data.i('payableCount'), total: data.at('payableTotal')),
                      ],
                    ),
            ),
          if (status == 'LOCKED' && canExport) Block(title: 'Bank File Export', child: _BankExport(runId: id, templates: data.l('bankTemplates'))),
          if (payslips.isEmpty) const EmptyState('No payslips yet - process this run above.', icon: LucideIcons.receipt),
          for (final s in payslips) _PayslipCard(slip: s, payoutActive: payoutActive),
        ];
      },
    );
  }
}

class _RunStat extends StatelessWidget {
  const _RunStat({required this.label, required this.value, required this.icon, required this.tone});
  final String label;
  final String value;
  final IconData icon;
  final CardTone tone;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TsCard.toneBg(p, tone),
        borderRadius: BorderRadius.circular(Ts.r2xl),
        boxShadow: p.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: TsCard.toneSolid(p, tone)),
              const SizedBox(width: 6),
              Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(12, color: p.muted))),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: tx(18, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
          ),
        ],
      ),
    );
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({required this.slip, required this.payoutActive});
  final Json slip;
  final bool payoutActive;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final status = slip.s('payoutStatus');
    final payable = status == 'NOT_INITIATED' || status == 'FAILED';
    final warnings = slip.i('warningCount');
    return MobileCard(
      onTap: () => context.push('/payroll/payslips/${slip.s('id')}'),
      children: [
        MobileCardHeader(title: slip.s('employeeName'), action: Icon(LucideIcons.chevronRight, size: 18, color: p.muted)),
        MobileCardRows(rows: [
          MobileCardRow(label: 'Gross', value: inr(slip.at('gross'))),
          MobileCardRow(label: 'Deductions', value: inr(slip.at('deductions'))),
          MobileCardRow(label: 'Net Pay', value: inr(slip.at('netPay'))),
          MobileCardRow(
            label: 'Warnings',
            value: warnings > 0 ? null : '—',
            child: warnings > 0 ? TsBadge('$warnings', tone: BadgeTone.amber) : null,
          ),
          if (payoutActive)
            MobileCardRow(label: 'Payout', child: TsBadge(status, tone: payoutStatusTone[status] ?? BadgeTone.slate)),
        ]),
        if (payoutActive && payable)
          MobileCardFooter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (status == 'FAILED')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(slip.sn('payoutErrorMessage') ?? 'Failed', style: tx(12, color: p.danger)),
                  ),
                ActionButton(
                  label: 'Pay',
                  pendingLabel: 'Paying...',
                  variant: TsButtonVariant.secondary,
                  compact: true,
                  followRedirects: false,
                  confirm:
                      "Pay ${slip.s('employeeName')} ${inr(slip.at('netPay'))} via your connected payout provider? This moves real money and can't be undone.",
                  run: () => api.action('payroll.initiatePayslipPayout', args: [slip.s('id')]),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// payout-actions.tsx's PayAllPayslipsButton, with its result lines.
class _PayAllButton extends StatefulWidget {
  const _PayAllButton({required this.runId, required this.count, required this.total});
  final String runId;
  final int count;
  final Object? total;

  @override
  State<_PayAllButton> createState() => _PayAllButtonState();
}

class _PayAllButtonState extends State<_PayAllButton> {
  bool _pending = false;
  ActionResult? _result;

  Future<void> _pay() async {
    final ok = await confirmDialog(
      context,
      message:
          "Pay all ${widget.count} remaining employee(s), totalling ${inr(widget.total)}, via your connected payout provider?\n\nThis moves real money and can't be undone.",
      confirmLabel: 'Pay All (${widget.count})',
    );
    if (!ok || !mounted) return;
    setState(() {
      _pending = true;
      _result = null;
    });
    final r = await runAction(context, () => api.action('payroll.initiateBulkPayslipPayout', args: [widget.runId]),
        followRedirects: false);
    if (!mounted) return;
    setState(() {
      _pending = false;
      _result = r;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final r = _result;
    final paid = r?.data?.i('paidCount') ?? 0;
    final failed = r?.data?.i('failedCount') ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TsButton(
          label: 'Pay All (${widget.count})',
          pendingLabel: 'Paying...',
          pending: _pending,
          icon: LucideIcons.send,
          onPressed: _pay,
        ),
        if (r != null && !r.ok) Padding(padding: const EdgeInsets.only(top: 8), child: StatusMessage.error(r.error)),
        if (r != null && r.ok && r.data != null) ...[
          const SizedBox(height: 8),
          Text('Paid $paid of ${paid + failed}.', style: tx(14, color: p.success)),
          for (final s in r.data!.l('skipped'))
            Text('${s.s('employeeName')}: ${s.s('reason')}', style: tx(14, color: p.danger)),
        ],
      ],
    );
  }
}

/// The "Bank File Export" card: template select + Download (a GET to the
/// bank-export route), or the "Create one" prompt.
class _BankExport extends StatefulWidget {
  const _BankExport({required this.runId, required this.templates});
  final String runId;
  final List<Json> templates;

  @override
  State<_BankExport> createState() => _BankExportState();
}

class _BankExportState extends State<_BankExport> {
  String? _templateId;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    if (widget.templates.isEmpty) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('No bank file templates configured yet. ', style: tx(14, color: p.muted, height: 1.5)),
          TsLink('Create one', onTap: () => context.push('/settings/bank-templates/new')),
          Text(" to export this run for your bank's net-banking bulk salary upload.", style: tx(14, color: p.muted, height: 1.5)),
        ],
      );
    }
    final ids = widget.templates.map((t) => t.s('id')).toList();
    final selected = _templateId != null && ids.contains(_templateId) ? _templateId! : ids.first;
    return Gap(
      gap: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TsSelect<String>(
          label: 'Template',
          value: selected,
          options: [
            for (final t in widget.templates) SelectOption(t.s('id'), '${t.s('name')} (${t.s('fileFormat')})'),
          ],
          onChanged: (v) => setState(() => _templateId = v),
        ),
        DownloadButton(
          key: ValueKey(selected),
          label: 'Download',
          secondary: true,
          path: '/api/payroll/runs/${widget.runId}/bank-export?templateId=$selected',
        ),
      ],
    );
  }
}
