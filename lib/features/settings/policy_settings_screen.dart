import '../../widgets/ts.dart';
import 'settings_widgets.dart';

const _notAuthorized = 'You are not authorized to update policy settings.';

const _tabs = [
  ('leave', 'Leave'),
  ('leaveWorkflow', 'Leave Workflow'),
  ('probation', 'Probation & Notice'),
  ('hours', 'Working Hours'),
  ('payBands', 'Pay Bands'),
  ('salaryStructure', 'Salary Structure'),
  ('clauseText', 'Clause Text'),
];

/// Checkbox fields post "on" when ticked and nothing otherwise, exactly
/// like an HTML checkbox.
String? _checkbox(bool value) => value ? 'on' : null;

/// app/(app)/settings/policy/page.tsx + policy-tabs.tsx: seven client-side
/// tabs, each its own form. Writes are TENANT_ADMIN-only, so HR_ADMIN sees
/// every tab read-only.
class PolicySettingsScreen extends StatefulWidget {
  const PolicySettingsScreen({super.key});

  @override
  State<PolicySettingsScreen> createState() => _PolicySettingsScreenState();
}

class _PolicySettingsScreenState extends State<PolicySettingsScreen> {
  String _tab = 'leave';

  static const _header = PageHeader(
    title: 'Policy Settings',
    description: 'HR policy defaults applied to every appointment letter.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/policy',
      header: _header,
      builder: (context, data, reload) {
        final canWrite = data.b('canWrite');
        final policy = data.m('policy');
        return [
          _header,
          if (!canWrite) const ReadOnlyNote(_notAuthorized),
          LinkTabs<String>(value: _tab, tabs: _tabs, onChanged: (t) => setState(() => _tab = t)),
          ..._content(data, policy, canWrite),
        ];
      },
    );
  }

  List<Widget> _content(Json data, Json policy, bool canWrite) {
    switch (_tab) {
      case 'leave':
        return [
          TsCard(
            child: _LeavePolicyForm(policy: policy, canWrite: canWrite, organizationId: data.s('organizationId')),
          ),
        ];
      case 'leaveWorkflow':
        return [
          TsCard(child: _LeaveWorkflowForm(policy: policy, canWrite: canWrite)),
          const SectionTitle(
            'Holiday Calendar',
            description:
                'Required for a fully functional leave panel — this is what makes the Casual Leave day-count exclusion and the "holidays count fully" rule for other leave types mean something concrete.',
          ),
          TsCard(child: _HolidayCalendar(holidays: data.l('holidays'), canWrite: canWrite)),
        ];
      case 'probation':
        return [TsCard(child: _ProbationNoticeForm(policy: policy, canWrite: canWrite))];
      case 'hours':
        return [TsCard(child: _WorkingHoursForm(policy: policy, canWrite: canWrite))];
      case 'payBands':
        return _payBands(data.l('payBands'), canWrite);
      case 'salaryStructure':
        return [
          _SalaryStructureForm(
            salaryStructure: data.m('salaryStructure'),
            payBands: data.l('payBands'),
            canWrite: canWrite,
          ),
        ];
      case 'clauseText':
        return [TsCard(child: _ClauseTextForm(clauses: data.l('clauses'), canWrite: canWrite))];
    }
    return const [];
  }

  List<Widget> _payBands(List<Json> bands, bool canWrite) => [
        for (final band in bands) _PayBandRow(key: ValueKey(band.s('id')), band: band, canWrite: canWrite),
        if (canWrite) const _AddPayBandForm(),
      ];
}

/// A save-on-submit form's pending / error / "Saved." state, shared by the
/// simple policy tabs.
mixin _SaveState<T extends StatefulWidget> on State<T> {
  bool pending = false;
  String? error;
  bool success = false;

  Future<void> submit(String action, Map<String, Object?> fields) async {
    FocusScope.of(context).unfocus();
    setState(() {
      pending = true;
      error = null;
      success = false;
    });
    final r = await runAction(context, () => api.action(action, fields: fields), followRedirects: false);
    if (!mounted) return;
    setState(() {
      pending = false;
      error = r.error;
      success = r.ok;
    });
  }

  List<Widget> footer(bool canWrite, VoidCallback onSave, {String label = 'Save'}) => [
        if (canWrite) ...[
          FormStatus(error: error, success: success ? 'Saved.' : null),
          SubmitButton(label: label, pending: pending, onPressed: onSave),
        ],
      ];
}

Widget _number(
  FieldControllers f,
  String name,
  String label,
  bool enabled, {
  String? hint,
  String? placeholder,
  bool decimal = false,
}) =>
    TsInput(
      controller: f[name],
      label: label,
      hint: hint,
      placeholder: placeholder,
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    );

// ---------------------------------------------------------------------------
// Leave

class _LeavePolicyForm extends StatefulWidget {
  const _LeavePolicyForm({required this.policy, required this.canWrite, required this.organizationId});
  final Json policy;
  final bool canWrite;
  final String organizationId;

  @override
  State<_LeavePolicyForm> createState() => _LeavePolicyFormState();
}

class _LeavePolicyFormState extends State<_LeavePolicyForm> with _SaveState {
  late final FieldControllers _f = FieldControllers({
    for (final name in const [
      'earnedLeaveDaysPerYear',
      'earnedLeaveAccrualPerMonth',
      'casualLeaveDays',
      'sickLeaveDays',
      'earnedLeaveEncashmentMinBalance',
      'earnedLeaveEncashmentDayDivisor',
      'maternityLeaveText',
      'paternityLeaveText',
      'bereavementLeaveText',
      'compensatoryOffText',
      'leaveWithoutPayText',
    ])
      name: widget.policy.s(name),
  });
  late bool _accumulation = widget.policy.b('earnedLeaveAccumulationAllowed');
  bool _opening = false;

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  Future<void> _openPdf() async {
    setState(() => _opening = true);
    try {
      await api.openFile('/api/leave-policy/${widget.organizationId}', filename: 'Leave-Policy.pdf');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.canWrite;
    return Gap(
      children: [
        _number(_f, 'earnedLeaveDaysPerYear', 'Earned Leave — Days / Year', w),
        _number(_f, 'earnedLeaveAccrualPerMonth', 'Earned Leave — Accrual / Month', w, decimal: true),
        _number(_f, 'casualLeaveDays', 'Casual Leave — Days', w),
        _number(_f, 'sickLeaveDays', 'Sick Leave — Days', w),
        _number(_f, 'earnedLeaveEncashmentMinBalance', 'EL Encashment — Min Balance Retained', w),
        _number(_f, 'earnedLeaveEncashmentDayDivisor', 'EL Encashment — Per-Day Divisor', w,
            hint: 'Per-day rate = (Basic + DA) ÷ this number'),
        SettingsCheckbox(
          label: 'Earned Leave may be accumulated',
          value: _accumulation,
          enabled: w,
          onChanged: (v) => setState(() => _accumulation = v),
        ),
        TsInput(controller: _f['maternityLeaveText'], label: 'Maternity Leave', enabled: w),
        TsInput(controller: _f['paternityLeaveText'], label: 'Paternity Leave', enabled: w),
        TsInput(controller: _f['bereavementLeaveText'], label: 'Bereavement Leave', enabled: w),
        TsInput(controller: _f['compensatoryOffText'], label: 'Compensatory Off', enabled: w),
        TsInput(controller: _f['leaveWithoutPayText'], label: 'Leave Without Pay', enabled: w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TsLink(_opening ? 'Opening...' : 'Preview Leave Policy PDF', onTap: _opening ? null : _openPdf),
                const SizedBox(width: 6),
                Icon(LucideIcons.externalLink, size: 14, color: Ts.of(context).primary),
              ],
            ),
            const SizedBox(height: 4),
            const Muted(
              'Generated automatically from the settings above - no separate file to upload or keep in sync. This is what opens from the "Leave Policy" button on the WhatsApp messages an employee gets for their leave applications.',
              size: 12,
            ),
          ],
        ),
        ...footer(
          w,
          () => submit('settings.updateLeavePolicy', {
            ..._f.values,
            'earnedLeaveAccumulationAllowed': _checkbox(_accumulation),
          }),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Leave Workflow

class _LeaveWorkflowForm extends StatefulWidget {
  const _LeaveWorkflowForm({required this.policy, required this.canWrite});
  final Json policy;
  final bool canWrite;

  @override
  State<_LeaveWorkflowForm> createState() => _LeaveWorkflowFormState();
}

class _LeaveWorkflowFormState extends State<_LeaveWorkflowForm> with _SaveState {
  late final FieldControllers _f = FieldControllers({
    'earnedLeaveMaxConsecutiveDays': widget.policy.sn('earnedLeaveMaxConsecutiveDays'),
    'casualLeaveMaxConsecutiveDays': widget.policy.sn('casualLeaveMaxConsecutiveDays'),
    'sickLeaveMaxConsecutiveDays': widget.policy.sn('sickLeaveMaxConsecutiveDays'),
    'sickLeaveMedicalCertRequiredAfterDays': widget.policy.sn('sickLeaveMedicalCertRequiredAfterDays'),
  });
  late final Map<String, bool> _checks = {
    for (final name in const [
      'sickLeavePostFactoCertAllowed',
      'sickLeaveFitnessCertRequiredToRejoin',
      'maternityProofRequired',
      'paternityProofRequired',
      'managerApprovalEnabled',
      'earnedLeaveRequiresHrFinalApproval',
    ])
      name: widget.policy.b(name),
  };

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  Widget _check(String name, String label, {String? hint}) => SettingsCheckbox(
        label: label,
        hint: hint,
        value: _checks[name]!,
        enabled: widget.canWrite,
        onChanged: (v) => setState(() => _checks[name] = v),
      );

  @override
  Widget build(BuildContext context) {
    final w = widget.canWrite;
    return Gap(
      gap: 24,
      children: [
        Gap(
          gap: 12,
          children: [
            const SubHeading('Consecutive-day caps'),
            _number(_f, 'earnedLeaveMaxConsecutiveDays', 'Earned Leave', w, placeholder: 'No cap'),
            _number(_f, 'casualLeaveMaxConsecutiveDays', 'Casual Leave', w, placeholder: 'No cap'),
            _number(_f, 'sickLeaveMaxConsecutiveDays', 'Sick Leave', w, placeholder: 'No cap'),
          ],
        ),
        Gap(
          gap: 12,
          children: [
            const SubHeading('Sick leave certificates'),
            _number(
              _f,
              'sickLeaveMedicalCertRequiredAfterDays',
              'Medical certificate required once a request exceeds this many days',
              w,
            ),
            _check(
              'sickLeavePostFactoCertAllowed',
              'Allow post-facto submission of the medical certificate',
              hint: 'If off, a request needing a certificate is blocked until one is attached.',
            ),
            _check('sickLeaveFitnessCertRequiredToRejoin', 'Require a fitness certificate to rejoin after sick leave'),
          ],
        ),
        Gap(
          gap: 12,
          children: [
            const SubHeading('Proof of event'),
            _check('maternityProofRequired', 'Require proof for Maternity Leave'),
            _check('paternityProofRequired', 'Require proof for Paternity Leave'),
          ],
        ),
        Gap(
          gap: 12,
          children: [
            const SubHeading('Approval routing'),
            _check(
              'managerApprovalEnabled',
              'Allow reporting managers to approve leave',
              hint: 'Off means every request goes straight to HR, regardless of manager linkage.',
            ),
            _check(
              'earnedLeaveRequiresHrFinalApproval',
              'Earned Leave always needs a final HR sign-off',
              hint: "Even when manager approval is allowed above, EL still needs HR's final say.",
            ),
          ],
        ),
        if (w)
          Gap(
            gap: 12,
            children: footer(
              w,
              () => submit('settings.updateLeaveWorkflowPolicy', {
                ..._f.values,
                for (final e in _checks.entries) e.key: _checkbox(e.value),
              }),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Holiday Calendar

class _HolidayCalendar extends StatelessWidget {
  const _HolidayCalendar({required this.holidays, required this.canWrite});
  final List<Json> holidays;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final byYear = <int, List<Json>>{};
    for (final h in holidays) {
      (byYear[h.i('year')] ??= []).add(h);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    return Gap(
      children: [
        for (final year in years)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('$year', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
              ),
              for (final h in byYear[year]!) _HolidayRow(key: ValueKey(h.s('id')), holiday: h, canWrite: canWrite),
            ],
          ),
        if (years.isEmpty) const Muted('No holidays recorded yet.'),
        if (canWrite) const _AddHolidayForm(),
      ],
    );
  }
}

class _HolidayRow extends StatefulWidget {
  const _HolidayRow({super.key, required this.holiday, required this.canWrite});
  final Json holiday;
  final bool canWrite;

  @override
  State<_HolidayRow> createState() => _HolidayRowState();
}

class _HolidayRowState extends State<_HolidayRow> {
  bool _removing = false;

  Future<void> _remove() async {
    setState(() => _removing = true);
    await runAction(
      context,
      () => api.action('settings.deleteHoliday', fields: {'id': widget.holiday.s('id')}),
      followRedirects: false,
      toastErrors: true,
    );
    if (mounted) setState(() => _removing = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final h = widget.holiday;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.border))),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${h.s('label')} — ${h.s('name')}',
              style: tx(14, color: p.foreground.withValues(alpha: 0.8)),
            ),
          ),
          if (widget.canWrite)
            _removing
                ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.danger))
                : TsLink('Remove', onTap: _remove, size: 12, color: p.danger),
        ],
      ),
    );
  }
}

class _AddHolidayForm extends StatefulWidget {
  const _AddHolidayForm();

  @override
  State<_AddHolidayForm> createState() => _AddHolidayFormState();
}

class _AddHolidayFormState extends State<_AddHolidayForm> {
  String? _date;
  final _name = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('settings.addHoliday', fields: {'date': _date ?? '', 'name': _name.text}),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      if (r.ok) {
        _date = null;
        _name.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Gap(
        gap: 12,
        children: [
          TsDateField(
            label: 'Date',
            value: _date,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            onChanged: (v) => setState(() => _date = v),
          ),
          TsInput(controller: _name, label: 'Name', placeholder: 'Republic Day'),
          if (_error != null) StatusMessage.error(_error),
          SubmitButton(label: 'Add Holiday', pendingLabel: 'Adding...', pending: _pending, onPressed: _add),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Probation & Notice

class _ProbationNoticeForm extends StatefulWidget {
  const _ProbationNoticeForm({required this.policy, required this.canWrite});
  final Json policy;
  final bool canWrite;

  @override
  State<_ProbationNoticeForm> createState() => _ProbationNoticeFormState();
}

class _ProbationNoticeFormState extends State<_ProbationNoticeForm> with _SaveState {
  late final FieldControllers _f = FieldControllers({
    'defaultProbationMonths': widget.policy.s('defaultProbationMonths'),
    'probationNoticeDays': widget.policy.s('probationNoticeDays'),
    'postConfirmationNoticeDays': widget.policy.s('postConfirmationNoticeDays'),
  });
  late bool _autoCertificate = widget.policy.b('autoGenerateInternshipCertificate');

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.canWrite;
    return Gap(
      children: [
        _number(_f, 'defaultProbationMonths', 'Default Probation Duration (months)', w),
        _number(_f, 'probationNoticeDays', 'Notice Period During Probation (days)', w),
        _number(_f, 'postConfirmationNoticeDays', 'Notice Period After Confirmation (days)', w),
        SettingsCheckbox(
          label: 'Automatically email completion certificates to interns once their internship ends',
          value: _autoCertificate,
          enabled: w,
          onChanged: (v) => setState(() => _autoCertificate = v),
        ),
        ...footer(
          w,
          () => submit('settings.updateProbationNotice', {
            ..._f.values,
            'autoGenerateInternshipCertificate': _checkbox(_autoCertificate),
          }),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Working Hours

class _WorkingHoursForm extends StatefulWidget {
  const _WorkingHoursForm({required this.policy, required this.canWrite});
  final Json policy;
  final bool canWrite;

  @override
  State<_WorkingHoursForm> createState() => _WorkingHoursFormState();
}

class _WorkingHoursFormState extends State<_WorkingHoursForm> with _SaveState {
  late final FieldControllers _f = FieldControllers({
    'workingHoursStart': widget.policy.s('workingHoursStart'),
    'workingHoursEnd': widget.policy.s('workingHoursEnd'),
    'weeklyOffDay': widget.policy.s('weeklyOffDay'),
  });
  late String _workMode = widget.policy.s('defaultWorkMode', 'WFO');

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.canWrite;
    return Gap(
      children: [
        TsInput(controller: _f['workingHoursStart'], label: 'Working Hours Start', enabled: w),
        TsInput(controller: _f['workingHoursEnd'], label: 'Working Hours End', enabled: w),
        TsInput(controller: _f['weeklyOffDay'], label: 'Weekly Off Day', enabled: w),
        TsSelect<String>(
          label: 'Default Work Mode',
          value: _workMode,
          enabled: w,
          options: const [
            SelectOption('WFO', 'Work From Office'),
            SelectOption('WFH', 'Work From Home'),
            SelectOption('HYBRID', 'Hybrid'),
          ],
          onChanged: (v) => setState(() => _workMode = v ?? _workMode),
        ),
        ...footer(w, () => submit('settings.updateWorkingHours', {..._f.values, 'defaultWorkMode': _workMode})),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pay Bands

class _PayBandRow extends StatefulWidget {
  const _PayBandRow({super.key, required this.band, required this.canWrite});
  final Json band;
  final bool canWrite;

  @override
  State<_PayBandRow> createState() => _PayBandRowState();
}

class _PayBandRowState extends State<_PayBandRow> {
  late final _name = TextEditingController(text: widget.band.s('name'));
  late final _ctc = TextEditingController(text: widget.band.s('annualCTC'));
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _ctc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('settings.updatePayBand', fields: {
        'id': widget.band.s('id'),
        'name': _name.text,
        'annualCTC': _ctc.text,
      }),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.canWrite;
    final active = widget.band.b('isActive');
    return TsCard(
      padding: const EdgeInsets.all(16),
      child: Gap(
        gap: 12,
        children: [
          TsInput(controller: _name, label: 'Name', enabled: w),
          TsInput(
            controller: _ctc,
            label: 'Annual CTC (₹)',
            enabled: w,
            keyboardType: TextInputType.number,
            inputFormatters: TsInput.digitsOnly,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (w) ...[
                TsButton.secondary(
                  label: 'Save',
                  pendingLabel: 'Saving...',
                  pending: _pending,
                  compact: true,
                  onPressed: _save,
                ),
                ActionButton(
                  label: active ? 'Deactivate' : 'Activate',
                  variant: TsButtonVariant.secondary,
                  compact: true,
                  followRedirects: false,
                  run: () => api.action('settings.setPayBandActive', fields: {
                    'id': widget.band.s('id'),
                    'isActive': (!active).toString(),
                  }),
                ),
              ],
              if (!active) const TsPill('Inactive'),
            ],
          ),
          if (_error != null) StatusMessage.error(_error),
        ],
      ),
    );
  }
}

class _AddPayBandForm extends StatefulWidget {
  const _AddPayBandForm();

  @override
  State<_AddPayBandForm> createState() => _AddPayBandFormState();
}

class _AddPayBandFormState extends State<_AddPayBandForm> {
  final _name = TextEditingController();
  final _ctc = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _ctc.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('settings.addPayBand', fields: {'name': _name.text, 'annualCTC': _ctc.text}),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      if (r.ok) {
        _name.clear();
        _ctc.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FormSection(
      title: 'Add Pay Band',
      gap: 12,
      children: [
        TsInput(controller: _name, label: 'Name', placeholder: 'Pay Band 2'),
        TsInput(
          controller: _ctc,
          label: 'Annual CTC (₹)',
          keyboardType: TextInputType.number,
          inputFormatters: TsInput.digitsOnly,
        ),
        if (_error != null) StatusMessage.error(_error),
        SubmitButton(label: 'Add Pay Band', pendingLabel: 'Adding...', pending: _pending, onPressed: _add),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Salary Structure

/// JavaScript's Math.round (halves round towards +infinity), so negative
/// Special Allowance figures match the web preview to the rupee.
int _jsRound(double x) => (x + 0.5).floor();

/// lib/salary-breakup.ts#computeSalaryBreakup. `cityType` picks which of the
/// two HRA rates applies - lib/salary-breakup.ts's own Metro/Non-Metro
/// auto-classification (hraMetroPercentOfBasic vs hraNonMetroPercentOfBasic).
List<(String, int, int)> _salaryBreakup(Map<String, double> r, int annualCTC, String cityType) {
  final basic = _jsRound(r['basicPercentOfCTC']! / 100 * annualCTC);
  final da = _jsRound(r['daPercentOfCTC']! / 100 * annualCTC);
  final wages = basic + da;
  final hraPercent = cityType == 'METRO' ? r['hraMetroPercentOfBasic']! : r['hraNonMetroPercentOfBasic']!;
  final hra = _jsRound(hraPercent / 100 * basic);
  final employerPf = _jsRound(r['employerPfPercentOfWages']! / 100 * wages);
  final gratuity = _jsRound(r['gratuityPercentOfWages']! / 100 * wages);
  final special = annualCTC - (basic + da + hra + employerPf + gratuity);
  final lines = [
    ('Basic Salary', basic),
    ('Dearness Allowance (DA)', da),
    ('House Rent Allowance (HRA)', hra),
    ('Special / Other Allowance', special),
    ("Employer's Contribution to Provident Fund", employerPf),
    ('Gratuity (Statutory Provision)', gratuity),
  ];
  return [for (final (name, annual) in lines) (name, annual, _jsRound(annual / 12))];
}

class _SalaryStructureForm extends StatefulWidget {
  const _SalaryStructureForm({required this.salaryStructure, required this.payBands, required this.canWrite});
  final Json salaryStructure;
  final List<Json> payBands;
  final bool canWrite;

  @override
  State<_SalaryStructureForm> createState() => _SalaryStructureFormState();
}

class _SalaryStructureFormState extends State<_SalaryStructureForm> with _SaveState {
  static const _fields = [
    ('basicPercentOfCTC', 'Basic Salary (% of CTC)'),
    ('daPercentOfCTC', 'Dearness Allowance (% of CTC)'),
    ('hraMetroPercentOfBasic', 'HRA, Metro city (% of Basic)'),
    ('hraNonMetroPercentOfBasic', 'HRA, Non-Metro city (% of Basic)'),
    ('employerPfPercentOfWages', 'Employer PF (% of Basic + DA)'),
    ('gratuityPercentOfWages', 'Gratuity (% of Basic + DA)'),
  ];

  late final FieldControllers _f = FieldControllers({
    for (final (name, _) in _fields) name: widget.salaryStructure.s(name),
  });

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  // `Number(e.target.value)` - a blank or half-typed field counts as 0.
  Map<String, double> get _rates => {
        for (final (name, _) in _fields) name: double.tryParse(_f[name].text.trim()) ?? 0,
      };

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final w = widget.canWrite;
    final rates = _rates;
    final wagesPercent = rates['basicPercentOfCTC']! + rates['daPercentOfCTC']!;
    final meets = wagesPercent >= 50;
    return Gap(
      children: [
        TsCard(
          child: Gap(
            children: [
              const Muted(
                "Defines how each Pay Band's annual CTC is broken up into components for Annexure A of the appointment letter. Employer PF and Gratuity are computed on Basic + DA (\"wages\"), per the labour codes in force since 21 Nov 2025. Special/Other Allowance always absorbs whatever remains, so every break-up sums exactly to the CTC.",
              ),
              for (final (name, label) in _fields)
                TsInput(
                  controller: _f[name],
                  label: label,
                  enabled: w,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  suffix: Text('%', style: tx(14, color: p.muted)),
                  onChanged: (_) => setState(() {}),
                ),
              Text(
                'Basic + DA = ${wagesPercent.toStringAsFixed(1)}% of CTC — ${meets ? 'meets the 50% statutory wage floor.' : 'below the 50% statutory wage floor required by the new labour codes.'}',
                style: tx(14, color: meets ? p.success : p.warning),
              ),
              ...footer(w, () => submit('settings.updateSalaryStructure', _f.values)),
            ],
          ),
        ),
        const SectionTitle('Preview (live, based on the values above)'),
        // No specific employee here (a Pay Band is a reusable template), so
        // both city types are shown - stacked, matching the web preview's
        // own mobile-width (grid-cols-1) layout - rather than picking one.
        for (final band in widget.payBands) ...[
          _BreakupCard(
            title: '${band.s('name')} — ${rupee(band.i('annualCTC'))} CTC (Metro City)',
            lines: _salaryBreakup(rates, band.i('annualCTC'), 'METRO'),
          ),
          _BreakupCard(
            title: '${band.s('name')} — ${rupee(band.i('annualCTC'))} CTC (Non-Metro City)',
            lines: _salaryBreakup(rates, band.i('annualCTC'), 'NON_METRO'),
          ),
        ],
        if (widget.payBands.isEmpty) const Muted('Add a Pay Band to see a live preview.'),
      ],
    );
  }
}

class _BreakupCard extends StatelessWidget {
  const _BreakupCard({required this.title, required this.lines});
  final String title;
  final List<(String, int, int)> lines;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    Widget row(String a, String b, String c, {bool head = false}) {
      final style = head
          ? tx(11, weight: FontWeight.w600, color: p.muted, tracking: 0.04)
          : tx(13, color: p.foreground.withValues(alpha: 0.8));
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(a, style: style)),
            SizedBox(width: 84, child: Text(b, textAlign: TextAlign.right, style: style)),
            SizedBox(width: 72, child: Text(c, textAlign: TextAlign.right, style: style)),
          ],
        ),
      );
    }

    return TsCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: tx(14, weight: FontWeight.w500, color: p.foreground)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(Ts.rXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ColoredBox(
                  color: p.surfaceHover,
                  child: row('COMPONENT', 'ANNUAL (₹)', 'MONTHLY (₹)', head: true),
                ),
                for (var i = 0; i < lines.length; i++)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      border: i == 0 ? null : Border(top: BorderSide(color: p.border)),
                    ),
                    child: row(lines[i].$1, fmtNumber(lines[i].$2), fmtNumber(lines[i].$3)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clause Text

class _ClauseTextForm extends StatefulWidget {
  const _ClauseTextForm({required this.clauses, required this.canWrite});
  final List<Json> clauses;
  final bool canWrite;

  @override
  State<_ClauseTextForm> createState() => _ClauseTextFormState();
}

class _ClauseTextFormState extends State<_ClauseTextForm> with _SaveState {
  // Fixed at first render, like the web's useState(() => sorted).
  late final List<Json> _clauses = [...widget.clauses]..sort((a, b) => a.i('order').compareTo(b.i('order')));
  late final FieldControllers _f = FieldControllers({
    for (final c in _clauses) 'clause_${c.s('key')}': c.s('content'),
  });

  @override
  void dispose() {
    _f.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.canWrite;
    return Gap(
      gap: 24,
      children: [
        for (final c in _clauses)
          TsTextarea(controller: _f['clause_${c.s('key')}'], label: c.s('label'), rows: 4, enabled: w),
        if (w)
          Gap(
            gap: 12,
            children: footer(w, () => submit('settings.updateClauseTexts', _f.values), label: 'Save Clause Text'),
          ),
      ],
    );
  }
}
