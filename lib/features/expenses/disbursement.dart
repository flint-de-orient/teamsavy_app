import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/expenses/disbursement/page.tsx - approved, assigned, unpaid
/// claims: Cashfree "Pay All" (when a payout connection is active), the
/// beneficiary file export, the claim list, then one "Mark as Disbursed"
/// form per claim. HR sees every officer's claims; an officer only theirs.
class DisbursementQueueScreen extends StatelessWidget {
  const DisbursementQueueScreen({super.key});

  static PageHeader _header(bool isHr) => PageHeader(
        title: 'Disbursement Queue',
        description: isHr
            ? 'Every claim assigned to a Disbursement Officer, awaiting payment.'
            : 'Claims assigned to you for NEFT disbursement.',
      );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/expenses/disbursement',
      header: _header(session.me?.isHr ?? false),
      builder: (context, data, reload) {
        final isHr = data.b('isHr');
        final canPayViaApi = data.b('canPayViaApi');
        final claims = data.l('claims');
        final templates = data.l('templates');
        final payableIds = data.list<String>('payableClaimIds');
        return [
          _header(isHr),
          if (canPayViaApi)
            TsCard(
              title: 'Pay via Cashfree',
              child: payableIds.isEmpty
                  ? const Muted('Every claim here has already been paid or is in progress.')
                  : Gap(
                      gap: 12,
                      children: [
                        const Muted(
                          'Pays directly from your connected Cashfree account instead of a manual bank-file upload.',
                        ),
                        _PayAllButton(claimIds: payableIds, totalLabel: data.s('payableTotalLabel')),
                      ],
                    ),
            ),
          TsCard(
            title: 'Beneficiary File Export',
            child: templates.isEmpty
                ? const _NoTemplates()
                : claims.isEmpty
                    ? const Muted('Nothing waiting to be exported.')
                    : _ExportForm(templates: templates),
          ),
          if (claims.isEmpty) const EmptyState('Nothing assigned right now.'),
          for (final c in claims)
            MobileCard(
              onTap: () => context.push('/expenses/${c.s('id')}'),
              children: [
                MobileCardHeader(
                  title: c.s('employeeName'),
                  action: Text(c.s('amountLabel'), style: tx(14, color: Ts.of(context).foreground)),
                ),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Category', value: c.s('categoryLabel')),
                  MobileCardRow(label: 'Date', value: fmtDate(c.at('expenseDate'))),
                  if (isHr) MobileCardRow(label: 'Officer', value: c.sn('officerName') ?? '—'),
                  if (canPayViaApi)
                    MobileCardRow(
                      label: 'Payout',
                      child: TsBadge(c.s('payoutStatus'), tone: badgeToneFrom(c.sn('payoutStatusTone'))),
                    ),
                ]),
                // The web offers "Pay" in its desktop table only; the app is
                // phone-only, so it sits in the card footer here.
                if (canPayViaApi && c.b('canPay'))
                  MobileCardFooter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (c.s('payoutStatus') == 'FAILED') ...[
                          Text(c.sn('payoutErrorMessage') ?? 'Failed', style: tx(12, color: Ts.of(context).danger)),
                          const SizedBox(height: 6),
                        ],
                        ActionButton(
                          label: 'Pay',
                          pendingLabel: 'Paying...',
                          variant: TsButtonVariant.secondary,
                          compact: true,
                          followRedirects: false,
                          confirm: 'Pay ${c.s('employeeName')} ${c.s('amountLabel')} via your connected payout '
                              "provider? This moves real money and can't be undone.",
                          confirmLabel: 'Pay',
                          run: () => api.action('expenses.initiateExpenseClaimPayout', args: [c.s('id')]),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          BorderedSection(
            title: 'Mark as Disbursed',
            description: "Only after you've uploaded the beneficiary file to netbanking and confirmed the transfer "
                'actually cleared - not automatically on download.',
            child: claims.isEmpty
                ? const Muted('Nothing to mark right now.')
                : Gap(
                    gap: 12,
                    children: [
                      for (final c in claims)
                        TsPanel(
                          key: ValueKey(c.s('id')),
                          child: Gap(
                            gap: 12,
                            children: [
                              Text(
                                '${c.s('employeeName')} — ${c.s('amountLabel')}',
                                style: tx(14, weight: FontWeight.w500, color: Ts.of(context).foreground),
                              ),
                              TransferForm(
                                claimId: c.s('id'),
                                action: 'expenses.markExpenseClaimDisbursed',
                                submitLabel: 'Mark as Disbursed',
                                pendingLabel: 'Marking...',
                                successText: 'Marked disbursed.',
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ];
      },
    );
  }
}

class _NoTemplates extends StatelessWidget {
  const _NoTemplates();

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final style = tx(14, color: p.muted, height: 1.5);
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          const TextSpan(text: 'No bank file templates configured yet. '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => context.push('/settings/bank-templates/new'),
              child: Text('Create one', style: style.copyWith(color: p.primary, fontWeight: FontWeight.w500)),
            ),
          ),
          const TextSpan(text: " to export this queue for your bank's net-banking bulk upload."),
        ],
      ),
    );
  }
}

/// The export GET form: pick a template, download the CSV/XLSX through the
/// existing /api/expenses/disbursement/export route.
class _ExportForm extends StatefulWidget {
  const _ExportForm({required this.templates});
  final List<Json> templates;

  @override
  State<_ExportForm> createState() => _ExportFormState();
}

class _ExportFormState extends State<_ExportForm> {
  late String _templateId = widget.templates.first.s('id');
  bool _pending = false;
  String? _error;

  Future<void> _download() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    try {
      await api.openFile('/api/expenses/disbursement/export?templateId=${Uri.encodeQueryComponent(_templateId)}');
    } on ApiException catch (e) {
      _error = e.message;
    }
    if (mounted) setState(() => _pending = false);
  }

  @override
  Widget build(BuildContext context) {
    final ids = widget.templates.map((t) => t.s('id'));
    if (!ids.contains(_templateId)) _templateId = widget.templates.first.s('id');
    return Gap(
      gap: 12,
      children: [
        TsSelect<String>(
          label: 'Template',
          value: _templateId,
          options: [
            for (final t in widget.templates) SelectOption(t.s('id'), '${t.s('name')} (${t.s('fileFormat')})'),
          ],
          onChanged: (v) => setState(() => _templateId = v ?? _templateId),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton(
            label: 'Download Beneficiary File',
            pendingLabel: 'Generating...',
            pending: _pending,
            icon: LucideIcons.download,
            onPressed: _download,
          ),
        ),
        if (_error != null) StatusMessage.error(_error),
      ],
    );
  }
}

/// payout-actions.tsx's PayAllClaimsButton, with the web's confirm text and
/// its "Paid x of y." summary plus one line per skipped claim.
class _PayAllButton extends StatefulWidget {
  const _PayAllButton({required this.claimIds, required this.totalLabel});
  final List<String> claimIds;
  final String totalLabel;

  @override
  State<_PayAllButton> createState() => _PayAllButtonState();
}

class _PayAllButtonState extends State<_PayAllButton> {
  bool _pending = false;
  ActionResult? _result;

  Future<void> _pay() async {
    final n = widget.claimIds.length;
    final ok = await confirmDialog(
      context,
      message: 'Pay all $n claim(s), totalling ${widget.totalLabel}, via your connected payout provider?'
          "\n\nThis moves real money and can't be undone.",
      confirmLabel: 'Pay All ($n)',
    );
    if (!ok || !mounted) return;
    setState(() {
      _pending = true;
      _result = null;
    });
    final r = await runAction(
      context,
      () => api.action('expenses.initiateBulkExpenseClaimPayout', fields: {'claimIds': widget.claimIds}),
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
    final data = r?.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TsButton(
          label: 'Pay All (${widget.claimIds.length})',
          pendingLabel: 'Paying...',
          pending: _pending,
          onPressed: _pay,
        ),
        if (r != null && !r.ok) ...[
          const SizedBox(height: 8),
          StatusMessage.error(r.error),
        ],
        if (r != null && r.ok && data != null && data.b('success')) ...[
          const SizedBox(height: 8),
          StatusMessage.success(
            'Paid ${data.i('paidCount')} of ${data.i('paidCount') + data.i('failedCount')}.',
          ),
          for (final s in data.l('skipped'))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${s.s('employeeName')}: ${s.s('reason')}', style: tx(14, color: p.danger)),
            ),
        ],
      ],
    );
  }
}
