import 'dart:convert';

import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/jobs/new/page.tsx.
class NewJobScreen extends StatelessWidget {
  const NewJobScreen({super.key});

  static const _header = PageHeader(title: 'New Job Requisition');

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/jobs/new',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        JobForm(defaultOfficeAddress: data.s('defaultOfficeAddress')),
      ],
    );
  }
}

/// app/(app)/jobs/[id]/edit/page.tsx.
class EditJobScreen extends StatelessWidget {
  const EditJobScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/jobs/$id/edit',
      builder: (context, data, reload) => [
        PageHeader(title: 'Edit ${data.s('job.title')}'),
        JobForm(defaultOfficeAddress: data.s('defaultOfficeAddress'), job: data.m('job'), jobId: id),
      ],
    );
  }
}

TextEditingController _ctrl(Object? value) => TextEditingController(text: value?.toString() ?? '');

class _Venues {
  _Venues(List<String> values) : rows = [for (final v in values) TextEditingController(text: v)];
  final List<TextEditingController> rows;

  String toJson() => jsonEncode(rows.map((c) => c.text).where((v) => v.trim().isNotEmpty).toList());

  void dispose() {
    for (final c in rows) {
      c.dispose();
    }
  }
}

/// One selection round's fields. Every field is posted for every round
/// (the web keeps them all mounted) so the parallel arrays stay aligned.
class _Round {
  _Round.empty(String defaultVenue)
      : type = 'MCQ_EXAM',
        examTopicType = 'APTITUDE',
        examTopicOther = _ctrl(null),
        examScheduledAt = '',
        examDurationMinutes = _ctrl(null),
        examFullMarks = _ctrl(null),
        examNegative = _ctrl(null),
        examCutoff = _ctrl(null),
        interviewNature = 'GENERAL',
        interviewNatureOther = _ctrl(null),
        interviewVenues = _Venues(defaultVenue.isEmpty ? [] : [defaultVenue]),
        physicalNature = 'RUNNING',
        physicalNatureOther = _ctrl(null),
        physicalVenues = _Venues(defaultVenue.isEmpty ? [] : [defaultVenue]),
        physicalInstructions = _ctrl(null),
        medicalProcedure = _ctrl(null),
        medicalVenues = _Venues(defaultVenue.isEmpty ? [] : [defaultVenue]),
        medicalCertificateRequired = '';

  _Round.from(Json r)
      : type = r.s('type', 'MCQ_EXAM'),
        examTopicType = r.sn('examTopicType') ?? 'APTITUDE',
        examTopicOther = _ctrl(r.at('examTopicOther')),
        examScheduledAt = r.s('examScheduledAt'),
        examDurationMinutes = _ctrl(r.at('examDurationMinutes')),
        examFullMarks = _ctrl(r.at('examFullMarks')),
        examNegative = _ctrl(r.at('examNegativeMarkingPerWrong')),
        examCutoff = _ctrl(r.at('examCutoffMarks')),
        interviewNature = r.sn('interviewNature') ?? 'GENERAL',
        interviewNatureOther = _ctrl(r.at('interviewNatureOther')),
        interviewVenues = _Venues(r.list<String>('interviewVenues')),
        physicalNature = r.sn('physicalNature') ?? 'RUNNING',
        physicalNatureOther = _ctrl(r.at('physicalNatureOther')),
        physicalVenues = _Venues(r.list<String>('physicalVenues')),
        physicalInstructions = _ctrl(r.at('physicalInstructions')),
        medicalProcedure = _ctrl(r.at('medicalProcedure')),
        medicalVenues = _Venues(r.list<String>('medicalVenues')),
        medicalCertificateRequired = r.at('medicalCertificateRequired') == null
            ? ''
            : (r.b('medicalCertificateRequired') ? 'yes' : 'no');

  String type;
  String examTopicType;
  final TextEditingController examTopicOther;
  String examScheduledAt;
  final TextEditingController examDurationMinutes, examFullMarks, examNegative, examCutoff;
  String interviewNature;
  final TextEditingController interviewNatureOther;
  final _Venues interviewVenues;
  String physicalNature;
  final TextEditingController physicalNatureOther;
  final _Venues physicalVenues;
  final TextEditingController physicalInstructions, medicalProcedure;
  final _Venues medicalVenues;
  String medicalCertificateRequired;

  void dispose() {
    for (final c in [
      examTopicOther, examDurationMinutes, examFullMarks, examNegative, examCutoff, interviewNatureOther,
      physicalNatureOther, physicalInstructions, medicalProcedure,
    ]) {
      c.dispose();
    }
    interviewVenues.dispose();
    physicalVenues.dispose();
    medicalVenues.dispose();
  }
}

class _Question {
  _Question(String text, this.required) : text = TextEditingController(text: text);
  final TextEditingController text;
  bool required;
}

/// app/(app)/jobs/job-form.tsx.
class JobForm extends StatefulWidget {
  const JobForm({super.key, required this.defaultOfficeAddress, this.job, this.jobId});
  final String defaultOfficeAddress;
  final Json? job;
  final String? jobId;

  @override
  State<JobForm> createState() => _JobFormState();
}

class _JobFormState extends State<JobForm> {
  late final Json _j = widget.job ?? const {};
  late final _title = _ctrl(_j.at('title'));
  late final _designation = _ctrl(_j.at('designation'));
  late final _department = _ctrl(_j.at('department'));
  late final _vacancyCount = _ctrl(_j.at('vacancyCount'));
  late final _minQualification = _ctrl(_j.at('minQualification'));
  late final _minGradeOrMarks = _ctrl(_j.at('minGradeOrMarks'));
  late final _minExperienceYears = _ctrl(_j.at('minExperienceYears'));
  late final _industryExperience = _ctrl(_j.at('industryExperience'));
  late bool _industryExperienceRequired = _j.b('industryExperienceRequired');
  late String _jobType = _j.sn('jobType') ?? 'PERMANENT';
  late final _internshipDurationMonths = _ctrl(_j.at('internshipDurationMonths'));
  late bool _internshipIsPaid = _j.b('internshipIsPaid');
  late final _internshipStipendAmount = _ctrl(_j.at('internshipStipendAmount'));
  late bool _internshipCanRegularize = _j.b('internshipCanRegularize');
  late final _temporaryDurationMonths = _ctrl(_j.at('temporaryDurationMonths'));
  late String _temporaryPayStructure = _j.sn('temporaryPayStructure') ?? 'CONSOLIDATED';
  late final _temporaryPayAmount = _ctrl(_j.at('temporaryPayAmount'));
  late final _permanentCTC = _ctrl(_j.at('permanentCTC'));
  late bool _paymentNegotiable = _j.b('paymentNegotiable');
  late bool _paymentNoBar = _j.b('paymentNoBarForRightCandidate');
  late final _location = _ctrl(_j.at('location'));
  late String _jobNature = _j.sn('jobNature') ?? 'WFO';
  late final _officeAddress = TextEditingController(
      text: widget.job == null ? widget.defaultOfficeAddress : (_j.sn('officeAddress') ?? widget.defaultOfficeAddress));
  late String? _applicationDeadline = _j.sn('applicationDeadline');
  late final _terms = _ctrl(_j.at('termsAndConditions'));
  late final List<_Round> _rounds = _j.l('selectionRounds').isEmpty
      ? [_Round.empty(widget.defaultOfficeAddress)]
      : [for (final r in _j.l('selectionRounds')) _Round.from(r)];
  late final List<_Question> _questions = [
    for (final q in _j.l('applicationQuestions')) _Question(q.s('questionText'), q.b('required')),
  ];

  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _title, _designation, _department, _vacancyCount, _minQualification, _minGradeOrMarks, _minExperienceYears,
      _industryExperience, _internshipDurationMonths, _internshipStipendAmount, _temporaryDurationMonths,
      _temporaryPayAmount, _permanentCTC, _location, _officeAddress, _terms,
    ]) {
      c.dispose();
    }
    for (final r in _rounds) {
      r.dispose();
    }
    for (final q in _questions) {
      q.text.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _fields() {
    List<String> each(String Function(_Round r) f) => [for (final r in _rounds) f(r)];
    return {
      'title': _title.text,
      'designation': _designation.text,
      'department': _department.text,
      'vacancyCount': _vacancyCount.text,
      'minQualification': _minQualification.text,
      'minGradeOrMarks': _minGradeOrMarks.text,
      'minExperienceYears': _minExperienceYears.text,
      'industryExperience': _industryExperience.text,
      if (_industryExperienceRequired) 'industryExperienceRequired': 'on',
      'jobType': _jobType,
      if (_jobType == 'INTERNSHIP') ...{
        'internshipDurationMonths': _internshipDurationMonths.text,
        if (_internshipIsPaid) 'internshipIsPaid': 'on',
        'internshipStipendAmount': _internshipStipendAmount.text,
        if (_internshipCanRegularize) 'internshipCanRegularize': 'on',
      },
      if (_jobType == 'TEMPORARY') ...{
        'temporaryDurationMonths': _temporaryDurationMonths.text,
        'temporaryPayStructure': _temporaryPayStructure,
        'temporaryPayAmount': _temporaryPayAmount.text,
      },
      if (_jobType == 'PERMANENT') 'permanentCTC': _permanentCTC.text,
      if (_paymentNegotiable) 'paymentNegotiable': 'on',
      if (_paymentNoBar) 'paymentNoBarForRightCandidate': 'on',
      'location': _location.text,
      'jobNature': _jobNature,
      'officeAddress': _officeAddress.text,
      'applicationDeadline': _applicationDeadline ?? '',
      'termsAndConditions': _terms.text,
      'roundType': each((r) => r.type),
      'examTopicType': each((r) => r.examTopicType),
      'examTopicOther': each((r) => r.examTopicOther.text),
      'examScheduledAt': each((r) => r.examScheduledAt),
      'examDurationMinutes': each((r) => r.examDurationMinutes.text),
      'examFullMarks': each((r) => r.examFullMarks.text),
      'examNegativeMarkingPerWrong': each((r) => r.examNegative.text),
      'examCutoffMarks': each((r) => r.examCutoff.text),
      'interviewNature': each((r) => r.interviewNature),
      'interviewNatureOther': each((r) => r.interviewNatureOther.text),
      'interviewVenues': each((r) => r.interviewVenues.toJson()),
      'physicalNature': each((r) => r.physicalNature),
      'physicalNatureOther': each((r) => r.physicalNatureOther.text),
      'physicalVenues': each((r) => r.physicalVenues.toJson()),
      'physicalInstructions': each((r) => r.physicalInstructions.text),
      'medicalProcedure': each((r) => r.medicalProcedure.text),
      'medicalVenues': each((r) => r.medicalVenues.toJson()),
      'medicalCertificateRequired': each((r) => r.medicalCertificateRequired),
      'applicationQuestions': jsonEncode([
        for (final q in _questions)
          if (q.text.text.trim().isNotEmpty) {'questionText': q.text.text, 'required': q.required},
      ]),
    };
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    final fields = _fields();
    final r = await runAction(
      context,
      () => widget.jobId == null
          ? api.action('hiring.createJob', fields: fields)
          : api.action('hiring.updateJob', fields: fields, args: [widget.jobId!]),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  TsInput _number(TextEditingController c, String label, {String? hint, bool decimal = false}) => TsInput(
        controller: c,
        label: label,
        hint: hint,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: decimal ? null : TsInput.digitsOnly,
      );

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Gap(
      gap: 24,
      children: [
        FormSection(title: 'Job Basics', children: [
          TsInput(controller: _title, label: 'Job Name'),
          TsInput(controller: _designation, label: 'Designation / Post'),
          TsInput(controller: _department, label: 'Department'),
          _number(_vacancyCount, 'Number of Vacancies'),
        ]),
        FormSection(title: 'Eligibility', children: [
          TsInput(controller: _minQualification, label: 'Minimum Educational Qualification'),
          TsInput(
            controller: _minGradeOrMarks,
            label: 'Minimum Grade / Marks (if any)',
            placeholder: 'e.g. 60%, CGPA 7.0, First Class',
          ),
          _number(_minExperienceYears, 'Minimum Work Experience (years)'),
          TsInput(controller: _industryExperience, label: 'Specific Industry Experience'),
          TsCheckbox(
            label: 'Industry experience is mandatory (unchecked = optional)',
            value: _industryExperienceRequired,
            onChanged: (v) => setState(() => _industryExperienceRequired = v),
          ),
        ]),
        FormSection(title: 'Job Type & Compensation', children: [
          TsSelect<String>(
            label: 'Type of Job',
            value: _jobType,
            options: const [
              SelectOption('INTERNSHIP', 'Internship'),
              SelectOption('TEMPORARY', 'Temporary'),
              SelectOption('PERMANENT', 'Permanent'),
            ],
            onChanged: (v) => setState(() => _jobType = v ?? _jobType),
          ),
          if (_jobType == 'INTERNSHIP') ...[
            _number(_internshipDurationMonths, 'Internship Duration (months)'),
            TsCheckbox(
              label: 'Paid internship',
              value: _internshipIsPaid,
              onChanged: (v) => setState(() => _internshipIsPaid = v),
            ),
            _number(_internshipStipendAmount, 'Stipend Amount (₹/month)'),
            TsCheckbox(
              label: 'Option to regularize into a permanent post',
              value: _internshipCanRegularize,
              onChanged: (v) => setState(() => _internshipCanRegularize = v),
            ),
          ],
          if (_jobType == 'TEMPORARY') ...[
            _number(_temporaryDurationMonths, 'Duration (months)'),
            TsSelect<String>(
              label: 'Pay Structure',
              value: _temporaryPayStructure,
              options: const [SelectOption('CONSOLIDATED', 'Consolidated Pay'), SelectOption('REGULAR', 'Regular Pay')],
              onChanged: (v) => setState(() => _temporaryPayStructure = v ?? _temporaryPayStructure),
            ),
            _number(_temporaryPayAmount, 'Pay Amount (₹)'),
          ],
          if (_jobType == 'PERMANENT') _number(_permanentCTC, 'CTC (₹/year)'),
          Wrap(
            spacing: 16,
            children: [
              TsCheckbox(
                label: 'Negotiable',
                value: _paymentNegotiable,
                onChanged: (v) => setState(() => _paymentNegotiable = v),
              ),
              TsCheckbox(
                label: 'No Bar for the right candidate',
                value: _paymentNoBar,
                onChanged: (v) => setState(() => _paymentNoBar = v),
              ),
            ],
          ),
        ]),
        FormSection(title: 'Location & Nature of Job', children: [
          TsInput(controller: _location, label: 'Job Location'),
          TsSelect<String>(
            label: 'Nature of Job',
            value: _jobNature,
            options: const [
              SelectOption('WFO', 'Work From Office Only'),
              SelectOption('WFH', 'Work From Home Only'),
              SelectOption('HYBRID', 'Hybrid'),
              SelectOption('ON_SITE', 'On-Site'),
              SelectOption('FIELD_JOB', 'Field Job'),
            ],
            onChanged: (v) => setState(() => _jobNature = v ?? _jobNature),
          ),
          TsInput(
            controller: _officeAddress,
            label: 'Office Address',
            hint: 'Pre-filled from Company Settings - edit freely for this job.',
          ),
        ]),
        FormSection(title: 'Application', children: [
          TsDateField(
            label: 'Application Deadline',
            value: _applicationDeadline,
            onChanged: (v) => setState(() => _applicationDeadline = v),
          ),
          TsTextarea(controller: _terms, label: 'Terms & Conditions (shown to candidates at application)', rows: 3),
        ]),
        FormSection(title: 'Selection Process', children: [
          for (var i = 0; i < _rounds.length; i++) _roundCard(i, _rounds[i]),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton.secondary(
              label: '+ Add Round',
              onPressed: () => setState(() => _rounds.add(_Round.empty(widget.defaultOfficeAddress))),
            ),
          ),
        ]),
        FormSection(title: 'Additional Application Questions (optional)', children: [
          const Muted(
              'Ask candidates anything beyond the standard personal/education/experience fields - shown on the public application form.'),
          for (var i = 0; i < _questions.length; i++)
            TsPanel(
              padding: const EdgeInsets.all(12),
              child: Gap(
                gap: 8,
                children: [
                  TsInput(
                    controller: _questions[i].text,
                    label: 'Question ${i + 1}',
                    placeholder: 'e.g. Do you have a two-wheeler license?',
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TsCheckbox(
                          label: 'Required',
                          value: _questions[i].required,
                          onChanged: (v) => setState(() => _questions[i].required = v),
                        ),
                      ),
                      TsButton.danger(
                        label: 'Remove',
                        compact: true,
                        onPressed: () => setState(() => disposeAfterFrame(_questions.removeAt(i).text.dispose)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton.secondary(
              label: '+ Add Question',
              onPressed: () => setState(() => _questions.add(_Question('', true))),
            ),
          ),
        ]),
        Gap(
          gap: 12,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) Text(_error!, style: tx(14, color: p.danger)),
            TsButton(
              label: widget.jobId == null ? 'Save as Draft' : 'Save Changes',
              pendingLabel: 'Saving...',
              pending: _pending,
              onPressed: _submit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _roundCard(int index, _Round r) {
    return TsPanel(
      child: Gap(
        gap: 14,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TsSelect<String>(
                  label: 'Round ${index + 1} Type',
                  value: r.type,
                  options: const [
                    SelectOption('MCQ_EXAM', 'MCQ Online Exam'),
                    SelectOption('INTERVIEW', 'Interview'),
                    SelectOption('PHYSICAL_FITNESS', 'Physical Fitness'),
                    SelectOption('MEDICAL_FITNESS', 'Medical Fitness'),
                  ],
                  onChanged: (v) => setState(() => r.type = v ?? r.type),
                ),
              ),
              const SizedBox(width: 10),
              TsButton.danger(
                label: 'Remove',
                compact: true,
                onPressed: () => setState(() => disposeAfterFrame(_rounds.removeAt(index).dispose)),
              ),
            ],
          ),
          if (r.type == 'MCQ_EXAM') ...[
            TsSelect<String>(
              label: 'Exam Topic',
              value: r.examTopicType,
              options: const [
                SelectOption('APTITUDE', 'Aptitude'),
                SelectOption('TECHNICAL', 'Technical'),
                SelectOption('OTHER', 'Other'),
              ],
              onChanged: (v) => setState(() => r.examTopicType = v ?? r.examTopicType),
            ),
            TsInput(controller: r.examTopicOther, label: 'Topic (if Other)'),
            DateTimeLocalField(
              label: 'Exam Date & Time',
              value: r.examScheduledAt,
              onChanged: (v) => setState(() => r.examScheduledAt = v),
            ),
            _number(r.examDurationMinutes, 'Duration (minutes)'),
            _number(r.examFullMarks, 'Full Marks'),
            _number(r.examNegative, 'Negative Marking (per wrong answer)',
                hint: 'Leave blank for no negative marking.', decimal: true),
            _number(r.examCutoff, 'Cutoff Marks'),
          ],
          if (r.type == 'INTERVIEW') ...[
            TsSelect<String>(
              label: 'Interview Nature',
              value: r.interviewNature,
              options: const [
                SelectOption('GENERAL', 'General'),
                SelectOption('TECHNICAL', 'Technical'),
                SelectOption('HR', 'HR'),
                SelectOption('OTHER', 'Other'),
              ],
              onChanged: (v) => setState(() => r.interviewNature = v ?? r.interviewNature),
            ),
            TsInput(controller: r.interviewNatureOther, label: 'Nature (if Other)'),
            _venueList(
              r.interviewVenues,
              hint:
                  'Actual candidate-by-candidate date & time slots are scheduled later, once candidates apply. Add more than one centre if candidates will be interviewed at different locations.',
            ),
          ],
          if (r.type == 'PHYSICAL_FITNESS') ...[
            TsSelect<String>(
              label: 'Test Nature',
              value: r.physicalNature,
              options: const [
                SelectOption('RUNNING', 'Running'),
                SelectOption('TREADMILL_TEST', 'Treadmill Test'),
                SelectOption('OTHER', 'Other'),
              ],
              onChanged: (v) => setState(() => r.physicalNature = v ?? r.physicalNature),
            ),
            TsInput(controller: r.physicalNatureOther, label: 'Nature (if Other)'),
            _venueList(r.physicalVenues),
            TsTextarea(controller: r.physicalInstructions, label: 'Procedure / Instructions', rows: 3),
          ],
          if (r.type == 'MEDICAL_FITNESS') ...[
            TsTextarea(controller: r.medicalProcedure, label: 'Procedure', rows: 3),
            _venueList(r.medicalVenues),
            TsSelect<String>(
              label: 'Certificate Required',
              value: r.medicalCertificateRequired,
              options: const [SelectOption('', '— Select —'), SelectOption('yes', 'Yes'), SelectOption('no', 'No')],
              onChanged: (v) => setState(() => r.medicalCertificateRequired = v ?? ''),
            ),
          ],
        ],
      ),
    );
  }

  /// VenueListField: always at least one (possibly blank) row.
  Widget _venueList(_Venues venues, {String? hint}) {
    final p = Ts.of(context);
    if (venues.rows.isEmpty) venues.rows.add(TextEditingController());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Venue(s)', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint, style: tx(12, color: p.muted))),
        for (var i = 0; i < venues.rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(child: TsInput(controller: venues.rows[i], placeholder: 'Centre address')),
                if (venues.rows.length > 1)
                  TsButton.ghost(
                    label: 'Remove',
                    compact: true,
                    onPressed: () => setState(() => disposeAfterFrame(venues.rows.removeAt(i).dispose)),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton.secondary(
            label: '+ Add Centre',
            compact: true,
            onPressed: () => setState(() => venues.rows.add(TextEditingController())),
          ),
        ),
      ],
    );
  }
}
