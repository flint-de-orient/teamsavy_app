import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/expenses/[id]/page.tsx - the claim's Details (its only history
/// view) and whichever action cards the viewer's role and the claim's
/// status allow: Manager Approval, HR Approval (with partial approval),
/// Reimbursement and Cancel.
class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/expenses/$id',
      builder: (context, data, reload) {
        final requested = data.i('amount');
        return [
          PageHeader(
            title: data.s('title'),
            description: data.s('subtitle'),
            actions: [TsBadge(data.s('statusLabel'), tone: badgeToneFrom(data.sn('statusTone')))],
          ),
          TsCard(
            title: 'Details',
            child: DetailList(rows: [
              DetailRow(label: 'Description', value: data.s('description')),
              if (data.sn('receiptUrl') != null)
                DetailRow(label: 'Receipt', child: _ReceiptLink(path: data.s('receiptUrl'))),
              if (data.sn('managerDecision') != null)
                DetailRow(label: 'Manager Decision', value: data.s('managerDecision')),
              if (data.sn('hrDecision') != null) DetailRow(label: 'HR Decision', value: data.s('hrDecision')),
              if (data.sn('approvedAmountLabel') != null)
                DetailRow(
                  label: 'Approved Amount',
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TsBadge(data.s('approvedAmountLabel'), tone: BadgeTone.amber),
                  ),
                ),
              if (data.sn('disbursementOfficerName') != null)
                DetailRow(label: 'Disbursement Officer', value: data.s('disbursementOfficerName')),
              if (data.sn('reimbursed') != null) DetailRow(label: 'Reimbursed', value: data.s('reimbursed')),
            ]),
          ),
          if (data.b('canManagerAct'))
            TsCard(
              title: 'Manager Approval',
              child: _ApproveRejectPanel(
                claimId: id,
                approveAction: 'expenses.approveExpenseClaimAsManager',
                rejectAction: 'expenses.rejectExpenseClaimAsManager',
              ),
            ),
          if (data.b('canHrAct'))
            TsCard(
              title: 'HR Approval',
              child: _ApproveRejectPanel(
                claimId: id,
                approveAction: 'expenses.approveExpenseClaimAsHr',
                rejectAction: 'expenses.rejectExpenseClaimAsHr',
                requestedAmount: requested,
              ),
            ),
          if (data.b('canMarkReimbursed'))
            TsCard(
              title: 'Reimbursement',
              description: "Only needed if you're paying this outside the next payroll run.",
              child: TransferForm(
                claimId: id,
                action: 'expenses.markExpenseClaimReimbursed',
                submitLabel: 'Mark as Reimbursed',
                pendingLabel: 'Saving...',
                variant: TsButtonVariant.secondary,
              ),
            ),
          if (data.b('canCancel'))
            TsCard(
              title: 'Cancel',
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionButton(
                  label: 'Cancel Claim',
                  pendingLabel: 'Cancelling...',
                  variant: TsButtonVariant.danger,
                  followRedirects: false,
                  run: () => api.action('expenses.cancelExpenseClaim', args: [id]),
                ),
              ),
            ),
        ];
      },
    );
  }
}

/// "View Receipt" - downloads /api/expenses/{id}/receipt with the session
/// token and opens it in the device viewer (the web opens a new tab).
class _ReceiptLink extends StatefulWidget {
  const _ReceiptLink({required this.path});
  final String path;

  @override
  State<_ReceiptLink> createState() => _ReceiptLinkState();
}

class _ReceiptLinkState extends State<_ReceiptLink> {
  bool _opening = false;

  Future<void> _open() async {
    setState(() => _opening = true);
    try {
      await api.openFile(widget.path);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TsLink('View Receipt', onTap: _opening ? null : _open),
        if (_opening) ...[
          const SizedBox(width: 8),
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: p.primary)),
        ],
      ],
    );
  }
}

/// expense-claim-actions.tsx's ApproveRejectPanel: an Approve form (with
/// the partial "Approved Amount" field on HR's panel only) and a Reject
/// form whose note is the required reason. One error line under both.
class _ApproveRejectPanel extends StatefulWidget {
  const _ApproveRejectPanel({
    required this.claimId,
    required this.approveAction,
    required this.rejectAction,
    this.requestedAmount,
  });

  final String claimId;
  final String approveAction;
  final String rejectAction;
  final int? requestedAmount;

  @override
  State<_ApproveRejectPanel> createState() => _ApproveRejectPanelState();
}

class _ApproveRejectPanelState extends State<_ApproveRejectPanel> {
  final _approvedAmount = TextEditingController();
  final _approveNote = TextEditingController();
  final _rejectNote = TextEditingController();
  bool _approving = false;
  bool _rejecting = false;
  String? _error;

  @override
  void dispose() {
    _approvedAmount.dispose();
    _approveNote.dispose();
    _rejectNote.dispose();
    super.dispose();
  }

  Future<void> _run({required bool approve}) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _approving = approve;
      _rejecting = !approve;
      _error = null;
    });
    final fields = approve
        ? {
            if (widget.requestedAmount != null) 'approvedAmount': _approvedAmount.text.trim(),
            'note': _approveNote.text,
          }
        : {'note': _rejectNote.text};
    final r = await runAction(
      context,
      () => api.action(approve ? widget.approveAction : widget.rejectAction, args: [widget.claimId], fields: fields),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _approving = false;
      _rejecting = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final requested = widget.requestedAmount;
    final busy = _approving || _rejecting;
    return Gap(
      gap: 16,
      children: [
        TsPanel(
          child: Gap(
            gap: 12,
            children: [
              if (requested != null)
                TsInput(
                  controller: _approvedAmount,
                  label: 'Approved Amount (optional - leave blank to approve the full ${rupee(requested)})',
                  placeholder: '$requested',
                  keyboardType: TextInputType.number,
                  inputFormatters: TsInput.digitsOnly,
                ),
              TsTextarea(controller: _approveNote, label: 'Note (optional)', rows: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: TsButton(
                  label: 'Approve',
                  pendingLabel: 'Approving...',
                  pending: _approving,
                  onPressed: busy ? null : () => _run(approve: true),
                ),
              ),
            ],
          ),
        ),
        TsPanel(
          child: Gap(
            gap: 12,
            children: [
              TsTextarea(controller: _rejectNote, label: 'Reason (required to reject)', rows: 2),
              Align(
                alignment: Alignment.centerLeft,
                child: TsButton.danger(
                  label: 'Reject',
                  pendingLabel: 'Rejecting...',
                  pending: _rejecting,
                  onPressed: busy ? null : () => _run(approve: false),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) StatusMessage.error(_error),
      ],
    );
  }
}
