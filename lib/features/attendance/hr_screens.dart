import '../../widgets/ts.dart';
import 'widgets.dart';

// ---------------------------------------------------------------------------
// /attendance - daily grid

/// app/(app)/attendance/page.tsx: one day across the company, filtered by
/// date (IST, default today) and status, 30 per page.
class AttendanceGridScreen extends StatefulWidget {
  const AttendanceGridScreen({super.key, this.date, this.status, this.page});
  final String? date;
  final String? status;
  final String? page;

  @override
  State<AttendanceGridScreen> createState() => _AttendanceGridScreenState();
}

class _AttendanceGridScreenState extends State<AttendanceGridScreen> {
  static const _header = PageHeader(title: 'Attendance', description: 'Daily status across the company.');

  late String _date = widget.date ?? todayValue();
  late String _status = widget.status ?? '';

  void _go(String date, String status, {int page = 1}) {
    context.replace(Uri(path: '/attendance', queryParameters: {
      'date': date,
      if (status.isNotEmpty) 'status': status,
      if (page > 1) 'page': '$page',
    }).toString());
  }

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/attendance',
      query: {'date': widget.date, 'status': widget.status, 'page': widget.page},
      header: _header,
      builder: (context, data, reload) {
        final days = data.l('days');
        return [
          _header,
          TsCard(
            child: Gap(
              gap: 14,
              children: [
                TsDateField(label: 'Date', value: _date, onChanged: (v) => setState(() => _date = v ?? _date)),
                TsSelect<String>(
                  label: 'Status',
                  value: _status,
                  options: [
                    const SelectOption('', 'All statuses'),
                    for (final o in data.l('statusOptions')) SelectOption(o.s('value'), o.s('label')),
                  ],
                  onChanged: (v) => setState(() => _status = v ?? ''),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TsButton.secondary(label: 'Filter', onPressed: () => _go(_date, _status)),
                ),
              ],
            ),
          ),
          if (days.isEmpty) const EmptyState('No attendance records for this date.', icon: LucideIcons.calendarClock),
          for (final d in days)
            AttendanceDayCard(
              title: d.s('employeeName'),
              day: d,
              onTap: () => context.push('/employees/${d.s('employeeId')}'),
              footer: OverrideCell(day: d),
            ),
          Pagination(
            page: data.i('page', 1),
            pageCount: data.i('totalPages', 1),
            onChanged: (p) => _go(data.s('date'), data.s('status'), page: p),
          ),
        ];
      },
    );
  }
}

// ---------------------------------------------------------------------------
// /attendance/override

/// app/(app)/attendance/override/page.tsx + override-form.tsx.
class OverrideScreen extends StatelessWidget {
  const OverrideScreen({super.key, this.employeeId, this.date, this.returnTo});
  final String? employeeId;
  final String? date;
  final String? returnTo;

  static const _title = 'Override Attendance Day';

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/attendance/override',
      query: {'employeeId': employeeId, 'date': date, 'returnTo': returnTo},
      header: const PageHeader(title: _title),
      builder: (context, data, reload) {
        final day = data.mN('day');
        final first = day?.at('firstPunchAt');
        final last = day?.at('lastPunchAt');
        return [
          PageHeader(title: _title, description: '${data.s('employee.name')} — ${fmtDate(data.at('date'))}'),
          TsCard(
            title: 'Current Record',
            child: DetailList(rows: [
              DetailRow(label: 'Computed Status', value: day?.s('statusLabel') ?? 'No record for this day'),
              if (first != null)
                DetailRow(
                  label: 'First / Last Punch',
                  value: '${fmtTime(first)}${last != null ? ' — ${fmtTime(last)}' : ''}',
                ),
              if (day != null && day.b('overridden'))
                DetailRow(label: 'Already Overridden', value: day.s('overrideReason')),
            ]),
          ),
          TsCard(
            title: 'Set Status',
            child: _OverrideForm(
              employeeId: data.s('employee.id'),
              dateParam: data.s('dateParam'),
              backHref: data.s('backHref'),
            ),
          ),
        ];
      },
    );
  }
}

class _OverrideForm extends StatefulWidget {
  const _OverrideForm({required this.employeeId, required this.dateParam, required this.backHref});
  final String employeeId;
  final String dateParam;
  final String backHref;

  @override
  State<_OverrideForm> createState() => _OverrideFormState();
}

class _OverrideFormState extends State<_OverrideForm> {
  String? _status;
  final _reason = TextEditingController();
  bool _pending = false;
  String? _error;
  String? _warning;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
      _warning = null;
    });
    final r = await runAction(
      context,
      () => api.action(
        'attendance.overrideAttendanceDay',
        args: [widget.employeeId, widget.dateParam],
        fields: {'status': _status ?? '', 'reason': _reason.text},
      ),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _warning = r.ok ? r.warning : null;
    });
    // Only leave on a clean success - a warning (locked payroll month)
    // has to be read first.
    if (r.ok && r.warning == null) followRedirect(context, widget.backHref);
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Gap(
      gap: 16,
      children: [
        TsSelect<String>(
          label: 'Status',
          value: _status,
          placeholder: 'Choose...',
          options: const [SelectOption('PRESENT', 'Present'), SelectOption('ABSENT', 'Absent')],
          onChanged: (v) => setState(() => _status = v),
        ),
        TsTextarea(
          controller: _reason,
          label: 'Reason',
          hint: "Required - explain why you're overriding this day.",
          rows: 3,
        ),
        if (_error != null) StatusMessage.error(_error),
        if (_warning != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.warningLight,
              borderRadius: BorderRadius.circular(Ts.rLg),
              border: Border.all(color: p.warning.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Override saved, but: $_warning', style: tx(14, color: p.warning)),
                const SizedBox(height: 8),
                TsLink('Back', onTap: () => followRedirect(context, widget.backHref)),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton(label: 'Save Override', pendingLabel: 'Saving...', pending: _pending, onPressed: _submit),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// /attendance/exceptions

/// app/(app)/attendance/exceptions/page.tsx: geofence exceptions
/// (unreviewed / reviewed) and missing punch-outs with no regularization.
class ExceptionsScreen extends StatelessWidget {
  const ExceptionsScreen({super.key, this.type, this.show});
  final String? type;
  final String? show;

  static const _header = PageHeader(
    title: 'Attendance Exceptions',
    description: 'Punches or days that need a second look - nothing here is blocked, just flagged for review.',
  );

  @override
  Widget build(BuildContext context) {
    final isMissing = type == 'missing-punch-out';
    final showReviewed = show == 'reviewed';
    return ApiScreen(
      path: '/attendance/exceptions',
      query: {'type': type, 'show': show},
      header: _header,
      builder: (context, data, reload) {
        final days = data.l('days');
        return [
          _header,
          LinkTabs<String>(
            value: isMissing ? 'missing' : 'geofence',
            tabs: const [('geofence', 'Geofence'), ('missing', 'Missing Punch Out')],
            onChanged: (v) => context.replace(
              v == 'missing' ? '/attendance/exceptions?type=missing-punch-out' : '/attendance/exceptions',
            ),
          ),
          if (!isMissing)
            LinkTabs<String>(
              value: showReviewed ? 'reviewed' : 'unreviewed',
              tabs: const [('unreviewed', 'Unreviewed'), ('reviewed', 'Reviewed')],
              onChanged: (v) => context.replace(
                v == 'reviewed' ? '/attendance/exceptions?show=reviewed' : '/attendance/exceptions',
              ),
            ),
          if (days.isEmpty)
            EmptyState(
              isMissing
                  ? 'No unresolved missing punch-outs.'
                  : (showReviewed ? 'No reviewed exceptions.' : 'No unreviewed exceptions.'),
              icon: LucideIcons.shieldCheck,
            ),
          if (isMissing)
            for (final d in days)
              MobileCard(
                children: [
                  MobileCardHeader(
                    title: d.s('employeeName'),
                    action: TsBadge(fmtDate(d.at('date')), tone: BadgeTone.amber),
                  ),
                  MobileCardRows(rows: [MobileCardRow(label: 'First Punch', value: fmtTime(d.at('firstPunchAt')))]),
                ],
              )
          else
            for (final d in days)
              MobileCard(
                children: [
                  MobileCardHeader(
                    title: d.s('employeeName'),
                    action: TsBadge(fmtDate(d.at('date')), tone: BadgeTone.red),
                  ),
                  MobileCardRows(rows: [MobileCardRow(label: 'Nearest Location', value: d.sn('nearestLocation') ?? '—')]),
                  MobileCardFooter(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: d.at('reviewedAt') != null
                          ? TsBadge('Reviewed ${fmtDate(d.at('reviewedAt'))}', tone: BadgeTone.green)
                          : ActionButton(
                              label: 'Mark Reviewed',
                              variant: TsButtonVariant.secondary,
                              compact: true,
                              run: () => api.action(
                                'attendance.reviewGeofenceException',
                                fields: {'attendanceDayId': d.s('id')},
                              ),
                            ),
                    ),
                  ),
                ],
              ),
        ];
      },
    );
  }
}

// ---------------------------------------------------------------------------
// /attendance/report

/// Downloads one of the report exports with the session token and opens it.
class ExportButton extends StatefulWidget {
  const ExportButton({super.key, required this.label, required this.path});
  final String label;
  final String path;

  @override
  State<ExportButton> createState() => _ExportButtonState();
}

class _ExportButtonState extends State<ExportButton> {
  bool _pending = false;

  Future<void> _open() async {
    setState(() => _pending = true);
    try {
      await api.openFile(widget.path);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => TsButton.secondary(
        label: widget.label,
        pending: _pending,
        icon: LucideIcons.download,
        onPressed: _open,
      );
}

/// app/(app)/attendance/report/page.tsx: one card per employee with any
/// computed day in the month.
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key, this.month});
  final String? month;

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  static const _title = 'Monthly Attendance Report';

  late String _month = widget.month ?? currentMonthValue();

  void _goto(String month) {
    setState(() => _month = month);
    context.replace('/attendance/report?month=$month');
  }

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/attendance/report',
      query: {'month': widget.month},
      header: const PageHeader(title: _title),
      builder: (context, data, reload) {
        final m = data.m('month');
        final label = m.s('label');
        final summaries = data.l('summaries');
        return [
          PageHeader(
            title: _title,
            description: 'Summary for $label. One row per employee with any computed attendance day this month.',
            actions: [
              TsButton.secondary(label: '← Previous', onPressed: () => _goto(m.s('prevValue'))),
              TsButton.secondary(label: 'Next →', onPressed: () => _goto(m.s('nextValue'))),
              ExportButton(label: 'Export CSV', path: data.s('csvPath')),
              ExportButton(label: 'Export PDF', path: data.s('pdfPath')),
            ],
          ),
          TsCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TsMonthField(label: 'Month', value: _month, onChanged: (v) => setState(() => _month = v)),
                ),
                const SizedBox(width: 12),
                TsButton.secondary(label: 'Go', onPressed: () => _goto(_month)),
              ],
            ),
          ),
          if (summaries.isEmpty) EmptyState('No attendance recorded for $label.', icon: LucideIcons.calendarClock),
          for (final s in summaries)
            MobileCard(
              onTap: () => context.push('/employees/${s.s('employeeId')}'),
              children: [
                MobileCardHeader(title: s.s('employeeName')),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Present', value: '${s.i('present')}'),
                  MobileCardRow(label: 'Half Day', value: '${s.i('halfDay')}'),
                  MobileCardRow(label: 'Absent', value: '${s.i('absent')}'),
                  MobileCardRow(label: 'On Leave', value: '${s.i('onLeave')}'),
                  MobileCardRow(label: 'Late', value: '${s.i('lateCount')}'),
                  MobileCardRow(label: 'Early Out', value: '${s.i('earlyCount')}'),
                  MobileCardRow(label: 'Total Worked', value: workedTime(s.i('workedMinutes'))),
                ]),
                MobileCardFooter(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TsLink(
                      'View Days',
                      onTap: () => context.push('/attendance/report/${s.s('employeeId')}?month=${m.s('value')}'),
                    ),
                  ),
                ),
              ],
            ),
        ];
      },
    );
  }
}

/// app/(app)/attendance/report/[employeeId]/page.tsx: one employee's days
/// in the month, each with its OverrideCell.
class AttendanceReportDaysScreen extends StatelessWidget {
  const AttendanceReportDaysScreen({super.key, required this.employeeId, this.month});
  final String employeeId;
  final String? month;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/attendance/report/$employeeId',
      query: {'month': month},
      builder: (context, data, reload) {
        final m = data.m('month');
        final label = m.s('label');
        final days = data.l('days');
        return [
          PageHeader(
            title: data.s('employee.name'),
            description: 'Daily attendance for $label.',
            actions: [
              TsButton.secondary(
                label: '← Previous',
                onPressed: () => context.replace('/attendance/report/$employeeId?month=${m.s('prevValue')}'),
              ),
              TsButton.secondary(
                label: 'Next →',
                onPressed: () => context.replace('/attendance/report/$employeeId?month=${m.s('nextValue')}'),
              ),
              TsButton.secondary(
                label: 'Back to Report',
                onPressed: () => followRedirect(context, '/attendance/report?month=${m.s('value')}'),
              ),
            ],
          ),
          if (days.isEmpty) EmptyState('No attendance recorded for $label.', icon: LucideIcons.calendarClock),
          for (final d in days)
            AttendanceDayCard(
              title: fmtDate(d.at('date')),
              day: d,
              footer: OverrideCell(day: d, returnTo: data.s('returnTo')),
            ),
        ];
      },
    );
  }
}
