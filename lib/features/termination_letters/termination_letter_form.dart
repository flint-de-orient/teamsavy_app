import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/termination-letters/new/page.tsx and [id]/edit/page.tsx - both
/// render TerminationLetterForm (termination-letter-form.tsx); [letterId]
/// picks edit mode, [employeeId] is the optional prefill query param the
/// "Issue Termination Letter" button on an employee's own page sends.
class TerminationLetterFormScreen extends StatelessWidget {
  const TerminationLetterFormScreen({super.key, this.letterId, this.employeeId});
  final String? letterId;
  final String? employeeId;

  static const _createHeader = PageHeader(
    title: 'New Termination Letter',
    description:
        "Creates a draft - nothing is finalized, no employee record changes, and no letter is sent until you issue it.",
  );

  @override
  Widget build(BuildContext context) {
    final id = letterId;
    return ApiScreen(
      path: id == null ? '/termination-letters/new' : '/termination-letters/$id/edit',
      query: id == null ? {'employeeId': employeeId} : null,
      header: id == null ? _createHeader : null,
      builder: (context, data, reload) {
        final noticePeriodInfo = data.mN('noticePeriodInfo');
        return [
          if (id == null) _createHeader else const PageHeader(title: 'Edit Termination Letter'),
          if (noticePeriodInfo != null)
            StatusMessage(
              'Based on Policy Settings, this employee is currently '
              '${noticePeriodInfo.b('onProbation') ? 'on probation' : 'confirmed'} — their contractual notice '
              'period is ${noticePeriodInfo.i('days')} day(s).',
              kind: StatusKind.info,
              boxed: true,
            ),
          _TerminationLetterForm(data: data, letterId: id),
        ];
      },
    );
  }
}

class _TerminationLetterForm extends StatefulWidget {
  const _TerminationLetterForm({required this.data, this.letterId});
  final Json data;
  final String? letterId;

  @override
  State<_TerminationLetterForm> createState() => _TerminationLetterFormState();
}

class _TerminationLetterFormState extends State<_TerminationLetterForm> {
  late String _employeeId;
  late String _reason;
  final _reasonDetails = TextEditingController();
  String? _lastWorkingDay;
  late bool _noticePeriodServed;
  final _payInLieuDays = TextEditingController();
  final _noticeWaiverReason = TextEditingController();
  final _additionalRemarks = TextEditingController();
  late String _settlementStatus;
  String? _settlementDueBy;
  final _settlementAmount = TextEditingController();
  String? _settlementPaidOn;
  final _settlementReference = TextEditingController();

  bool _pending = false;
  String? _error;
  bool _saved = false;

  bool get _isCreate => widget.letterId == null;
  Json get _d => _isCreate ? const <String, dynamic>{} : widget.data.m('defaults');

  @override
  void initState() {
    super.initState();
    final d = _d;
    _employeeId = d.sn('employeeId') ?? widget.data.sn('defaultEmployeeId') ?? '';
    _reason = d.s('reason', 'PERFORMANCE');
    _reasonDetails.text = d.s('reasonDetails');
    _lastWorkingDay = d.sn('lastWorkingDay');
    _noticePeriodServed = _isCreate ? true : d.b('noticePeriodServed');
    _payInLieuDays.text = d.iN('payInLieuDays')?.toString() ?? '';
    // Rebuilds so the zero-notice-pay waiver-reason field shows/hides as
    // the user types, same conditional as the web's own controlled input.
    _payInLieuDays.addListener(() => setState(() {}));
    _noticeWaiverReason.text = d.s('noticeWaiverReason');
    _additionalRemarks.text = d.s('additionalRemarks');
    _settlementStatus = d.s('settlementStatus', 'PENDING');
    _settlementDueBy = d.sn('settlementDueBy');
    _settlementAmount.text = d.iN('settlementAmount')?.toString() ?? '';
    _settlementPaidOn = d.sn('settlementPaidOn');
    _settlementReference.text = d.s('settlementReference');
  }

  @override
  void dispose() {
    _reasonDetails.dispose();
    _payInLieuDays.dispose();
    _noticeWaiverReason.dispose();
    _additionalRemarks.dispose();
    _settlementAmount.dispose();
    _settlementReference.dispose();
    super.dispose();
  }

  /// Exactly the fields termination-letter-form.tsx posts: conditional
  /// sections only when rendered, the checkbox as "on" only when ticked.
  Map<String, Object?> _fields() {
    return {
      'employeeId': _employeeId,
      'reason': _reason,
      'reasonDetails': _reasonDetails.text,
      'lastWorkingDay': _lastWorkingDay ?? '',
      if (_noticePeriodServed) 'noticePeriodServed': 'on',
      if (!_noticePeriodServed) 'payInLieuDays': _payInLieuDays.text,
      if (!_noticePeriodServed && _payInLieuDays.text == '0') 'noticeWaiverReason': _noticeWaiverReason.text,
      'additionalRemarks': _additionalRemarks.text,
      'settlementStatus': _settlementStatus,
      if (_settlementStatus == 'PENDING') 'settlementDueBy': _settlementDueBy ?? '',
      if (_settlementStatus == 'SETTLED') ...{
        'settlementAmount': _settlementAmount.text,
        'settlementPaidOn': _settlementPaidOn ?? '',
        'settlementReference': _settlementReference.text,
      },
    };
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
      _saved = false;
    });
    final id = widget.letterId;
    final r = await runAction(
      context,
      () => id == null
          ? api.action('termination.createTerminationLetter', fields: _fields())
          : api.action('termination.updateTerminationLetter', args: [id], fields: _fields()),
      successToast: id == null ? null : 'Saved.',
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _saved = r.ok;
    });
    // termination-letter-form.tsx navigates back to the list client-side on
    // a successful create (the action itself has no server redirect, so
    // the generic mobile bridge's redirect-following has nothing to do
    // here - this mirrors that router.push call exactly).
    if (r.ok && id == null && context.mounted) context.pushReplacement('/termination-letters');
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final detailsRequired = _reason == 'OTHER' || _reason == 'MISCONDUCT';

    return Gap(
      children: [
        TsSelect<String>(
          label: 'Employee',
          value: _employeeId.isEmpty ? null : _employeeId,
          options: [for (final e in data.l('employees')) SelectOption(e.s('id'), '${e.s('name')} (${e.s('designation')})')],
          onChanged: (v) => setState(() => _employeeId = v ?? ''),
        ),
        TsSelect<String>(
          label: 'Reason',
          value: _reason,
          options: kTerminationReasonOptions,
          onChanged: (v) => setState(() => _reason = v ?? 'PERFORMANCE'),
        ),
        TsTextarea(
          label: 'Reason Details${detailsRequired ? ' (required)' : ' (optional)'}',
          controller: _reasonDetails,
          hint: "Specifics behind the reason above - kept internal to this record and the letter's body.",
          rows: 3,
        ),
        TsDateField(
          label: 'Last Working Day',
          value: _lastWorkingDay,
          onChanged: (v) => setState(() => _lastWorkingDay = v),
        ),
        TsPanel(
          child: Gap(
            gap: 12,
            children: [
              TsCheckbox(
                label: 'Notice period will be served',
                value: _noticePeriodServed,
                onChanged: (v) => setState(() => _noticePeriodServed = v),
              ),
              if (!_noticePeriodServed) ...[
                TsInput(
                  label: 'Pay in Lieu of Notice (days)',
                  controller: _payInLieuDays,
                  keyboardType: TextInputType.number,
                  inputFormatters: TsInput.digitsOnly,
                ),
                if (_payInLieuDays.text == '0')
                  TsTextarea(
                    label: 'Reason for Zero Notice Pay (required)',
                    controller: _noticeWaiverReason,
                    hint: 'Why no payment in lieu of notice is being made - this appears in the letter.',
                    rows: 2,
                  ),
              ],
            ],
          ),
        ),
        TsTextarea(
          label: 'Additional Remarks (optional)',
          controller: _additionalRemarks,
          hint: 'An extra paragraph appended to the letter, e.g. well-wishes for an amicable separation.',
          rows: 4,
        ),
        FormSection(
          title: 'Full and Final Settlement',
          children: [
            RadioRow<String>(
              value: _settlementStatus,
              options: const [
                SelectOption('PENDING', 'Pending'),
                SelectOption('SETTLED', 'Already Settled'),
              ],
              onChanged: (v) => setState(() => _settlementStatus = v),
            ),
            if (_settlementStatus == 'PENDING')
              TsDateField(
                label: 'Settle On or Before',
                value: _settlementDueBy,
                hint: 'Stated in the letter as the date by which settlement will be paid.',
                onChanged: (v) => setState(() => _settlementDueBy = v),
              )
            else ...[
              TsInput(
                label: 'Settlement Amount Paid (₹)',
                controller: _settlementAmount,
                keyboardType: TextInputType.number,
                inputFormatters: TsInput.digitsOnly,
              ),
              TsDateField(
                label: 'Date Paid',
                value: _settlementPaidOn,
                onChanged: (v) => setState(() => _settlementPaidOn = v),
              ),
              TsInput(
                label: 'Reference (optional)',
                controller: _settlementReference,
                hint: 'Cheque no., UTR, or any other note HR wants on record.',
              ),
            ],
          ],
        ),
        if (_error != null) StatusMessage.error(_error),
        if (_saved && !_isCreate) StatusMessage.success('Saved.'),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton(
            label: _isCreate ? 'Create Draft' : 'Save Changes',
            pendingLabel: 'Saving...',
            pending: _pending,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
