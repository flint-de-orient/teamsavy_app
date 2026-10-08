import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/employees/new/page.tsx and [id]/edit/page.tsx - both render
/// EmployeeForm (employee-form.tsx); [employeeId] picks edit mode.
class EmployeeFormScreen extends StatelessWidget {
  const EmployeeFormScreen({super.key, this.employeeId});
  final String? employeeId;

  static const _createHeader = PageHeader(
    title: 'Add Employee',
    description: 'For staff who are already on the team - not going through an appointment letter.',
  );

  @override
  Widget build(BuildContext context) {
    final id = employeeId;
    return ApiScreen(
      path: id == null ? '/employees/new' : '/employees/$id/edit',
      header: id == null ? _createHeader : null,
      builder: (context, data, reload) => [
        if (id == null) _createHeader else PageHeader(title: 'Edit ${data.s('name')}'),
        _EmployeeForm(data: data, employeeId: id),
      ],
    );
  }
}

class _EmployeeForm extends StatefulWidget {
  const _EmployeeForm({required this.data, this.employeeId});
  final Json data;
  final String? employeeId;

  @override
  State<_EmployeeForm> createState() => _EmployeeFormState();
}

class _EmployeeFormState extends State<_EmployeeForm> {
  final _c = <String, TextEditingController>{};

  late String _dateOfJoining;
  late String _dateOfBirth;
  late String _internshipEndDate;
  late String _probationEndDate;
  late String _payBandId;
  late String _managerId;
  late String _shiftId;
  late String _employmentType;
  late String _compensationMode;
  late bool _probationAutoTransitionDisabled;
  late bool _isDisbursementOfficer;
  late Set<String> _locations;

  late String _pfType;
  late String _taxRegime;
  late String _cityType;
  late bool _esiApplicable;
  late bool _ptExempt;

  bool _pending = false;
  String? _error;

  Json get _d => widget.data.m('defaults');
  Json? get _payroll => widget.data.mN('payrollProfile');
  Json get _idCard => widget.data.m('idCardProfile');
  bool get _isCreate => widget.employeeId == null;

  TextEditingController _ctl(String key, [String? initial]) =>
      _c.putIfAbsent(key, () => TextEditingController(text: initial ?? ''));

  @override
  void initState() {
    super.initState();
    final d = _d;
    _ctl('name', d.s('name'));
    _ctl('email', d.s('email'));
    _ctl('designation', d.s('designation'));
    _ctl('department', d.s('department'));
    _ctl('stipendAmount', d.s('stipendAmount'));
    _dateOfJoining = d.s('dateOfJoining');
    _dateOfBirth = d.s('dateOfBirth');
    _internshipEndDate = d.s('internshipEndDate');
    _probationEndDate = d.s('probationEndDate');
    _payBandId = d.s('payBandId');
    _managerId = d.s('managerId');
    _shiftId = d.s('shiftId');
    _employmentType = d.s('employmentType', 'PERMANENT');
    _compensationMode = d.s('compensationMode', 'REGULAR_PAY_FROM_START');
    _probationAutoTransitionDisabled = d.b('probationAutoTransitionDisabled');
    _isDisbursementOfficer = d.b('isDisbursementOfficer');
    _locations = d.list<String>('locationIds').toSet();

    final pp = _payroll ?? const <String, dynamic>{};
    _pfType = pp.s('pfType', 'EPF');
    _taxRegime = pp.s('taxRegime', 'NEW');
    _cityType = pp.s('cityType', 'NON_METRO');
    _esiApplicable = pp.b('esiApplicable');
    _ptExempt = pp.b('ptExempt');
    for (final k in [
      'uan',
      'pfAccountNumber',
      'esiNumber',
      'panNumber',
      'aadharNumber',
      'rentPaidPerMonth',
      'workState',
      'bankAccountNumber',
      'bankIfsc',
      'bankName',
      'bankAccountHolderName',
    ]) {
      _ctl(k, pp.s(k));
    }
    for (final k in ['section80CDeclared', 'section80DDeclared', 'homeLoanInterestDeclared']) {
      _ctl(k, pp.s(k, '0'));
    }
    for (final k in ['bloodGroup', 'mobileNumber', 'emergencyContactName', 'emergencyContactNumber']) {
      _ctl(k, _idCard.s(k));
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _t(String key) => _c[key]!.text;

  /// Exactly the fields employee-form.tsx posts: conditional sections only
  /// when rendered, checkboxes as "on" only when ticked.
  Map<String, Object?> _fields() {
    final hasShifts = widget.data.at('shifts') != null;
    final hasLocations = widget.data.at('locations') != null;
    final intern = _employmentType == 'INTERN';
    final stipend = !intern && _compensationMode == 'PROBATION_STIPEND';
    return {
      'name': _t('name'),
      'email': _t('email'),
      'designation': _t('designation'),
      'department': _t('department'),
      'dateOfJoining': _dateOfJoining,
      'payBandId': _payBandId,
      'employmentType': _employmentType,
      if (intern) ...{'internshipEndDate': _internshipEndDate, 'stipendAmount': _t('stipendAmount')},
      if (!intern) 'compensationMode': _compensationMode,
      if (stipend) ...{
        'stipendAmount': _t('stipendAmount'),
        'probationEndDate': _probationEndDate,
        if (_probationAutoTransitionDisabled) 'probationAutoTransitionDisabled': 'on',
      },
      'dateOfBirth': _dateOfBirth,
      'managerId': _managerId,
      if (_isDisbursementOfficer) 'isDisbursementOfficer': 'on',
      if (hasShifts) 'shiftId': _shiftId,
      if (hasLocations) 'locations': _locations.toList(),
      if (_payroll != null) ...{
        'pfType': _pfType,
        'uan': _t('uan'),
        'pfAccountNumber': _t('pfAccountNumber'),
        if (_esiApplicable) 'esiApplicable': 'on',
        'esiNumber': _t('esiNumber'),
        if (_ptExempt) 'ptExempt': 'on',
        'panNumber': _t('panNumber'),
        'aadharNumber': _t('aadharNumber'),
        'taxRegime': _taxRegime,
        'cityType': _cityType,
        'rentPaidPerMonth': _t('rentPaidPerMonth'),
        'section80CDeclared': _t('section80CDeclared'),
        'section80DDeclared': _t('section80DDeclared'),
        'homeLoanInterestDeclared': _t('homeLoanInterestDeclared'),
        'workState': _t('workState'),
        'bankAccountNumber': _t('bankAccountNumber'),
        'bankIfsc': _t('bankIfsc'),
        'bankName': _t('bankName'),
        'bankAccountHolderName': _t('bankAccountHolderName'),
      },
      'bloodGroup': _t('bloodGroup'),
      'mobileNumber': _t('mobileNumber'),
      'emergencyContactName': _t('emergencyContactName'),
      'emergencyContactNumber': _t('emergencyContactNumber'),
    };
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    final id = widget.employeeId;
    final r = await runAction(
      context,
      () => id == null
          ? api.action('people.createEmployee', fields: _fields())
          : api.action('people.updateEmployee', args: [id], fields: _fields()),
      successToast: id == null ? null : 'Saved.',
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  Widget _input(String key, String label, {String? hint, String? placeholder, bool number = false, TextInputType? keyboard}) =>
      TsInput(
        controller: _c[key],
        label: label,
        hint: hint,
        placeholder: placeholder,
        keyboardType: number ? TextInputType.number : keyboard,
        inputFormatters: number ? TsInput.digitsOnly : null,
      );

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final data = widget.data;
    final shifts = data.at('shifts') == null ? null : data.l('shifts');
    final locations = data.at('locations') == null ? null : data.l('locations');
    final payroll = _payroll;
    const none = SelectOption('', '— None —');

    return Gap(
      children: [
        _input('name', 'Full Name'),
        _input('email', 'Email', keyboard: TextInputType.emailAddress),
        _input('designation', 'Designation'),
        _input('department', 'Department'),
        TsDateField(label: 'Date of Joining', value: _dateOfJoining, onChanged: (v) => setState(() => _dateOfJoining = v ?? '')),
        TsSelect<String>(
          label: 'Pay Band',
          value: _payBandId,
          options: [none, for (final b in data.l('payBands')) SelectOption(b.s('id'), b.s('name'))],
          onChanged: (v) => setState(() => _payBandId = v ?? ''),
        ),
        TsPanel(
          child: Gap(
            gap: 12,
            children: [
              TsCheckbox(
                label: 'This employee is an Intern',
                value: _employmentType == 'INTERN',
                onChanged: (v) => setState(() => _employmentType = v ? 'INTERN' : 'PERMANENT'),
              ),
              if (_employmentType == 'INTERN') ...[
                TsDateField(
                  label: 'Internship End Date',
                  value: _internshipEndDate,
                  hint: 'Use their actual remaining tenure, e.g. if already mid-term when added here.',
                  onChanged: (v) => setState(() => _internshipEndDate = v ?? ''),
                ),
                _input('stipendAmount', 'Consolidated Stipend Amount (₹ / month)', number: true),
              ] else ...[
                Text('Compensation During Probation', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
                RadioRow<String>(
                  value: _compensationMode,
                  options: const [
                    SelectOption('PROBATION_STIPEND', 'Probation Stipend'),
                    SelectOption('REGULAR_PAY_FROM_START', 'Regular Pay From Start'),
                  ],
                  onChanged: (v) => setState(() => _compensationMode = v),
                ),
                if (_compensationMode == 'PROBATION_STIPEND') ...[
                  _input('stipendAmount', 'Consolidated Stipend Amount (₹ / month)', number: true),
                  TsDateField(
                    label: 'Probation End Date',
                    value: _probationEndDate,
                    hint: 'Use their actual date, e.g. if already mid-probation when added here.',
                    onChanged: (v) => setState(() => _probationEndDate = v ?? ''),
                  ),
                  TsCheckbox(
                    label: 'Keep on stipend past this date until I manually switch them to regular pay',
                    value: _probationAutoTransitionDisabled,
                    onChanged: (v) => setState(() => _probationAutoTransitionDisabled = v),
                  ),
                ],
              ],
            ],
          ),
        ),
        TsDateField(
          label: 'Date of Birth',
          value: _dateOfBirth,
          clearable: true,
          hint: 'Needed for correct Old-regime tax slabs if the Payroll module is used - old-regime rates vary by age.',
          onChanged: (v) => setState(() => _dateOfBirth = v ?? ''),
        ),
        TsSelect<String>(
          label: 'Reporting Manager',
          value: _managerId,
          hint: 'Leave requests route straight to HR until a manager is linked.',
          options: [none, for (final m in data.l('managers')) SelectOption(m.s('id'), m.s('name'))],
          onChanged: (v) => setState(() => _managerId = v ?? ''),
        ),
        TsCheckbox(
          label: 'Disbursement Officer - can be assigned approved expense claims to disburse via NEFT',
          value: _isDisbursementOfficer,
          onChanged: (v) => setState(() => _isDisbursementOfficer = v),
        ),
        if (shifts != null)
          TsSelect<String>(
            label: 'Shift',
            value: _shiftId,
            options: [
              none,
              for (final s in shifts) SelectOption(s.s('id'), '${s.s('name')} (${s.s('startTime')}–${s.s('endTime')})'),
            ],
            onChanged: (v) => setState(() => _shiftId = v ?? ''),
          ),
        if (locations != null)
          Gap(
            gap: 4,
            children: [
              const GroupLabel(
                'Locations',
                help: 'Offices/sites this employee is allowed to check in from. A punch outside all assigned '
                    'locations is still recorded but flagged for HR review.',
              ),
              for (final l in locations)
                TsCheckbox(
                  label: l.s('name'),
                  value: _locations.contains(l.s('id')),
                  onChanged: (v) => setState(() => v ? _locations.add(l.s('id')) : _locations.remove(l.s('id'))),
                ),
              if (locations.isEmpty) const Muted('No locations set up yet.'),
            ],
          ),
        if (payroll != null)
          FormSection(
            title: 'Payroll Profile',
            children: [
              const Muted(
                "Statutory and bank details used when processing payroll. All optional here so an employee record "
                "isn't blocked on this - Payroll processing will flag anything still missing when it's actually needed.",
                size: 12,
              ),
              TsSelect<String>(
                label: 'PF Type',
                value: _pfType,
                options: const [
                  SelectOption('EPF', 'EPF'),
                  SelectOption('GPF', 'GPF'),
                  SelectOption('CPF', 'CPF'),
                  SelectOption('EXEMPT', 'Exempt'),
                ],
                onChanged: (v) => setState(() => _pfType = v ?? 'EPF'),
              ),
              _input('uan', 'UAN', hint: 'EPF only'),
              _input('pfAccountNumber', 'PF Account Number'),
              TsCheckbox(
                label: 'ESI applies to this employee',
                value: _esiApplicable,
                onChanged: (v) => setState(() => _esiApplicable = v),
              ),
              _input('esiNumber', 'ESI Number'),
              TsCheckbox(
                label: 'Exempt from Professional Tax (e.g. a stipend-based intern)',
                value: _ptExempt,
                onChanged: (v) => setState(() => _ptExempt = v),
              ),
              _input('panNumber', 'PAN'),
              _input('aadharNumber', 'Aadhar Number'),
              TsSelect<String>(
                label: 'Tax Regime',
                value: _taxRegime,
                hint: '${payroll.sn('taxRegimeSelectedFinancialYear') != null ? 'Confirmed for FY ${payroll.s('taxRegimeSelectedFinancialYear')}' : 'Not yet confirmed for any FY'}'
                    ' - saving here also confirms it for the current FY.',
                options: const [SelectOption('NEW', 'New'), SelectOption('OLD', 'Old')],
                onChanged: (v) => setState(() => _taxRegime = v ?? 'NEW'),
              ),
              TsSelect<String>(
                label: 'City Type',
                value: _cityType,
                hint: 'For HRA exemption under the Old regime',
                options: const [SelectOption('NON_METRO', 'Non-Metro'), SelectOption('METRO', 'Metro')],
                onChanged: (v) => setState(() => _cityType = v ?? 'NON_METRO'),
              ),
              _input('rentPaidPerMonth', 'Rent Paid per Month (₹)', number: true, hint: 'Old regime only, self-declared'),
              _input(
                'section80CDeclared',
                'Section 80C Declared (₹)',
                number: true,
                hint: 'Old regime only. Combined with your own PF contribution against the ₹1.5L cap.',
              ),
              _input('section80DDeclared', 'Section 80D Declared (₹)', number: true),
              _input('homeLoanInterestDeclared', 'Home Loan Interest Declared (₹)', number: true),
              _input('workState', 'Work State', hint: 'For Professional Tax. Leave blank to use the company default.'),
              _input('bankAccountNumber', 'Bank Account Number', keyboard: TextInputType.number),
              _input('bankIfsc', 'Bank IFSC'),
              _input('bankName', 'Bank Name'),
              _input('bankAccountHolderName', 'Bank Account Holder Name'),
            ],
          ),
        FormSection(
          title: 'ID Card Details',
          children: [
            const Muted(
              "Used on the employee's ID Card (Settings → ID Card Settings). All optional here - ID Card generation "
              "flags anything still missing when it's actually needed.",
              size: 12,
            ),
            _input('bloodGroup', 'Blood Group', placeholder: 'e.g. O+'),
            _input('mobileNumber', 'Mobile Number', keyboard: TextInputType.phone),
            _input('emergencyContactName', 'Emergency Contact Name'),
            _input('emergencyContactNumber', 'Emergency Contact Number', keyboard: TextInputType.phone),
          ],
        ),
        if (_error != null) StatusMessage.error(_error),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton(
            label: _isCreate ? 'Add Employee' : 'Save Changes',
            pendingLabel: 'Saving...',
            pending: _pending,
            onPressed: _submit,
          ),
        ),
      ],
    );
  }
}
