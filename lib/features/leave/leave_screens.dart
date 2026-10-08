import '../../widgets/ts.dart';
import 'widgets.dart';

const _balanceCards = [
  ('EARNED', 'Earned Leave', LucideIcons.calendarRange, CardTone.primary),
  ('CASUAL', 'Casual Leave', LucideIcons.coffee, CardTone.info),
  ('SICK', 'Sick Leave', LucideIcons.heartPulse, CardTone.purple),
];

/// app/(app)/leave/page.tsx - "My Leave": balances and the employee's own
/// requests.
class MyLeaveScreen extends StatelessWidget {
  const MyLeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(
      title: 'My Leave',
      description: 'Balances and requests.',
      actions: [TsButton(label: 'Apply for Leave', onPressed: () => context.push('/leave/new'))],
    );
    return ApiScreen(
      path: '/leave',
      header: header,
      builder: (context, data, reload) {
        final balances = {for (final b in data.l('balances')) b.s('key'): b};
        return [
          header,
          for (final (key, label, icon, tone) in _balanceCards)
            TsCard(
              title: label,
              icon: icon,
              tone: tone,
              child: _BalanceBody(balances[key] ?? const {}),
            ),
          if (!data.b('hasManager'))
            const StatusMessage(
              'No reporting manager is linked to your record yet — your leave requests go straight to HR.',
              kind: StatusKind.warning,
            ),
          ...cardList(
            data.l('requests'),
            'No leave requests yet.',
            (r) => MobileCard(
              onTap: () => context.push('/leave/${r.s('id')}'),
              children: [
                MobileCardHeader(title: r.s('typeLabel'), action: statusBadge(r.s('status'))),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Dates', value: dateRange(r.at('startDate'), r.at('endDate'))),
                  MobileCardRow(label: 'Days', value: r.s('numDays')),
                ]),
              ],
            ),
          ),
        ];
      },
    );
  }
}

class _BalanceBody extends StatelessWidget {
  const _BalanceBody(this.b);
  final Json b;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(b.s('balance', '0'), style: tx(24, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
        Text(
          '${b.s('entitlementToDate', '0')} entitled to date — ${b.s('daysTaken', '0')} used or reserved',
          style: tx(12, color: p.muted),
        ),
      ],
    );
  }
}

const _attachmentTypes = {'SICK', 'MATERNITY', 'PATERNITY'};

/// app/(app)/leave/new - Apply for Leave, with the holiday-aware range
/// calendar. Success follows the web's redirect to the new request.
class ApplyLeaveScreen extends StatefulWidget {
  const ApplyLeaveScreen({super.key});

  @override
  State<ApplyLeaveScreen> createState() => _ApplyLeaveScreenState();
}

class _ApplyLeaveScreenState extends State<ApplyLeaveScreen> {
  static const _header = PageHeader(title: 'Apply for Leave');

  String _type = 'EARNED';
  DateRange _range = const DateRange();
  final _reason = TextEditingController();
  UploadFile? _attachment;
  bool _pending = false;
  String? _error;
  String? _suggestions;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String _day(DateTime? d) => d == null ? '—' : '${d.day} ${monthShort(d.month)} ${d.year}';

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
      _suggestions = null;
    });
    final withAttachment = _attachmentTypes.contains(_type);
    final r = await runAction(
      context,
      () => api.action(
        'leave.applyForLeave',
        fields: {
          'type': _type,
          'startDate': ymd(_range.start!),
          'endDate': ymd(_range.end!),
          'reason': _reason.text,
        },
        files: {'attachment': withAttachment ? _attachment : null},
      ),
    );
    if (!mounted) return;
    final labels = {for (final o in kLeaveTypes) o.value: o.label};
    final suggestions = r.data?.l('suggestions') ?? const <Json>[];
    setState(() {
      _pending = false;
      _error = r.error;
      _suggestions = suggestions.isEmpty
          ? null
          : 'You could instead apply for: ${suggestions.map((s) {
              final label = labels[s.s('type')] ?? s.s('type');
              return s.at('availableBalance') != null ? '$label (${s.s('availableBalance')} day(s) available)' : label;
            }).join(', ')}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/leave/new',
      header: _header,
      builder: (context, data, reload) {
        final p = Ts.of(context);
        final holidays = {for (final h in data.l('holidays')) h.s('date'): h.s('name')};
        final strong = tx(14, weight: FontWeight.w500, color: p.foreground);
        return [
          _header,
          TsSelect<String>(
            label: 'Leave Type',
            value: _type,
            options: kLeaveTypes,
            onChanged: (v) => setState(() => _type = v ?? 'EARNED'),
          ),
          FieldWrapper(
            label: 'Dates',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text.rich(
                  TextSpan(
                    style: tx(14, color: p.muted),
                    children: [
                      const TextSpan(text: 'Start: '),
                      TextSpan(text: _day(_range.start), style: strong),
                      const TextSpan(text: '  ·  End: '),
                      TextSpan(text: _day(_range.end), style: strong),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                DateRangeCalendar(
                  range: _range,
                  onChanged: (r) => setState(() => _range = r),
                  holidays: holidays,
                  weeklyOffDay: data.s('weeklyOffDay', 'Sunday'),
                ),
              ],
            ),
          ),
          TsTextarea(label: 'Reason', controller: _reason, rows: 3),
          if (_attachmentTypes.contains(_type))
            TsFileField(
              label: _type == 'SICK' ? 'Medical Certificate (optional if within threshold)' : 'Proof of Event',
              file: _attachment,
              onChanged: (f) => setState(() => _attachment = f),
              accept: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
            ),
          if (_error != null) _ErrorBox(error: _error!, suggestions: _suggestions),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton(
              label: 'Submit Request',
              pendingLabel: 'Submitting...',
              pending: _pending,
              onPressed: _range.start != null && _range.end != null ? _submit : null,
            ),
          ),
        ];
      },
    );
  }
}

/// apply-leave-form.tsx's error box: danger border + tint, the error, then
/// the alternative leave types the server suggested.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.error, this.suggestions});
  final String error;
  final String? suggestions;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final style = tx(14, color: p.danger, height: 1.5);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.dangerLight,
        borderRadius: BorderRadius.circular(Ts.rLg),
        border: Border.all(color: p.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(error, style: style),
          if (suggestions != null) ...[const SizedBox(height: 8), Text(suggestions!, style: style)],
        ],
      ),
    );
  }
}

/// app/(app)/leave/[id] - request detail with the manager/HR approval
/// panels, cancel, attachments and the fitness-certificate close-out.
class LeaveDetailScreen extends StatelessWidget {
  const LeaveDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/leave/$id',
      builder: (context, data, reload) {
        final p = Ts.of(context);
        final attachments = data.l('attachments');
        final isOwner = data.b('isOwner');
        final isHr = data.b('isHr');
        return [
          PageHeader(
            title: '${data.s('typeLabel')} — ${data.s('employeeName')}',
            description: '${dateRange(data.at('startDate'), data.at('endDate'))} (${data.s('numDays')} day(s))',
            actions: [statusBadge(data.s('status'))],
          ),
          TsCard(
            title: 'Details',
            child: DetailList(rows: [
              DetailRow(label: 'Reason', value: data.s('reason')),
              if (data.b('certificatePending'))
                DetailRow(
                  label: 'Certificate',
                  child: Text('Pending post-facto submission', style: tx(14, color: p.warning)),
                ),
              ...decisionRows(data),
            ]),
          ),
          if (attachments.isNotEmpty)
            TsCard(
              title: 'Attachments',
              child: Gap(
                gap: 8,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final a in attachments)
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      children: [
                        Icon(LucideIcons.paperclip, size: 14, color: p.primary),
                        TsLink(a.s('label'), onTap: () => openFileOrToast(context, '/api/leave/attachments/${a.s('id')}')),
                        Text('(${fmtDate(a.at('uploadedAt'))})', style: tx(14, color: p.muted)),
                      ],
                    ),
                ],
              ),
            ),
          ...requestActionCards(
            data,
            id: id,
            managerApprove: 'leave.approveLeaveAsManager',
            managerReject: 'leave.rejectLeaveAsManager',
            hrApprove: 'leave.approveLeaveAsHr',
            hrReject: 'leave.rejectLeaveAsHr',
            cancel: 'leave.cancelLeaveRequest',
          ),
          if (data.b('needsFitnessCert'))
            TsCard(
              title: 'Fitness Certificate',
              description: 'Required to close out this Sick Leave request before rejoining duty.',
              child: Gap(
                gap: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((isOwner || isHr) && !data.b('hasFitnessCertUpload')) _FitnessCertificateUpload(id: id),
                  if (isHr && data.b('hasFitnessCertUpload'))
                    ActionButton(
                      label: 'Mark Verified',
                      variant: TsButtonVariant.secondary,
                      run: () => api.action('leave.verifyFitnessCertificate', args: [id]),
                    ),
                  if (!isHr && !isOwner) const Muted('Awaiting fitness certificate.'),
                ],
              ),
            ),
        ];
      },
    );
  }
}

class _FitnessCertificateUpload extends StatefulWidget {
  const _FitnessCertificateUpload({required this.id});
  final String id;

  @override
  State<_FitnessCertificateUpload> createState() => _FitnessCertificateUploadState();
}

class _FitnessCertificateUploadState extends State<_FitnessCertificateUpload> {
  UploadFile? _file;
  bool _pending = false;
  String? _error;

  Future<void> _upload() async {
    setState(() => _pending = true);
    final r = await runAction(
      context,
      () => api.action('leave.uploadFitnessCertificate', args: [widget.id], files: {'file': _file}),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Gap(
      gap: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TsFileField(
          file: _file,
          onChanged: (f) => setState(() => _file = f),
          accept: const ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic'],
        ),
        TsButton.secondary(
          label: 'Upload Fitness Certificate',
          pendingLabel: 'Uploading...',
          pending: _pending,
          onPressed: _upload,
        ),
        if (_error != null) StatusMessage.error(_error),
      ],
    );
  }
}

/// app/(app)/leave/approvals - the manager's direct reports' pending leave.
class LeaveApprovalsScreen extends StatelessWidget {
  const LeaveApprovalsScreen({super.key});

  static const _header = PageHeader(title: 'Approvals', description: "Your direct reports' pending leave requests.");

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/leave/approvals',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        ...cardList(
          data.l('requests'),
          'Nothing pending your approval.',
          (r) => MobileCard(
            onTap: () => context.push('/leave/${r.s('id')}'),
            children: [
              MobileCardHeader(title: r.s('employeeName')),
              MobileCardRows(rows: [
                MobileCardRow(label: 'Type', value: r.s('typeLabel')),
                MobileCardRow(label: 'Dates', value: dateRange(r.at('startDate'), r.at('endDate'))),
                MobileCardRow(label: 'Days', value: r.s('numDays')),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// app/(app)/leave/queue - every pending request company-wide (HR).
class LeaveQueueScreen extends StatelessWidget {
  const LeaveQueueScreen({super.key});

  static const _header = PageHeader(title: 'Leave Queue', description: 'Every request currently pending, company-wide.');

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/leave/queue',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        ...cardList(
          data.l('requests'),
          'Nothing pending.',
          (r) => MobileCard(
            onTap: () => context.push('/leave/${r.s('id')}'),
            children: [
              MobileCardHeader(title: r.s('employeeName'), action: queueBadge(r.s('status'))),
              MobileCardRows(rows: [
                MobileCardRow(label: 'Type', value: r.s('typeLabel')),
                MobileCardRow(label: 'Dates', value: dateRange(r.at('startDate'), r.at('endDate'))),
                MobileCardRow(label: 'Days', value: r.s('numDays')),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// app/(app)/leave/report?month= - Monthly Leave Report (HR), with the
/// existing CSV/PDF export routes.
class LeaveReportScreen extends StatefulWidget {
  const LeaveReportScreen({super.key, this.month});
  final String? month;

  @override
  State<LeaveReportScreen> createState() => _LeaveReportScreenState();
}

class _LeaveReportScreenState extends State<LeaveReportScreen> {
  String? _picked;

  @override
  void didUpdateWidget(covariant LeaveReportScreen old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _picked = null;
  }

  void _go(String month) => context.replace('/leave/report?month=$month');

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/leave/report',
      query: {'month': widget.month},
      header: const PageHeader(title: 'Monthly Leave Report'),
      builder: (context, data, reload) {
        final label = data.s('label');
        final value = data.s('value');
        return [
          PageHeader(
            title: 'Monthly Leave Report',
            description: 'Summary for $label. One row per employee with any leave request starting this month.',
            actions: [
              TsButton.secondary(label: '← Previous', onPressed: () => _go(data.s('prevValue'))),
              TsButton.secondary(label: 'Next →', onPressed: () => _go(data.s('nextValue'))),
              OpenFileButton(label: 'Export CSV', path: '/api/leave/report/csv?month=$value'),
              OpenFileButton(label: 'Export PDF', path: '/api/leave/report/pdf?month=$value'),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TsMonthField(
                  label: 'Month',
                  value: _picked ?? value,
                  onChanged: (m) => setState(() => _picked = m),
                ),
              ),
              const SizedBox(width: 12),
              TsButton.secondary(label: 'Go', onPressed: () => _go(_picked ?? value)),
            ],
          ),
          ...cardList(
            data.l('rows'),
            'No leave requests for $label.',
            (s) => MobileCard(
              onTap: () => context.push('/employees/${s.s('employeeId')}'),
              children: [
                MobileCardHeader(title: s.s('employeeName')),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Earned', value: s.s('earned')),
                  MobileCardRow(label: 'Casual', value: s.s('casual')),
                  MobileCardRow(label: 'Sick', value: s.s('sick')),
                  MobileCardRow(label: 'Other', value: s.s('other')),
                  MobileCardRow(label: 'Approved Days', value: s.s('approvedDays')),
                  MobileCardRow(label: 'Pending', value: s.s('pending')),
                  MobileCardRow(label: 'Rejected/Cancelled', value: s.s('closed')),
                ]),
              ],
            ),
          ),
        ];
      },
    );
  }
}
