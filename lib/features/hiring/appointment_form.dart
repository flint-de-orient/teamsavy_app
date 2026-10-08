import 'package:dio/dio.dart' as dio;

import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/appointments/new/page.tsx.
class NewAppointmentScreen extends StatelessWidget {
  const NewAppointmentScreen({super.key, this.regularizeEmployeeId, this.candidateId});
  final String? regularizeEmployeeId;
  final String? candidateId;

  static const _title = PlainHeader('New Appointment Letter');

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/appointments/new',
      query: {'regularizeEmployeeId': regularizeEmployeeId, 'candidateId': candidateId},
      header: _title,
      builder: (context, data, reload) {
        final p = Ts.of(context);
        switch (data.s('state')) {
          case 'ineligible':
            return [
              _title,
              StatusMessage.error(
                "This candidate isn't eligible for an appointment right now - they may have already been linked to one, withdrawn, or not yet cleared every round.",
              ),
            ];
          case 'noPayBands':
            return [
              _title,
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('No active pay bands are configured yet. Add one in ', style: tx(14, color: p.muted)),
                  GestureDetector(
                    onTap: () => context.push('/settings/policy'),
                    child: Text('Policy Settings',
                        style: tx(14, color: p.primary, decoration: TextDecoration.underline)),
                  ),
                  Text(' before creating an appointment letter.', style: tx(14, color: p.muted)),
                ],
              ),
            ];
          default:
            return [_title, AppointmentForm(data: data)];
        }
      },
    );
  }
}

/// app/(app)/appointments/[id]/edit/page.tsx.
class EditAppointmentScreen extends StatelessWidget {
  const EditAppointmentScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/appointments/$id/edit',
      builder: (context, data, reload) => [
        PlainHeader('Edit Appointment Letter — ${data.s('appointment.candidateName')}'),
        AppointmentForm(data: data, appointmentId: id),
      ],
    );
  }
}

class _AllowanceRow {
  _AllowanceRow(String name, String amount)
      : name = TextEditingController(text: name),
        amount = TextEditingController(text: amount);
  final TextEditingController name;
  final TextEditingController amount;

  void dispose() {
    name.dispose();
    amount.dispose();
  }
}

/// appointment-form.tsx, shared by create (no [appointmentId]) and edit.
class AppointmentForm extends StatefulWidget {
  const AppointmentForm({super.key, required this.data, this.appointmentId});
  final Json data;
  final String? appointmentId;

  @override
  State<AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<AppointmentForm> {
  bool get _isEdit => widget.appointmentId != null;
  late final Json _d = widget.data;
  late final Json _appt = _d.m('appointment');
  late final bool _isIssuedCorrection = _d.b('isIssuedCorrection');
  late final List<Json> _interns = _isEdit ? const [] : _d.l('internCandidates');
  late final Json? _seed = _d.mN('candidateSeed');

  late final TextEditingController _candidateName, _fatherName, _aadharNo, _mobileNo, _email, _address;
  late final TextEditingController _designation, _department, _placeOfPosting, _effectiveDateCondition;
  late final TextEditingController _probationMonths, _stipendAmount, _memoNo;
  String? _dob;
  String? _dateOfJoining;
  String? _issueDate;
  late String _reportingManagerId;
  late String _shiftId;
  late Set<String> _locations;
  late String _employmentType;
  late String _internshipDurationMonths;
  late String _payBandId;
  late String _compensationMode;
  late String _workMode;
  late String _memoNoMode;
  late String _issueDateMode;
  late String _regularizingEmployeeId;
  final List<_AllowanceRow> _allowances = [];

  String? _aadharLastFour;
  bool _aadharFilledViaOcr = false;

  bool _pending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final defaults = _d.m('defaults');
    final initialRegularize = _d.s('initialRegularizeEmployeeId');
    _regularizingEmployeeId = initialRegularize;
    // ?regularizeEmployeeId= pre-fills like a picker choice; otherwise the
    // candidate seed ("Create Appointment from Candidate") does.
    final initial = _interns.where((c) => c.s('id') == initialRegularize).firstOrNull ?? _seed;
    String pick(String key, [String fallback = '']) =>
        _isEdit ? _appt.s(key) : (initial?.sn(key) ?? fallback);

    _candidateName = TextEditingController(text: pick('candidateName'));
    _fatherName = TextEditingController(text: pick('fatherName'));
    _dob = pick('dob');
    _aadharNo = TextEditingController(text: pick('aadharNo'));
    _mobileNo = TextEditingController(text: pick('mobileNo'));
    _email = TextEditingController(text: pick('email'));
    _address = TextEditingController(text: pick('address'));
    _designation = TextEditingController(text: pick('designation', defaults.s('designation')));
    _department = TextEditingController(text: pick('department', defaults.s('department')));
    _placeOfPosting = TextEditingController(text: _isEdit ? _appt.s('placeOfPosting') : defaults.s('placeOfPosting'));
    _effectiveDateCondition = TextEditingController(text: _appt.s('effectiveDateCondition'));
    _dateOfJoining = _appt.s('dateOfJoining');
    _reportingManagerId = _appt.s('reportingManagerId');
    _shiftId = _appt.s('shiftId');
    _locations = _appt.list<String>('locationIds').toSet();
    _employmentType = _appt.sn('employmentType') ?? 'PERMANENT';
    if (initialRegularize.isNotEmpty) _employmentType = 'PERMANENT';
    _internshipDurationMonths = _appt.sn('internshipDurationMonths') ?? '3';
    _probationMonths = TextEditingController(text: '${_appt.iN('probationMonths') ?? defaults.i('probationMonths')}');
    final bands = _d.l('payBands');
    _payBandId = _appt.sn('payBandId') ?? (bands.isEmpty ? '' : bands.first.s('id'));
    _compensationMode = _appt.sn('compensationMode') ?? 'PROBATION_STIPEND';
    _stipendAmount = TextEditingController(text: _appt.s('stipendAmount'));
    for (final a in _appt.l('otherAllowances')) {
      _allowances.add(_AllowanceRow(a.s('name'), a.s('amount')));
    }
    _workMode = _appt.sn('workMode') ?? defaults.s('workMode', 'WFO');
    _memoNoMode = _appt.sn('memoNoMode') ?? 'AUTO';
    _memoNo = TextEditingController(text: _appt.s('memoNo'));
    _issueDateMode = _appt.sn('issueDateMode') ?? 'AUTO';
    _issueDate = _appt.s('issueDate');
    _aadharNo.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [
      _candidateName, _fatherName, _aadharNo, _mobileNo, _email, _address, _designation, _department,
      _placeOfPosting, _effectiveDateCondition, _probationMonths, _stipendAmount, _memoNo,
    ]) {
      c.dispose();
    }
    for (final a in _allowances) {
      a.dispose();
    }
    super.dispose();
  }

  void _internSelected(String id) {
    setState(() {
      _regularizingEmployeeId = id;
      if (id.isEmpty) return;
      final intern = _interns.where((c) => c.s('id') == id).firstOrNull;
      if (intern == null) return;
      _candidateName.text = intern.s('candidateName');
      _fatherName.text = intern.s('fatherName');
      _dob = intern.s('dob');
      _aadharNo.text = intern.s('aadharNo');
      _address.text = intern.s('address');
      _mobileNo.text = intern.s('mobileNo');
      _email.text = intern.s('email');
      _designation.text = intern.s('designation');
      _department.text = intern.s('department');
      // A regularization is definitionally a permanent role.
      _employmentType = 'PERMANENT';
    });
  }

  void _aadhaarScanned(Json r) {
    setState(() {
      if (r.sn('candidateName') != null) _candidateName.text = r.s('candidateName');
      if (r.sn('fatherNameGuess') != null) _fatherName.text = r.s('fatherNameGuess');
      if (r.sn('dob') != null) _dob = r.s('dob');
      if (r.sn('address') != null) _address.text = r.s('address');
      _aadharLastFour = r.sn('aadhaarLastFourDigits');
      final alreadyFull = _aadharNo.text.replaceAll(RegExp(r'\D'), '').length >= 12;
      if (alreadyFull) return;
      if (r.sn('aadharNoFull') != null) {
        _aadharNo.text = r.s('aadharNoFull');
        _aadharFilledViaOcr = true;
      } else if (_aadharLastFour != null) {
        _aadharNo.text = _aadharLastFour!;
      }
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final intern = _employmentType == 'INTERN';
    final fields = <String, Object?>{
      'regularizesEmployeeId': _regularizingEmployeeId,
      'candidateId': _seed?.s('id') ?? '',
      'candidateName': _candidateName.text,
      'fatherName': _fatherName.text,
      'dob': _dob ?? '',
      'aadharNo': _aadharNo.text,
      'mobileNo': _mobileNo.text,
      'email': _email.text,
      'address': _address.text,
      'designation': _designation.text,
      'department': _department.text,
      'reportingManagerId': _reportingManagerId,
      'placeOfPosting': _placeOfPosting.text,
      'dateOfJoining': _dateOfJoining ?? '',
      if (_d.at('shifts') != null) 'shiftId': _shiftId,
      'effectiveDateCondition': _effectiveDateCondition.text,
      if (_d.at('locations') != null) 'locations': _locations.toList(),
      'employmentType': _employmentType,
      if (intern) ...{
        'internshipDurationMonths': _internshipDurationMonths,
        'probationMonths': '0',
        'compensationMode': 'PROBATION_STIPEND',
        'stipendAmount': _stipendAmount.text,
      } else ...{
        'probationMonths': _probationMonths.text,
        'compensationMode': _compensationMode,
        if (_compensationMode == 'PROBATION_STIPEND') 'stipendAmount': _stipendAmount.text,
      },
      'payBandId': _payBandId,
      'allowanceName': [for (final a in _allowances) a.name.text],
      'allowanceAmount': [for (final a in _allowances) a.amount.text],
      'workMode': _workMode,
      if (_isIssuedCorrection) ...{
        'memoNoMode': _appt.s('memoNoMode'),
        'memoNo': _appt.s('memoNo'),
        'issueDateMode': _appt.s('issueDateMode'),
        'issueDate': _appt.s('issueDate'),
      } else ...{
        'memoNoMode': _memoNoMode,
        if (_memoNoMode == 'MANUAL') 'memoNo': _memoNo.text,
        'issueDateMode': _issueDateMode,
        if (_issueDateMode == 'MANUAL') 'issueDate': _issueDate ?? '',
      },
    };
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => _isEdit
          ? api.action('hiring.updateAppointment', fields: fields, args: [widget.appointmentId!])
          : api.action('hiring.createAppointment', fields: fields),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final intern = _employmentType == 'INTERN';
    final shifts = _d.at('shifts') == null ? null : _d.l('shifts');
    final locations = _d.at('locations') == null ? null : _d.l('locations');
    final payBands = _d.l('payBands');
    final digits = _aadharNo.text.replaceAll(RegExp(r'\D'), '');

    Widget? aadharHint;
    final last4 = _aadharLastFour;
    if (last4 != null) {
      final matches = digits.length == 12 && digits.endsWith(last4);
      aadharHint = Text(
        digits == last4
            ? "Pre-filled with the last 4 digits from the QR ($last4) — that's all UIDAI includes. Type the remaining 8 digits in front of them."
            : matches
                ? 'Ends in $last4, matching the QR.'
                : "Doesn't end in $last4 — double check against the QR.",
        style: tx(12, color: matches ? p.success : p.warning),
      );
    } else if (_aadharFilledViaOcr) {
      aadharHint = Text(
        "Auto-filled using on-device text recognition of the printed number — please verify it against the card, OCR isn't perfectly reliable.",
        style: tx(12, color: p.warning),
      );
    }

    final stipendField = TsInput(
      controller: _stipendAmount,
      label: 'Consolidated Stipend Amount (₹ / month)',
      keyboardType: TextInputType.number,
      inputFormatters: TsInput.digitsOnly,
    );

    return Gap(
      gap: 24,
      children: [
        if (_interns.isNotEmpty)
          FormSection(title: 'Regularizing an Intern?', children: [
            TsSelect<String>(
              label: 'Select an intern to offer a permanent role, or leave blank for a new candidate',
              value: _regularizingEmployeeId,
              options: [
                const SelectOption('', '— New candidate —'),
                for (final c in _interns) SelectOption(c.s('id'), '${c.s('candidateName')} — ${c.s('designation')}'),
              ],
              onChanged: (v) => _internSelected(v ?? ''),
              hint: _regularizingEmployeeId.isNotEmpty
                  ? 'Fields below are pre-filled from their internship record — still editable if anything changed (e.g. a new role or department).'
                  : null,
            ),
          ]),
        if (_seed != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: p.primaryLight,
              borderRadius: BorderRadius.circular(Ts.r2xl),
              border: Border.all(color: p.primary.withValues(alpha: 0.3)),
            ),
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Creating this appointment for '),
                TextSpan(text: _seed.s('candidateName'), style: const TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(
                  text:
                      ', who cleared every round for ${_d.sn('candidateJobTitle') ?? 'their job'}. Personal details are pre-filled below - review before issuing.',
                ),
              ]),
              style: tx(14, color: p.foreground, height: 1.5),
            ),
          ),
        FormSection(title: 'Candidate', children: [
          _AadhaarUpload(onScanned: _aadhaarScanned),
          TsInput(controller: _candidateName, label: 'Candidate Name', textCapitalization: TextCapitalization.words),
          TsInput(controller: _fatherName, label: "Father's Name", textCapitalization: TextCapitalization.words),
          TsDateField(label: 'Date of Birth', value: _dob, onChanged: (v) => setState(() => _dob = v)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TsInput(
                controller: _aadharNo,
                label: 'Aadhar No.',
                keyboardType: TextInputType.number,
                inputFormatters: TsInput.digitsOnly,
                maxLength: 12,
              ),
              if (aadharHint != null) Padding(padding: const EdgeInsets.only(top: 6), child: aadharHint),
            ],
          ),
          TsInput(
            controller: _mobileNo,
            label: 'Mobile No.',
            keyboardType: TextInputType.phone,
            inputFormatters: TsInput.digitsOnly,
            maxLength: 10,
          ),
          TsInput(controller: _email, label: 'Email', keyboardType: TextInputType.emailAddress),
          TsInput(controller: _address, label: 'Address', textCapitalization: TextCapitalization.sentences),
        ]),
        FormSection(title: 'Role & Posting', children: [
          TsInput(controller: _designation, label: 'Designation'),
          TsInput(controller: _department, label: 'Department'),
          TsSelect<String>(
            label: 'Reporting Manager',
            value: _reportingManagerId,
            options: [
              const SelectOption('', '— No reporting manager —'),
              for (final e in _d.l('employees')) SelectOption(e.s('id'), '${e.s('name')} — ${e.s('designation')}'),
            ],
            onChanged: (v) => setState(() => _reportingManagerId = v ?? ''),
          ),
          TsInput(controller: _placeOfPosting, label: 'Place of Posting'),
          TsDateField(
            label: 'Date of Joining',
            value: _dateOfJoining,
            onChanged: (v) => setState(() => _dateOfJoining = v),
          ),
          if (shifts != null)
            TsSelect<String>(
              label: 'Shift',
              value: _shiftId,
              options: [
                const SelectOption('', '— None —'),
                for (final s in shifts)
                  SelectOption(s.s('id'), '${s.s('name')} (${s.s('startTime')}–${s.s('endTime')})'),
              ],
              onChanged: (v) => setState(() => _shiftId = v ?? ''),
            ),
          TsInput(
            controller: _effectiveDateCondition,
            label: 'Effective Date Condition (optional — leave blank to use Date of Joining directly)',
          ),
          if (locations != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Locations', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
                const SizedBox(height: 4),
                Text('Offices/sites this employee will be allowed to check in from once they join.',
                    style: tx(12, color: p.muted)),
                const SizedBox(height: 4),
                for (final l in locations)
                  TsCheckbox(
                    label: l.s('name'),
                    value: _locations.contains(l.s('id')),
                    onChanged: (v) => setState(() => v ? _locations.add(l.s('id')) : _locations.remove(l.s('id'))),
                  ),
                if (locations.isEmpty) const Muted('No locations set up yet.'),
              ],
            ),
        ]),
        FormSection(title: 'Probation & Compensation', children: [
          if (_regularizingEmployeeId.isNotEmpty)
            const Muted(
                'Regularizing an intern to a permanent role — probation and compensation below apply to their new role.')
          else
            TsCheckbox(
              label: 'This is an Internship',
              value: intern,
              onChanged: (v) => setState(() => _employmentType = v ? 'INTERN' : 'PERMANENT'),
            ),
          if (intern)
            TsSelect<String>(
              label: 'Internship Duration',
              value: _internshipDurationMonths,
              options: const [
                SelectOption('3', '3 months'),
                SelectOption('6', '6 months'),
                SelectOption('12', '12 months'),
              ],
              onChanged: (v) => setState(() => _internshipDurationMonths = v ?? '3'),
            )
          else
            TsInput(
              controller: _probationMonths,
              label: 'Probation Duration (months)',
              keyboardType: TextInputType.number,
              inputFormatters: TsInput.digitsOnly,
            ),
          TsSelect<String>(
            label: intern ? 'Pay Band (not used for stipend-based interns)' : 'Regular Pay Band',
            value: _payBandId,
            options: [
              for (final b in payBands) SelectOption(b.s('id'), '${b.s('name')} — ${rupee(b.at('annualCTC'))} CTC'),
            ],
            onChanged: (v) => setState(() => _payBandId = v ?? _payBandId),
          ),
          if (intern)
            stipendField
          else ...[
            RadioGroupRow<String>(
              label: 'Compensation During Probation',
              value: _compensationMode,
              options: const [
                SelectOption('PROBATION_STIPEND', 'Probation Stipend'),
                SelectOption('REGULAR_PAY_FROM_START', 'Regular Pay From Start'),
              ],
              onChanged: (v) => setState(() => _compensationMode = v),
            ),
            if (_compensationMode == 'PROBATION_STIPEND') stipendField,
          ],
        ]),
        FormSection(title: 'Other Allowances (optional)', children: [
          for (final row in _allowances)
            TsPanel(
              child: Gap(
                gap: 12,
                children: [
                  TsInput(controller: row.name, label: 'Allowance Name'),
                  TsInput(
                    controller: row.amount,
                    label: 'Amount (₹)',
                    keyboardType: TextInputType.number,
                    inputFormatters: TsInput.digitsOnly,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TsButton.secondary(
                      label: 'Remove',
                      compact: true,
                      onPressed: () => setState(() {
                        _allowances.remove(row);
                        disposeAfterFrame(row.dispose);
                      }),
                    ),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton.secondary(
              label: '+ Add Allowance',
              onPressed: () => setState(() => _allowances.add(_AllowanceRow('', ''))),
            ),
          ),
        ]),
        FormSection(title: 'Work Mode', children: [
          TsSelect<String>(
            value: _workMode,
            options: const [
              SelectOption('WFO', 'Work From Office'),
              SelectOption('WFH', 'Work From Home'),
              SelectOption('HYBRID', 'Hybrid'),
            ],
            onChanged: (v) => setState(() => _workMode = v ?? _workMode),
          ),
        ]),
        FormSection(title: 'Memo No. & Date', children: [
          if (_isIssuedCorrection)
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Locked once issued - Memo No. '),
                TextSpan(text: _appt.s('memoNo'), style: TextStyle(fontWeight: FontWeight.w700, color: p.foreground)),
                const TextSpan(text: ', dated '),
                TextSpan(text: _appt.s('issueDate'), style: TextStyle(fontWeight: FontWeight.w700, color: p.foreground)),
                const TextSpan(
                    text: '. Your other changes below will regenerate the letter with this same memo number and date.'),
              ]),
              style: tx(14, color: p.muted, height: 1.5),
            )
          else ...[
            RadioGroupRow<String>(
              label: 'Memo No.',
              value: _memoNoMode,
              options: const [SelectOption('AUTO', 'Auto Generate'), SelectOption('MANUAL', 'Manual')],
              onChanged: (v) => setState(() => _memoNoMode = v),
            ),
            if (_memoNoMode == 'MANUAL') TsInput(controller: _memoNo, label: 'Memo No.'),
            RadioGroupRow<String>(
              label: 'Date',
              value: _issueDateMode,
              options: const [SelectOption('AUTO', 'Auto (Today)'), SelectOption('MANUAL', 'Manual')],
              onChanged: (v) => setState(() => _issueDateMode = v),
            ),
            if (_issueDateMode == 'MANUAL')
              TsDateField(label: 'Date', value: _issueDate, onChanged: (v) => setState(() => _issueDate = v)),
          ],
        ]),
        Gap(
          gap: 12,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) StatusMessage.error(_error),
            TsButton(
              label: _isEdit ? 'Save Changes' : 'Save Draft',
              pendingLabel: 'Saving...',
              pending: _pending,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }
}

/// The upload half of aadhaar-scan.tsx: a photo/PDF of the card is read by
/// the server's AI step (POST /api/aadhaar/extract) and fills the form.
/// The live-camera QR scan and the on-device QR/OCR fallback run in the
/// browser only, so the app offers just this path.
class _AadhaarUpload extends StatefulWidget {
  const _AadhaarUpload({required this.onScanned});
  final ValueChanged<Json> onScanned;

  @override
  State<_AadhaarUpload> createState() => _AadhaarUploadState();
}

class _AadhaarUploadState extends State<_AadhaarUpload> {
  bool _processing = false;
  String? _error;
  String? _notice;

  Future<Json?> _extract(UploadFile f) async {
    try {
      final client = dio.Dio(dio.BaseOptions(validateStatus: (_) => true, receiveTimeout: const Duration(seconds: 90)));
      final form = dio.FormData.fromMap({
        'file': await dio.MultipartFile.fromFile(
          f.path,
          filename: f.filename,
          contentType: f.contentType == null ? null : dio.DioMediaType.parse(f.contentType!),
        ),
      });
      final res = await client.post(
        '${api.host}/api/aadhaar/extract',
        data: form,
        options: dio.Options(headers: api.authHeaders),
      );
      if ((res.statusCode ?? 500) >= 400) return null;
      return asJson(res.data).mN('fields');
    } catch (_) {
      return null;
    }
  }

  Future<void> _picked(UploadFile? f) async {
    if (f == null) return;
    setState(() {
      _processing = true;
      _error = null;
      _notice = null;
    });
    final fields = await _extract(f);
    if (!mounted) return;
    setState(() {
      _processing = false;
      if (fields == null) {
        _error = "Couldn't read that file. Try a different photo or PDF.";
        return;
      }
      if (fields.sn('candidateName') == null && fields.sn('dob') == null && fields.sn('address') == null) {
        _notice =
            "AI reading only found the Aadhaar No. — Name/Father's Name/DOB/Address weren't legible. Please fill the rest in manually.";
      } else if (fields.sn('aadharNoFull') == null) {
        _notice =
            "AI read the Aadhaar details, but the printed Aadhaar No. wasn't legible — please type it in manually.";
      }
    });
    if (fields != null) widget.onScanned(fields);
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Ts.rXl),
        border: Border.all(color: p.border),
        color: p.surfaceHover.withValues(alpha: 0.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_processing)
            Row(children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: p.accentViolet)),
              const SizedBox(width: 10),
              const Expanded(child: Muted('Reading document with AI…')),
            ])
          else ...[
            if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: StatusMessage.error(_error)),
            TsFileField(
              file: null,
              placeholder: _error == null ? 'Upload a photo or PDF of the Aadhaar' : 'Try a Photo/PDF Instead',
              accept: const ['pdf', 'jpg', 'jpeg', 'png'],
              onChanged: _picked,
            ),
            if (_notice != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_notice!, style: tx(14, color: p.warning)),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            "Fills Candidate Name, Father's/Guardian's Name (best guess — please verify), Date of Birth, Address and the full Aadhaar No. The photo/PDF is read by an AI model (sent to our server and Google's Gemini API for this step). Please verify what gets filled.",
            style: tx(12, color: p.muted, height: 1.45),
          ),
        ],
      ),
    );
  }
}
