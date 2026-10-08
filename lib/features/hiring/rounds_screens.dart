import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/jobs/[id]/rounds/[roundId]/questions/page.tsx.
class McqQuestionsScreen extends StatelessWidget {
  const McqQuestionsScreen({super.key, required this.jobId, required this.roundId});
  final String jobId;
  final String roundId;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/jobs/$jobId/rounds/$roundId/questions',
      header: const PageHeader(title: 'MCQ Exam Questions'),
      builder: (context, data, reload) {
        final p = Ts.of(context);
        return [
          PageHeader(title: 'MCQ Exam Questions', description: data.s('jobTitle')),
          if (data.b('locked'))
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surfaceHover,
                borderRadius: BorderRadius.circular(Ts.rXl),
                border: Border.all(color: p.border),
              ),
              child: const Muted("This exam's scheduled time has already passed, so its questions can no longer be changed."),
            )
          else
            _QuestionsForm(roundId: roundId, questions: data.l('questions')),
        ];
      },
    );
  }
}

class _QuestionRow {
  _QuestionRow({String text = '', List<String> options = const ['', '', '', ''], this.correct = 0, int marks = 1})
      : text = TextEditingController(text: text),
        options = [for (var i = 0; i < 4; i++) TextEditingController(text: i < options.length ? options[i] : '')],
        marks = TextEditingController(text: '$marks');
  final TextEditingController text;
  final List<TextEditingController> options;
  int correct;
  final TextEditingController marks;

  bool get isBlank => text.text.trim().isEmpty;

  void dispose() {
    text.dispose();
    marks.dispose();
    for (final o in options) {
      o.dispose();
    }
  }
}

/// questions-form.tsx.
class _QuestionsForm extends StatefulWidget {
  const _QuestionsForm({required this.roundId, required this.questions});
  final String roundId;
  final List<Json> questions;

  @override
  State<_QuestionsForm> createState() => _QuestionsFormState();
}

class _QuestionsFormState extends State<_QuestionsForm> {
  late final List<_QuestionRow> _rows = widget.questions.isEmpty
      ? [_QuestionRow()]
      : [
          for (final q in widget.questions)
            _QuestionRow(
              text: q.s('questionText'),
              options: q.list<String>('options'),
              correct: q.i('correctOptionIndex'),
              marks: q.i('marks', 1),
            ),
        ];

  final _count = TextEditingController(text: '5');
  final _genMarks = TextEditingController(text: '1');
  String _difficulty = 'MEDIUM';
  bool _generating = false;
  String? _generateError;

  bool _pending = false;
  String? _error;
  bool _saved = false;

  @override
  void dispose() {
    _count.dispose();
    _genMarks.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _generateError = null;
    });
    final r = await api.action('hiring.generateMcqQuestionsForRound', args: [widget.roundId], fields: {
      'count': _count.text.isEmpty ? '0' : _count.text,
      'difficulty': _difficulty,
    });
    if (!mounted) return;
    setState(() {
      _generating = false;
      if (!r.ok) {
        _generateError = r.error;
        return;
      }
      final marks = int.tryParse(_genMarks.text) ?? 0;
      // Drop the single still-blank starter row.
      if (_rows.length == 1 && _rows.first.isBlank) disposeAfterFrame(_rows.removeAt(0).dispose);
      for (final q in r.data?.l('questions') ?? const <Json>[]) {
        _rows.add(_QuestionRow(
          text: q.s('questionText'),
          options: q.list<String>('options'),
          correct: q.i('correctOptionIndex'),
          marks: marks,
        ));
      }
    });
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
      _saved = false;
    });
    final r = await runAction(
      context,
      () => api.action('hiring.saveMcqQuestions', args: [widget.roundId], fields: {
        'questionText': [for (final q in _rows) q.text.text],
        for (var o = 0; o < 4; o++) 'option$o': [for (final q in _rows) q.options[o].text],
        'correctOptionIndex': [for (final q in _rows) '${q.correct}'],
        'marks': [for (final q in _rows) q.marks.text],
      }),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _saved = r.ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Gap(
      gap: 16,
      children: [
        TsPanel(
          child: Gap(
            gap: 12,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TsInput(
                controller: _count,
                label: 'Generate with AI',
                hint: 'Number of questions to draft',
                keyboardType: TextInputType.number,
                inputFormatters: TsInput.digitsOnly,
                maxLength: 2,
              ),
              TsInput(
                controller: _genMarks,
                label: 'Marks per Question',
                keyboardType: TextInputType.number,
                inputFormatters: TsInput.digitsOnly,
              ),
              TsSelect<String>(
                label: 'Complexity',
                value: _difficulty,
                options: const [SelectOption('EASY', 'Easy'), SelectOption('MEDIUM', 'Medium'), SelectOption('HARD', 'Hard')],
                onChanged: (v) => setState(() => _difficulty = v ?? _difficulty),
              ),
              TsButton.secondary(
                label: 'Generate Questions',
                pendingLabel: 'Generating...',
                pending: _generating,
                onPressed: _generate,
              ),
              if (_generateError != null) StatusMessage.error(_generateError),
            ],
          ),
        ),
        const Muted(
          'AI-generated questions are added below as editable drafts - review each one (and the marked correct option) before saving.',
          size: 12,
        ),
        for (var i = 0; i < _rows.length; i++) _questionCard(i, _rows[i]),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton.secondary(label: '+ Add Question', onPressed: () => setState(() => _rows.add(_QuestionRow()))),
        ),
        Gap(
          gap: 12,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) StatusMessage.error(_error),
            if (_saved) StatusMessage.success('Saved.'),
            TsButton(label: 'Save Questions', pendingLabel: 'Saving...', pending: _pending, onPressed: _save),
          ],
        ),
      ],
    );
  }

  Widget _questionCard(int i, _QuestionRow q) {
    final p = Ts.of(context);
    return TsPanel(
      child: Gap(
        gap: 12,
        children: [
          Row(
            children: [
              Expanded(child: Text('Question ${i + 1}', style: tx(14, weight: FontWeight.w600, color: p.foreground))),
              TsButton.danger(
                label: 'Remove',
                compact: true,
                onPressed: () => setState(() => disposeAfterFrame(_rows.removeAt(i).dispose)),
              ),
            ],
          ),
          TsInput(controller: q.text, label: 'Question Text', maxLines: 3, minLines: 1),
          for (var o = 0; o < 4; o++)
            TsInput(controller: q.options[o], label: 'Option ${o + 1}', onChanged: (_) => setState(() {})),
          TsSelect<int>(
            label: 'Correct Option',
            value: q.correct,
            options: [
              for (var o = 0; o < 4; o++)
                SelectOption(o, q.options[o].text.trim().isNotEmpty ? '${o + 1}. ${q.options[o].text}' : 'Option ${o + 1}'),
            ],
            onChanged: (v) => setState(() => q.correct = v ?? q.correct),
          ),
          TsInput(
            controller: q.marks,
            label: 'Marks',
            keyboardType: TextInputType.number,
            inputFormatters: TsInput.digitsOnly,
          ),
        ],
      ),
    );
  }
}

/// app/(app)/jobs/[id]/rounds/[roundId]/schedule/page.tsx.
class RoundScheduleScreen extends StatelessWidget {
  const RoundScheduleScreen({super.key, required this.jobId, required this.roundId});
  final String jobId;
  final String roundId;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/jobs/$jobId/rounds/$roundId/schedule',
      header: const PageHeader(title: 'Schedule & Results'),
      builder: (context, data, reload) {
        final isInterview = data.b('isInterview');
        final awaitingScheduling = data.l('awaitingScheduling');
        final awaitingDecision = data.l('awaitingDecision');
        final finalized = data.l('finalized');
        return [
          PageHeader(title: 'Schedule & Results — ${data.s('roundLabel')}', description: data.s('jobTitle')),
          TsCard(
            title: 'Awaiting Scheduling (${awaitingScheduling.length})',
            child: awaitingScheduling.isEmpty
                ? const Muted('No candidates waiting to be scheduled.')
                : _ScheduleForm(
                    roundId: roundId,
                    isInterview: isInterview,
                    candidates: awaitingScheduling,
                    venues: data.list<String>('venues'),
                    panelists: data.l('panelists'),
                  ),
          ),
          TsCard(
            title: 'Scheduled — Awaiting ${isInterview ? 'Decision' : 'Outcome'} (${awaitingDecision.length})',
            child: awaitingDecision.isEmpty
                ? const Muted('Nothing scheduled and pending a result right now.')
                : Gap(
                    gap: 16,
                    children: [
                      for (final r in awaitingDecision)
                        isInterview
                            ? _FinalizeInterviewForm(key: ValueKey(r.s('resultId')), r: r)
                            : _FitnessOutcomeForm(key: ValueKey(r.s('resultId')), r: r),
                    ],
                  ),
          ),
          if (finalized.isNotEmpty)
            TsCard(
              title: 'Finalized',
              child: Gap(
                gap: 8,
                children: [
                  for (final r in finalized)
                    TsPanel(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(child: StrongText(r.s('name'))),
                          Text(r.s('status'), style: tx(14, color: Ts.of(context).muted)),
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

/// schedule-interview-form.tsx / schedule-fitness-form.tsx.
class _ScheduleForm extends StatefulWidget {
  const _ScheduleForm({
    required this.roundId,
    required this.isInterview,
    required this.candidates,
    required this.venues,
    required this.panelists,
  });
  final String roundId;
  final bool isInterview;
  final List<Json> candidates;
  final List<String> venues;
  final List<Json> panelists;

  @override
  State<_ScheduleForm> createState() => _ScheduleFormState();
}

class _ScheduleFormState extends State<_ScheduleForm> {
  final Set<String> _candidateIds = {};
  final Set<String> _panelistIds = {};
  String _scheduledAt = '';
  final _venue = TextEditingController();
  bool _pending = false;
  String? _error;
  bool _scheduled = false;

  @override
  void dispose() {
    _venue.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
      _scheduled = false;
    });
    final r = await runAction(
      context,
      () => api.action(
        widget.isInterview ? 'hiring.scheduleInterview' : 'hiring.scheduleFitnessRound',
        args: [widget.roundId, ..._candidateIds],
        fields: {
          'scheduledAt': _scheduledAt,
          'venue': _venue.text,
          if (widget.isInterview) 'panelistEmployeeIds': _panelistIds.toList(),
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _scheduled = r.ok;
      if (r.ok) _candidateIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final n = _candidateIds.length;
    final noun = widget.isInterview ? 'Interview' : 'Candidate';
    return Gap(
      gap: 16,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Candidates', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
            for (final c in widget.candidates)
              TsCheckbox(
                label: c.s('name'),
                value: _candidateIds.contains(c.s('candidateId')),
                onChanged: (v) => setState(() => v ? _candidateIds.add(c.s('candidateId')) : _candidateIds.remove(c.s('candidateId'))),
              ),
          ],
        ),
        DateTimeLocalField(label: 'Date & Time', value: _scheduledAt, onChanged: (v) => setState(() => _scheduledAt = v)),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TsInput(
              controller: _venue,
              label: 'Venue',
              hint: widget.venues.isEmpty ? null : widget.venues.join(' / '),
            ),
            if (widget.venues.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final v in widget.venues)
                      GestureDetector(
                        onTap: () => setState(() => _venue.text = v),
                        child: TsPill(v, tone: _venue.text == v ? BadgeTone.purple : BadgeTone.slate),
                      ),
                  ],
                ),
              ),
          ],
        ),
        if (widget.isInterview)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Panel', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
              if (widget.panelists.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Muted('No employees with portal login are available to assign as panelists.'),
                )
              else
                for (final e in widget.panelists)
                  TsCheckbox(
                    label: '${e.s('name')} — ${e.s('designation')}',
                    value: _panelistIds.contains(e.s('id')),
                    onChanged: (v) => setState(() => v ? _panelistIds.add(e.s('id')) : _panelistIds.remove(e.s('id'))),
                  ),
              const SizedBox(height: 4),
              Text('Only employees with portal login can be assigned as panelists.', style: tx(12, color: p.muted)),
            ],
          ),
        if (_error != null) StatusMessage.error(_error),
        if (_scheduled) StatusMessage.success('Scheduled.'),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton(
            label: 'Schedule ${n == 0 ? '' : n} $noun${n == 1 ? '' : 's'}',
            pendingLabel: 'Scheduling...',
            pending: _pending,
            onPressed: n == 0 ? null : _submit,
          ),
        ),
      ],
    );
  }
}

String _whenWhere(Json r) =>
    '${r.has('scheduledAt') ? fmtDateTime(r.at('scheduledAt')) : ''}${r.sn('scheduledVenue') != null ? ' · ${r.s('scheduledVenue')}' : ''}';

/// finalize-interview-form.tsx.
class _FinalizeInterviewForm extends StatefulWidget {
  const _FinalizeInterviewForm({super.key, required this.r});
  final Json r;

  @override
  State<_FinalizeInterviewForm> createState() => _FinalizeInterviewFormState();
}

class _FinalizeInterviewFormState extends State<_FinalizeInterviewForm> {
  String? _decision;
  final _notes = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    final res = await runAction(
      context,
      () => api.action('hiring.finalizeInterviewRound',
          args: [widget.r.s('resultId')], fields: {'decision': _decision ?? '', 'notes': _notes.text}),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = res.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final average = r.at('averageScore');
    return BorderedBlock(
      padding: const EdgeInsets.all(16),
      children: [
        StrongText(r.s('name')),
        MutedLine(_whenWhere(r)),
        MutedLine(
            'Panel: ${r.i('panelSubmitted')}/${r.i('panelTotal')} submitted${average != null ? ' · Reference average: ${r.s('averageScore')}/10' : ' · No scores yet'}'),
        const SizedBox(height: 12),
        TsSelect<String>(
          label: 'Decision',
          value: _decision,
          options: const [SelectOption('PASSED', 'Passed'), SelectOption('FAILED', 'Failed')],
          onChanged: (v) => setState(() => _decision = v),
        ),
        const SizedBox(height: 12),
        TsTextarea(controller: _notes, label: 'Notes', rows: 2),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: StatusMessage.error(_error)),
        const SizedBox(height: 12),
        TsButton(label: 'Finalize', pendingLabel: 'Finalizing...', pending: _pending, onPressed: _submit),
      ],
    );
  }
}

/// record-fitness-outcome-form.tsx.
class _FitnessOutcomeForm extends StatefulWidget {
  const _FitnessOutcomeForm({super.key, required this.r});
  final Json r;

  @override
  State<_FitnessOutcomeForm> createState() => _FitnessOutcomeFormState();
}

class _FitnessOutcomeFormState extends State<_FitnessOutcomeForm> {
  String? _outcome;
  final _notes = TextEditingController();
  UploadFile? _certificate;
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    final res = await runAction(
      context,
      () => api.action(
        'hiring.recordFitnessOutcome',
        args: [widget.r.s('resultId')],
        fields: {'outcome': _outcome ?? '', 'notes': _notes.text},
        files: {'certificate': _certificate},
      ),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = res.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    return BorderedBlock(
      padding: const EdgeInsets.all(16),
      children: [
        StrongText(r.s('name')),
        MutedLine(_whenWhere(r)),
        const SizedBox(height: 12),
        TsSelect<String>(
          label: 'Outcome',
          value: _outcome,
          options: const [
            SelectOption('PASSED', 'Passed'),
            SelectOption('FAILED', 'Failed'),
            SelectOption('DISQUALIFIED', 'Disqualified'),
          ],
          onChanged: (v) => setState(() => _outcome = v),
        ),
        const SizedBox(height: 12),
        TsTextarea(controller: _notes, label: 'Notes', rows: 2),
        const SizedBox(height: 12),
        TsFileField(
          label: 'Certificate (optional)',
          file: _certificate,
          accept: const ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png'],
          onChanged: (f) => setState(() => _certificate = f),
        ),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: StatusMessage.error(_error)),
        const SizedBox(height: 12),
        TsButton(label: 'Record Outcome', pendingLabel: 'Saving...', pending: _pending, onPressed: _submit),
      ],
    );
  }
}
