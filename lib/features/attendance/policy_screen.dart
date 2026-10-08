import '../../widgets/ts.dart';

/// (name, label, hint) for the add form's number fields, in the web's order.
const _numberFields = <(String, String, String?)>[
  ('fullDayMinWorkedMinutes', 'Full Day — Minimum Worked (minutes)', null),
  ('halfDayMinWorkedMinutes', 'Half Day — Minimum Worked (minutes)', null),
  ('lateArrivalGraceMinutes', 'Late Arrival Grace (minutes)', null),
  ('earlyDepartureGraceMinutes', 'Early Departure Grace (minutes)', null),
  (
    'missingPunchOutGraceMinutes',
    'Missing Punch-Out Grace (minutes)',
    'A missing punch-out never counts as Absent on its own - this only delays when it starts showing as an exception.',
  ),
  ('lateArrivalHalfDayAfterOccurrences', 'Half-day after N late arrivals / month', 'Leave blank to disable this rule.'),
  ('lateArrivalHalfDayAfterMinutes', 'Half-day if late by more than N minutes', 'Leave blank to disable this rule.'),
  (
    'lateArrivalAbsentAfterOccurrences',
    'Absent after N late arrivals / month',
    'More severe than the half-day rule above, and checked first - e.g. 3 lates = half-day, 6 lates = absent. Leave blank to disable.',
  ),
  (
    'lateArrivalAbsentAfterMinutes',
    'Absent if late by more than N minutes',
    'Single-day rule, independent of the monthly count above. Leave blank to disable.',
  ),
  ('earlyDepartureHalfDayAfterOccurrences', 'Half-day after N early departures / month', 'Leave blank to disable this rule.'),
  ('earlyDepartureHalfDayAfterMinutes', 'Half-day if leaving more than N minutes early', 'Leave blank to disable this rule.'),
  (
    'earlyDepartureAbsentAfterOccurrences',
    'Absent after N early departures / month',
    'More severe than the half-day rule above, and checked first. Leave blank to disable.',
  ),
  (
    'earlyDepartureAbsentAfterMinutes',
    'Absent if leaving more than N minutes early',
    'Single-day rule, independent of the monthly count above. Leave blank to disable.',
  ),
];

/// app/(app)/settings/attendance-policy/page.tsx: the version history, the
/// add-version form (Tenant Admin) and the bulk recompute (HR + TA).
class AttendancePolicyScreen extends StatelessWidget {
  const AttendancePolicyScreen({super.key});

  static const _header = PageHeader(
    title: 'Attendance Policy',
    description:
        'Half-day and late/early rules, and their effect on leave. Each change creates a new version - past days keep the result computed under the version that was in force then.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/attendance-policy',
      header: _header,
      builder: (context, data, reload) {
        final p = Ts.of(context);
        final policies = data.l('policies');
        return [
          _header,
          TsCard(
            child: policies.isEmpty
                ? const Muted('No policy version has been set yet.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < policies.length; i++)
                        Container(
                          padding: EdgeInsets.only(top: i == 0 ? 0 : 12, bottom: i == policies.length - 1 ? 0 : 12),
                          decoration: BoxDecoration(
                            border: i == policies.length - 1 ? null : Border(bottom: BorderSide(color: p.border)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    policies[i].s('title'),
                                    style: tx(14, weight: FontWeight.w600, color: p.foreground),
                                  ),
                                  if (policies[i].b('isCurrent')) const TsBadge('Current', tone: BadgeTone.green),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(policies[i].s('summary'), style: tx(12, color: p.muted, height: 1.5)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          if (data.b('canWrite'))
            _AddPolicyVersionForm(
              key: const ValueKey('add-policy-version'),
              defaults: data.m('defaults'),
              absentOptions: data.l('absentHandlingOptions'),
              deductionOptions: data.l('deductionOptions'),
            )
          else
            const Muted('Contact your tenant admin to change the attendance policy.'),
          if (data.b('canManageAttendance')) const _RecomputeForm(key: ValueKey('recompute-attendance')),
        ];
      },
    );
  }
}

/// Every warning box (locked payroll months).
class _Warnings extends StatelessWidget {
  const _Warnings(this.warnings);
  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Gap(
      gap: 8,
      children: [
        for (final w in warnings)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.warningLight,
              borderRadius: BorderRadius.circular(Ts.rLg),
              border: Border.all(color: p.warning.withValues(alpha: 0.4)),
            ),
            child: Text(w, style: tx(14, color: p.warning)),
          ),
      ],
    );
  }
}

class _AddPolicyVersionForm extends StatefulWidget {
  const _AddPolicyVersionForm({
    super.key,
    required this.defaults,
    required this.absentOptions,
    required this.deductionOptions,
  });

  final Json defaults;
  final List<Json> absentOptions;
  final List<Json> deductionOptions;

  @override
  State<_AddPolicyVersionForm> createState() => _AddPolicyVersionFormState();
}

class _AddPolicyVersionFormState extends State<_AddPolicyVersionForm> {
  // New versions start from the current one's values - only Effective
  // From and Label are new per version.
  String? _effectiveFrom = todayValue();
  final _label = TextEditingController();
  late final Map<String, TextEditingController> _numbers = {
    for (final (name, _, _) in _numberFields) name: TextEditingController(text: widget.defaults.s(name)),
  };
  late String _absentHandling = widget.defaults.s('absentHandling', 'AUTO_LWP');
  late String _halfDayDeductionUnit = widget.defaults.s('halfDayDeductionUnit', 'HALF_LWP_DAY');

  bool _pending = false;
  String? _error;
  bool _success = false;
  String? _recomputeNote;
  List<String> _warnings = const [];

  @override
  void dispose() {
    _label.dispose();
    for (final c in _numbers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final effectiveFrom = _effectiveFrom ?? '';
    // Only a past/today version has existing attendance to recompute.
    if (effectiveFrom.isNotEmpty && effectiveFrom.compareTo(todayValue()) <= 0) {
      final ok = await confirmDialog(
        context,
        message:
            'Saving this will recompute existing attendance from $effectiveFrom through today for every active employee, using the new policy.\n\nContinue?',
        confirmLabel: 'Continue',
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _pending = true;
      _error = null;
      _success = false;
    });
    final r = await runAction(
      context,
      () => api.action('attendance.addAttendancePolicyVersion', fields: {
        'effectiveFrom': effectiveFrom,
        'label': _label.text,
        for (final e in _numbers.entries) e.key: e.value.text,
        'absentHandling': _absentHandling,
        'halfDayDeductionUnit': _halfDayDeductionUnit,
      }),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _success = r.ok;
      _recomputeNote = r.data?.sn('recomputeNote');
      _warnings = r.data?.list<String>('warnings') ?? const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return TsCard(
      child: Gap(
        gap: 16,
        children: [
          TsDateField(label: 'Effective From', value: _effectiveFrom, onChanged: (v) => setState(() => _effectiveFrom = v)),
          TsInput(controller: _label, label: 'Label (optional)', placeholder: 'FY26-27 revision'),
          for (final (name, label, hint) in _numberFields)
            TsInput(
              controller: _numbers[name],
              label: label,
              hint: hint,
              keyboardType: TextInputType.number,
              inputFormatters: TsInput.digitsOnly,
            ),
          TsSelect<String>(
            label: 'How to handle an Absent day',
            value: _absentHandling,
            options: [for (final o in widget.absentOptions) SelectOption(o.s('value'), o.s('label'))],
            onChanged: (v) => setState(() => _absentHandling = v ?? _absentHandling),
          ),
          TsSelect<String>(
            label: 'Effect of a Half day',
            value: _halfDayDeductionUnit,
            options: [for (final o in widget.deductionOptions) SelectOption(o.s('value'), o.s('label'))],
            onChanged: (v) => setState(() => _halfDayDeductionUnit = v ?? _halfDayDeductionUnit),
          ),
          if (_error != null) StatusMessage.error(_error),
          if (_success)
            Gap(
              gap: 8,
              children: [
                StatusMessage.success('New policy version added.'),
                if (_recomputeNote != null) Muted(_recomputeNote!),
                _Warnings(_warnings),
              ],
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton(label: 'Add Policy Version', pendingLabel: 'Adding...', pending: _pending, onPressed: _submit),
          ),
        ],
      ),
    );
  }
}

class _RecomputeForm extends StatefulWidget {
  const _RecomputeForm({super.key});

  @override
  State<_RecomputeForm> createState() => _RecomputeFormState();
}

class _RecomputeFormState extends State<_RecomputeForm> {
  String? _startDate;
  bool _pending = false;
  String? _error;
  String? _summary;
  List<String> _warnings = const [];

  Future<void> _submit() async {
    final startDate = _startDate;
    if (startDate == null || startDate.isEmpty) {
      setState(() => _error = 'Enter a valid date.');
      return;
    }
    final ok = await confirmDialog(
      context,
      message:
          "Recompute every active employee's attendance from $startDate through today?\n\nThis affects the whole company and cannot be automatically undone - double check the date before continuing.",
      confirmLabel: 'Recompute Attendance',
    );
    if (!ok || !mounted) return;
    setState(() {
      _pending = true;
      _error = null;
      _summary = null;
    });
    final r = await runAction(
      context,
      () => api.action('attendance.recomputeAttendanceFromDate', fields: {'startDate': startDate}),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _summary = r.ok ? r.data?.sn('summary') : null;
      _warnings = r.data?.list<String>('warnings') ?? const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return TsCard(
      icon: LucideIcons.refreshCw,
      title: 'Recompute Attendance',
      description:
          "Recomputes every active employee's attendance from this date through today against the current policy, shift, and leave data - use this after changing the policy above, or after fixing an employee's shift or other attendance-affecting records.",
      child: Gap(
        gap: 16,
        children: [
          TsDateField(label: 'Start Date', value: _startDate, onChanged: (v) => setState(() => _startDate = v)),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton(
              label: 'Recompute Attendance',
              pendingLabel: 'Recomputing...',
              pending: _pending,
              onPressed: _submit,
            ),
          ),
          if (_error != null) StatusMessage.error(_error),
          if (_summary != null) ...[
            Text(_summary!, style: tx(14, color: p.foreground)),
            _Warnings(_warnings),
          ],
        ],
      ),
    );
  }
}
