import '../../widgets/ts.dart';
import 'widgets.dart';

TsBadge _candidateBadge(String status) => TsBadge(status, tone: candidateStatusTone[status] ?? BadgeTone.slate);

/// app/(app)/jobs/[id]/candidates/page.tsx + candidates-ranked-table.tsx.
class CandidatesScreen extends StatefulWidget {
  const CandidatesScreen({super.key, required this.jobId});
  final String jobId;

  @override
  State<CandidatesScreen> createState() => _CandidatesScreenState();
}

class _CandidatesScreenState extends State<CandidatesScreen> {
  final _cutoffCtrl = TextEditingController(text: '60');
  int _cutoff = 60;
  final Map<String, bool> _overrides = {};
  bool _moving = false;
  String? _error;

  @override
  void dispose() {
    _cutoffCtrl.dispose();
    super.dispose();
  }

  bool _eligible(Json c) => c.s('status') != 'WITHDRAWN' && c.at('currentRoundOrder') == null;

  bool _checked(Json c) {
    if (!_eligible(c)) return false;
    return _overrides[c.s('id')] ?? (c.iN('matchScore') ?? -1) >= _cutoff;
  }

  Future<void> _move(List<String> ids) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _moving = true;
      _error = null;
    });
    final r = await runAction(context, () => api.action('hiring.moveToRoundOne', args: [widget.jobId, ...ids]));
    if (!mounted) return;
    setState(() {
      _moving = false;
      _error = r.error;
      if (r.ok) _overrides.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/jobs/${widget.jobId}/candidates',
      header: const PageHeader(title: 'Candidates'),
      builder: (context, data, reload) {
        final candidates = data.l('candidates');
        final selected = [for (final c in candidates) if (_checked(c)) c.s('id')];
        return [
          PageHeader(title: 'Candidates', description: data.s('jobTitle')),
          TsPanel(
            child: Gap(
              gap: 12,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TsInput(
                  controller: _cutoffCtrl,
                  label: 'Minimum score to advance',
                  keyboardType: TextInputType.number,
                  inputFormatters: TsInput.digitsOnly,
                  maxLength: 3,
                  onChanged: (v) => setState(() => _cutoff = int.tryParse(v) ?? 0),
                ),
                TsButton(
                  label: 'Move ${selected.length} to Round 1',
                  pendingLabel: 'Moving...',
                  pending: _moving,
                  onPressed: selected.isEmpty ? null : () => _move(selected),
                ),
                if (_error != null) StatusMessage.error(_error),
              ],
            ),
          ),
          if (candidates.isEmpty) const EmptyState('No applications yet.'),
          for (final c in candidates)
            MobileCard(
              onTap: () => context.push('/jobs/${widget.jobId}/candidates/${c.s('id')}'),
              children: [
                MobileCardHeader(title: c.s('name'), action: _candidateBadge(c.s('status'))),
                MobileCardRows(rows: [
                  MobileCardRow(
                    label: 'Match Score',
                    value: c.sn('matchScore'),
                    child: c.has('matchScore') ? null : _RecomputeLink(candidateId: c.s('id')),
                  ),
                  MobileCardRow(label: 'Email', value: c.s('email')),
                  MobileCardRow(label: 'Mobile', value: c.s('mobileNo')),
                  MobileCardRow(label: 'Submitted', value: fmtDateTime(c.at('submittedAt'))),
                  MobileCardRow(label: 'Progress', value: roundProgressLabel(c.iN('currentRoundOrder'))),
                  MobileCardRow(
                    label: 'Round Result',
                    value: c.sn('latestResult.status') ?? '-',
                    child: c.has('latestResult')
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              TsBadge(c.s('latestResult.status'),
                                  tone: roundResultTone[c.s('latestResult.status')] ?? BadgeTone.slate),
                              if (c.has('latestResult.examScore'))
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text('Exam score: ${c.s('latestResult.examScore')}',
                                      style: tx(12, color: Ts.of(context).muted)),
                                ),
                            ],
                          )
                        : null,
                  ),
                ]),
                if (_eligible(c))
                  TsCheckbox(
                    label: 'Select for Round 1',
                    value: _checked(c),
                    onChanged: (_) => setState(() => _overrides[c.s('id')] = !_checked(c)),
                  ),
              ],
            ),
        ];
      },
    );
  }
}

/// The table's "Not scored - Recompute" link-button.
class _RecomputeLink extends StatefulWidget {
  const _RecomputeLink({required this.candidateId});
  final String candidateId;

  @override
  State<_RecomputeLink> createState() => _RecomputeLinkState();
}

class _RecomputeLinkState extends State<_RecomputeLink> {
  bool _pending = false;
  String? _error;

  Future<void> _run() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(context, () => api.action('hiring.recomputeCandidateMatchScore', args: [widget.candidateId]));
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TsLink(_pending ? 'Scoring...' : 'Not scored - Recompute', size: 12, onTap: _pending ? null : _run),
        if (_error != null) Text(_error!, textAlign: TextAlign.right, style: tx(12, color: p.danger)),
      ],
    );
  }
}

/// app/(app)/jobs/[id]/candidates/[candidateId]/page.tsx.
class CandidateDetailScreen extends StatelessWidget {
  const CandidateDetailScreen({super.key, required this.jobId, required this.candidateId});
  final String jobId;
  final String candidateId;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/jobs/$jobId/candidates/$candidateId',
      builder: (context, data, reload) {
        final c = data.m('candidate');
        final results = data.l('roundResults');
        final experiences = c.l('experiences');
        final answers = c.l('answers');
        final appointmentId = c.sn('appointmentId');
        final p = Ts.of(context);

        return [
          PageHeader(
            title: c.s('name'),
            description: c.s('email'),
            actions: [
              if (data.b('canCreateAppointment'))
                TsButton.secondary(
                  label: 'Create Appointment',
                  onPressed: () => context.push('/appointments/new?candidateId=${c.s('id')}'),
                ),
              if (appointmentId != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: TsLink('View Appointment →', onTap: () => context.push('/appointments/$appointmentId')),
                ),
              Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: _candidateBadge(c.s('status'))),
            ],
          ),
          if (c.b('autoPromoted')) const Muted("Waitlisted - auto-promoted after another candidate's offer fell through."),
          _MatchScoreCard(c: c),
          if (results.isNotEmpty)
            TsCard(
              title: 'Round History',
              child: Gap(
                gap: 12,
                children: [
                  for (final r in results)
                    BorderedBlock(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: StrongText(
                                  'Round ${r.i('roundOrder') + 1} — ${roundTypeLabel[r.s('roundType')] ?? r.s('roundType')}'),
                            ),
                            TsBadge(r.s('status'), tone: roundResultTone[r.s('status')] ?? BadgeTone.slate),
                          ],
                        ),
                        if (r.has('examScore')) MutedLine('Exam score: ${r.s('examScore')}'),
                        if (r.has('scheduledAt'))
                          MutedLine(
                              'Scheduled: ${fmtDateTime(r.at('scheduledAt'))}${r.sn('scheduledVenue') != null ? ' at ${r.s('scheduledVenue')}' : ''}'),
                        if (r.sn('notes') != null) MutedLine('Notes: ${r.s('notes')}'),
                        if (r.mN('panel') != null) _PanelScores(panel: r.m('panel')),
                        if ((r.s('roundType') == 'PHYSICAL_FITNESS' || r.s('roundType') == 'MEDICAL_FITNESS') &&
                            r.b('hasCertificate'))
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: TsLink('Download Certificate',
                                onTap: () => openHiringFile(context, '/api/files/fitness-certificate/${r.s('id')}')),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          TsCard(
            title: 'Personal Information',
            child: DetailList(rows: [
              DetailRow(label: 'Round Progress', value: roundProgressLabel(c.iN('currentRoundOrder'))),
              DetailRow(label: "Father's / Husband's Name", value: c.s('fatherName')),
              DetailRow(label: 'Date of Birth', value: fmtDate(c.at('dob'))),
              DetailRow(label: 'Gender', value: c.s('genderLabel')),
              DetailRow(label: 'Aadhaar Number', value: c.s('aadharNo')),
              DetailRow(label: 'Address', value: c.s('address')),
              DetailRow(label: 'Mobile', value: '${c.s('mobileNo')}${c.b('hasWhatsapp') ? ' (WhatsApp)' : ''}'),
              DetailRow(label: 'Email', value: c.s('email')),
              if (c.sn('referredByEmployeeName') != null)
                DetailRow(label: 'Referred By', value: c.s('referredByEmployeeName'))
              else if (c.sn('referredByNameRaw') != null)
                DetailRow(
                    label: 'Referred By', value: '${c.s('referredByNameRaw')} (not matched to an employee record)'),
            ]),
          ),
          TsCard(
            title: 'Education',
            child: DetailList(rows: [
              DetailRow(label: 'Highest Qualification', value: c.s('highestQualification')),
              if (c.has('gradePercentage')) DetailRow(label: 'Grade / Marks', value: '${c.s('gradePercentage')}%'),
              DetailRow(label: 'Board / University', value: c.s('boardOrUniversity')),
              DetailRow(label: 'Year of Passing', value: c.s('yearOfPassing')),
            ]),
          ),
          if (experiences.isNotEmpty)
            TsCard(
              title: 'Experience',
              child: Gap(
                gap: 12,
                children: [
                  for (final e in experiences)
                    BorderedBlock(children: [
                      StrongText('${e.s('role')} — ${e.s('company')}'),
                      MutedLine('${e.s('duration')} · ${e.s('areaOfExpertise')}'),
                    ]),
                ],
              ),
            ),
          TsCard(
            title: 'Additional Information',
            child: DetailList(rows: [
              if (c.sn('languagesKnown') != null) DetailRow(label: 'Languages Known', value: c.s('languagesKnown')),
              if (c.sn('hobbies') != null) DetailRow(label: 'Hobbies', value: c.s('hobbies')),
              if (c.sn('specialSkillsAndCertificates') != null)
                DetailRow(label: 'Special Skills / Certificates', value: c.s('specialSkillsAndCertificates')),
            ]),
          ),
          if (answers.isNotEmpty)
            TsCard(
              title: 'Additional Questions',
              child: DetailList(rows: [
                for (final a in answers) DetailRow(label: a.s('questionText'), value: a.s('answerText')),
              ]),
            ),
          TsCard(
            title: 'Resume',
            child: Align(
              alignment: Alignment.centerLeft,
              child: TsLink('Download Resume',
                  onTap: () => openHiringFile(context, '/api/files/candidate-resume/${c.s('id')}')),
            ),
          ),
          if (c.s('status') == 'WITHDRAWN' && c.has('withdrawnAt'))
            TsCard(
              title: 'Withdrawal',
              child: Text('Withdrawn on ${fmtDateTime(c.at('withdrawnAt'))}.', style: tx(14, color: p.muted)),
            ),
        ];
      },
    );
  }
}

class _PanelScores extends StatelessWidget {
  const _PanelScores({required this.panel});
  final Json panel;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final average = panel.at('average');
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: p.surfaceHover, borderRadius: BorderRadius.circular(Ts.rLg)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panel scores${average != null ? ' — average ${panel.s('average')}/10' : ' — no scores yet'}',
            style: tx(12, weight: FontWeight.w600, color: p.foreground),
          ),
          const SizedBox(height: 4),
          for (final s in panel.l('scores'))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${s.s('panelistName')}: ${s.b('submitted') ? '${s.s('score')}/10${s.sn('remarks') != null ? ' — ${s.s('remarks')}' : ''}' : 'not submitted'}',
                style: tx(12, color: p.muted),
              ),
            ),
        ],
      ),
    );
  }
}

/// match-score-card.tsx.
class _MatchScoreCard extends StatefulWidget {
  const _MatchScoreCard({required this.c});
  final Json c;

  @override
  State<_MatchScoreCard> createState() => _MatchScoreCardState();
}

class _MatchScoreCardState extends State<_MatchScoreCard> {
  bool _pending = false;
  String? _error;

  Future<void> _recompute() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(context, () => api.action('hiring.recomputeCandidateMatchScore', args: [widget.c.s('id')]));
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final c = widget.c;
    return TsCard(
      title: 'Match Score',
      child: Gap(
        gap: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.has('matchScore'))
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c.s('matchScore')}/100',
                    style: tx(28, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
                if (c.sn('matchScoreRationale') != null) MutedLine(c.s('matchScoreRationale')),
                if (c.has('matchScoreComputedAt')) MutedLine('Computed ${fmtDateTime(c.at('matchScoreComputedAt'))}', size: 12),
              ],
            )
          else
            const Muted('Not scored yet.'),
          TsButton.secondary(label: 'Recompute', pendingLabel: 'Scoring...', pending: _pending, onPressed: _recompute),
          if (_error != null) StatusMessage.error(_error),
        ],
      ),
    );
  }
}
