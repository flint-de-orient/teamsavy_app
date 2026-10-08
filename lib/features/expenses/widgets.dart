import '../../widgets/ts.dart';

/// TRANSFER_MODE_OPTIONS from the web's reimbursement and disbursement forms.
const kTransferModes = ['NEFT', 'RTGS', 'IMPS', 'UPI', 'Cash', 'Cheque', 'Other'];

/// The web's `mt-8 border-t border-border pt-6` block with an `<h2>` and a
/// muted sub-line ("Awaiting Disbursement Assignment", "Mark as Disbursed").
class BorderedSection extends StatelessWidget {
  const BorderedSection({super.key, required this.title, this.description, required this.child});
  final String title;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 24),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title, description: description, top: 0),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

/// The transfer details form shared by "Mark as Reimbursed" (claim detail)
/// and "Mark as Disbursed" (disbursement queue): Mode of Transfer,
/// Transaction Reference No / UTR No, Disbursement Date (today) and an
/// optional note, posted to an action bound to the claim id.
class TransferForm extends StatefulWidget {
  const TransferForm({
    super.key,
    required this.claimId,
    required this.action,
    required this.submitLabel,
    required this.pendingLabel,
    this.variant = TsButtonVariant.primary,
    this.successText,
  });

  final String claimId;
  final String action;
  final String submitLabel;
  final String pendingLabel;
  final TsButtonVariant variant;

  /// Shown under the button (and toasted, since a successful submit usually
  /// removes this claim's form from the reloaded page).
  final String? successText;

  @override
  State<TransferForm> createState() => _TransferFormState();
}

class _TransferFormState extends State<TransferForm> {
  final _reference = TextEditingController();
  final _note = TextEditingController();
  String _mode = 'NEFT';
  String? _date = todayValue();
  bool _pending = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _reference.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
      _success = false;
    });
    final r = await runAction(
      context,
      () => api.action(
        widget.action,
        args: [widget.claimId],
        fields: {
          'transferMode': _mode,
          'transactionReference': _reference.text.trim(),
          'disbursedOn': _date ?? '',
          'note': _note.text,
        },
      ),
      successToast: widget.successText,
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _success = r.ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Gap(
      gap: 12,
      children: [
        TsSelect<String>(
          label: 'Mode of Transfer',
          value: _mode,
          options: [for (final m in kTransferModes) SelectOption(m, m)],
          onChanged: (v) => setState(() => _mode = v ?? 'NEFT'),
        ),
        TsInput(controller: _reference, label: 'Transaction Reference No / UTR No'),
        TsDateField(label: 'Disbursement Date', value: _date, onChanged: (v) => setState(() => _date = v)),
        TsTextarea(controller: _note, label: 'Note (optional)', rows: 2),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton(
            label: widget.submitLabel,
            pendingLabel: widget.pendingLabel,
            pending: _pending,
            variant: widget.variant,
            onPressed: _submit,
          ),
        ),
        if (_error != null) StatusMessage.error(_error),
        if (_success && widget.successText != null) StatusMessage.success(widget.successText),
      ],
    );
  }
}

/// A MobileCard row value that keeps long text (descriptions) to two lines,
/// like the web table's truncated Description cell.
class ClampedValue extends StatelessWidget {
  const ClampedValue(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.right,
      style: tx(14, weight: FontWeight.w600, color: p.foreground),
    );
  }
}
