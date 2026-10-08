import 'package:flutter/services.dart';

import '../../widgets/ts.dart';
import 'widgets.dart';

TsBadge _jobBadge(String status) => TsBadge(status, tone: jobStatusTone[status] ?? BadgeTone.slate);

/// app/(app)/jobs/page.tsx.
class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  final _q = TextEditingController();
  String _status = '';
  String _appliedQ = '';
  String _appliedStatus = '';

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(
      title: 'Jobs',
      actions: [TsButton(label: 'New Job', onPressed: () => context.push('/jobs/new'))],
    );
    return ApiScreen(
      path: '/jobs',
      query: {'q': _appliedQ, 'status': _appliedStatus},
      header: header,
      builder: (context, data, reload) {
        final jobs = data.l('jobs');
        return [
          header,
          ListFilterBar(
            controller: _q,
            placeholder: 'Search by title or designation',
            status: _status,
            statusOptions: const [
              SelectOption('', 'All statuses'),
              SelectOption('DRAFT', 'Draft'),
              SelectOption('PUBLISHED', 'Published'),
              SelectOption('CLOSED', 'Closed'),
            ],
            onStatusChanged: (v) => setState(() => _status = v),
            onFilter: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _appliedQ = _q.text.trim();
                _appliedStatus = _status;
              });
            },
          ),
          if (jobs.isEmpty) const EmptyState('No jobs found.'),
          for (final j in jobs)
            MobileCard(
              onTap: () => context.push('/jobs/${j.s('id')}'),
              children: [
                MobileCardHeader(title: j.s('title'), action: _jobBadge(j.s('status'))),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Designation', value: j.s('designation')),
                  MobileCardRow(label: 'Vacancies', value: j.s('vacancyCount')),
                  MobileCardRow(label: 'Rounds', value: j.s('roundCount')),
                  MobileCardRow(label: 'Deadline', value: fmtDate(j.at('applicationDeadline'))),
                ]),
              ],
            ),
        ];
      },
    );
  }
}

/// app/(app)/jobs/[id]/page.tsx.
class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/jobs/$id',
      builder: (context, data, reload) {
        final j = data.m('job');
        final status = j.s('status');
        final isDraft = status == 'DRAFT';
        final isPublished = status == 'PUBLISHED';
        final rounds = data.l('rounds');
        final jobType = j.s('jobType');

        return [
          PageHeader(
            title: j.s('title'),
            description: '${j.s('designation')} · ${j.s('department')}',
            actions: [
              if (isDraft) TsButton.secondary(label: 'Edit', onPressed: () => context.push('/jobs/$id/edit')),
              Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: _jobBadge(status)),
            ],
          ),
          TsCard(
            title: 'Job Details',
            child: DetailList(rows: [
              DetailRow(label: 'Vacancies', value: j.s('vacancyCount')),
              DetailRow(label: 'Minimum Qualification', value: j.s('minQualification')),
              if (j.sn('minGradeOrMarks') != null) DetailRow(label: 'Minimum Grade / Marks', value: j.s('minGradeOrMarks')),
              if (j.has('minExperienceYears'))
                DetailRow(label: 'Minimum Experience', value: '${j.s('minExperienceYears')} year(s)'),
              if (j.sn('industryExperience') != null)
                DetailRow(
                  label: 'Industry Experience',
                  value: '${j.s('industryExperience')}${j.b('industryExperienceRequired') ? ' (Mandatory)' : ' (Optional)'}',
                ),
              DetailRow(label: 'Job Type', value: j.s('jobTypeLabel')),
              if (jobType == 'INTERNSHIP' && (j.iN('internshipDurationMonths') ?? 0) != 0)
                DetailRow(label: 'Internship Duration', value: '${j.s('internshipDurationMonths')} month(s)'),
              if (jobType == 'INTERNSHIP' && j.b('internshipCanRegularize'))
                const DetailRow(label: 'Regularization', value: 'Option to regularize into a permanent post'),
              if (jobType == 'TEMPORARY' && (j.iN('temporaryDurationMonths') ?? 0) != 0)
                DetailRow(label: 'Duration', value: '${j.s('temporaryDurationMonths')} month(s)'),
              DetailRow(label: 'Compensation', value: j.s('compensation')),
              DetailRow(label: 'Location', value: j.s('location')),
              DetailRow(label: 'Nature of Job', value: j.s('jobNatureLabel')),
              if (j.sn('officeAddress') != null) DetailRow(label: 'Office Address', value: j.s('officeAddress')),
              DetailRow(label: 'Posted By', value: j.s('postedBy')),
            ]),
          ),
          TsCard(
            title: 'Application Window',
            child: isDraft
                ? DetailList(rows: [
                    DetailRow(label: 'Vacancies', value: j.s('vacancyCount')),
                    DetailRow(label: 'Deadline', value: fmtDate(j.at('applicationDeadline'))),
                  ])
                : _SchedulingForm(
                    jobId: id,
                    vacancyCount: j.s('vacancyCount'),
                    applicationDeadline: j.s('applicationDeadlineInput'),
                  ),
          ),
          TsCard(
            title: 'Selection Process',
            child: Gap(
              gap: 12,
              children: [
                for (var i = 0; i < rounds.length; i++) _RoundSummary(jobId: id, index: i, r: rounds[i], isDraft: isDraft),
              ],
            ),
          ),
          if (isPublished && j.sn('applicationUrl') != null)
            TsCard(
              title: 'Application Link',
              child: Gap(
                gap: 12,
                children: [
                  const Muted('Share this link with candidates to let them apply.'),
                  _CopyLink(url: j.s('applicationUrl')),
                ],
              ),
            ),
          if (!isDraft)
            TsCard(
              title: 'Candidates',
              action: TsButton.secondary(
                label: 'View All',
                compact: true,
                onPressed: () => context.push('/jobs/$id/candidates'),
              ),
              child: Muted('${j.i('candidateCount')} application(s) received.'),
            ),
          if (isDraft)
            TsCard(
              title: 'Publish',
              child: Gap(
                gap: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Muted('Once published, the round list is locked - vacancies and the application deadline stay editable.'),
                  ActionButton(
                    label: 'Publish',
                    pendingLabel: 'Publishing...',
                    run: () => api.action('hiring.publishJob', args: [id]),
                  ),
                ],
              ),
            ),
          if (isPublished)
            TsCard(
              title: 'Close',
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionButton(
                  label: 'Close Job',
                  pendingLabel: 'Closing...',
                  variant: TsButtonVariant.danger,
                  run: () => api.action('hiring.closeJob', args: [id]),
                ),
              ),
            ),
          if (isDraft)
            TsCard(
              title: 'Danger Zone',
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionButton(
                  label: 'Delete Draft',
                  pendingLabel: 'Deleting...',
                  variant: TsButtonVariant.danger,
                  run: () => api.action('hiring.deleteJob', args: [id]),
                ),
              ),
            ),
        ];
      },
    );
  }
}

class _RoundSummary extends StatelessWidget {
  const _RoundSummary({required this.jobId, required this.index, required this.r, required this.isDraft});
  final String jobId;
  final int index;
  final Json r;
  final bool isDraft;

  String _other(String key, String otherKey) => r.s(key) == 'OTHER' ? r.s(otherKey) : r.s(key);

  @override
  Widget build(BuildContext context) {
    final type = r.s('type');
    String summary;
    switch (type) {
      case 'MCQ_EXAM':
        final neg = r.dN('examNegativeMarkingPerWrong');
        summary = '${_other('examTopicType', 'examTopicOther')} · '
            '${r.has('examScheduledAt') ? fmtDateTime(r.at('examScheduledAt')) : 'Not scheduled'} · '
            '${r.s('examDurationMinutes')} min · Full marks ${r.s('examFullMarks')} · Cutoff ${r.s('examCutoffMarks')}'
            '${neg != null && neg != 0 ? ' · Negative marking ${r.s('examNegativeMarkingPerWrong')}/wrong' : ''}';
      case 'INTERVIEW':
        final venues = r.list<String>('interviewVenues');
        summary = '${_other('interviewNature', 'interviewNatureOther')}${venues.isNotEmpty ? ' · ${venues.join(' / ')}' : ''}';
      case 'PHYSICAL_FITNESS':
        final venues = r.list<String>('physicalVenues');
        summary = '${_other('physicalNature', 'physicalNatureOther')}${venues.isNotEmpty ? ' · ${venues.join(' / ')}' : ''}';
      default:
        summary = '${r.list<String>('medicalVenues').join(' / ')}${r.b('medicalCertificateRequired') ? ' · Certificate required' : ''}';
    }
    final roundId = r.s('id');
    return BorderedBlock(
      children: [
        StrongText('Round ${index + 1} — ${roundTypeLabel[type] ?? type}'),
        MutedLine(summary),
        if (!isDraft) ...[
          const SizedBox(height: 6),
          type == 'MCQ_EXAM'
              ? TsLink('Manage Questions (${r.i('questionCount')})',
                  onTap: () => context.push('/jobs/$jobId/rounds/$roundId/questions'))
              : TsLink('Schedule & Results', onTap: () => context.push('/jobs/$jobId/rounds/$roundId/schedule')),
        ],
      ],
    );
  }
}

class _CopyLink extends StatelessWidget {
  const _CopyLink({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: p.surfaceHover,
        borderRadius: BorderRadius.circular(Ts.rXl),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              url,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: p.foreground),
            ),
          ),
          const SizedBox(width: 8),
          TsButton.secondary(
            label: 'Copy',
            compact: true,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: url));
              if (context.mounted) toast(context, 'Link copied.');
            },
          ),
        ],
      ),
    );
  }
}

/// job-actions.tsx's SchedulingForm.
class _SchedulingForm extends StatefulWidget {
  const _SchedulingForm({required this.jobId, required this.vacancyCount, required this.applicationDeadline});
  final String jobId;
  final String vacancyCount;
  final String applicationDeadline;

  @override
  State<_SchedulingForm> createState() => _SchedulingFormState();
}

class _SchedulingFormState extends State<_SchedulingForm> {
  late final _vacancies = TextEditingController(text: widget.vacancyCount);
  late String? _deadline = widget.applicationDeadline;
  bool _pending = false;
  String? _error;
  bool _saved = false;

  @override
  void dispose() {
    _vacancies.dispose();
    super.dispose();
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
      () => api.action('hiring.updateJobScheduling', args: [widget.jobId], fields: {
        'vacancyCount': _vacancies.text,
        'applicationDeadline': _deadline ?? '',
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
      gap: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TsInput(
          controller: _vacancies,
          label: 'Vacancies',
          keyboardType: TextInputType.number,
          inputFormatters: TsInput.digitsOnly,
        ),
        TsDateField(label: 'Application Deadline', value: _deadline, onChanged: (v) => setState(() => _deadline = v)),
        TsButton.secondary(label: 'Save', pendingLabel: 'Saving...', pending: _pending, onPressed: _save),
        if (_error != null) StatusMessage.error(_error),
        if (_saved) StatusMessage.success('Saved.'),
      ],
    );
  }
}
