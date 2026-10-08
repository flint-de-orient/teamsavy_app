import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/regularization - the employee's own correction requests.
class MyRegularizationScreen extends StatelessWidget {
  const MyRegularizationScreen({super.key});

  static const _header = PageHeader(
    title: 'My Regularization Requests',
    description: 'To request a correction, go to My Attendance and pick the day that needs fixing.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/regularization',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        ...cardList(
          data.l('requests'),
          'No regularization requests yet.',
          (r) => MobileCard(
            onTap: () => context.push('/regularization/${r.s('id')}'),
            children: [
              MobileCardHeader(title: fmtDate(r.at('date')), action: statusBadge(r.s('status'))),
              MobileCardRows(rows: [MobileCardRow(label: 'Type', value: r.s('typeLabel'))]),
            ],
          ),
        ),
      ],
    );
  }
}

/// app/(app)/regularization/new?attendanceDayId=&type= - opened from a day
/// on My Attendance. Stays on the page on success, like the web form.
class ApplyRegularizationScreen extends StatefulWidget {
  const ApplyRegularizationScreen({super.key, this.attendanceDayId, this.type});
  final String? attendanceDayId;
  final String? type;

  @override
  State<ApplyRegularizationScreen> createState() => _ApplyRegularizationScreenState();
}

class _ApplyRegularizationScreenState extends State<ApplyRegularizationScreen> {
  static const _header = PageHeader(title: 'Request Regularization');

  String? _type;
  String? _punchIn;
  String? _punchOut;
  final _reason = TextEditingController();
  bool _pending = false;
  String? _error;
  bool _submitted = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit(String attendanceDayId, String type) async {
    setState(() {
      _pending = true;
      _error = null;
      _submitted = false;
    });
    final r = await runAction(
      context,
      () => api.action(
        'leave.applyForRegularization',
        fields: {
          'attendanceDayId': attendanceDayId,
          'type': type,
          'requestedPunchInAt': _punchIn ?? '',
          'requestedPunchOutAt': _punchOut ?? '',
          'reason': _reason.text,
        },
      ),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _submitted = r.ok;
      if (r.ok) {
        _punchIn = null;
        _punchOut = null;
        _reason.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/regularization/new',
      query: {'attendanceDayId': widget.attendanceDayId, 'type': widget.type},
      header: _header,
      builder: (context, data, reload) {
        // An unset <select> shows (and posts) its first option.
        final type = _type ?? data.sn('defaultType') ?? kRegularizationTypes.first.value;
        final day = DateTime.tryParse(data.s('date'));
        return [
          _header,
          Muted('Correcting attendance for ${data.s('dateLabel')}.'),
          TsSelect<String>(
            label: "What's wrong",
            value: type,
            options: kRegularizationTypes,
            onChanged: (v) => setState(() => _type = v),
          ),
          DateTimeLocalField(
            label: 'Correct Punch In (optional)',
            value: _punchIn,
            initialDate: day,
            onChanged: (v) => setState(() => _punchIn = v),
          ),
          DateTimeLocalField(
            label: 'Correct Punch Out (optional)',
            value: _punchOut,
            initialDate: day,
            onChanged: (v) => setState(() => _punchOut = v),
          ),
          TsTextarea(label: 'Reason', controller: _reason, rows: 3),
          if (_error != null) StatusMessage.error(_error),
          if (_submitted) StatusMessage.success('Request submitted.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton(
              label: 'Submit Request',
              pendingLabel: 'Submitting...',
              pending: _pending,
              onPressed: () => _submit(data.s('attendanceDayId'), type),
            ),
          ),
        ];
      },
    );
  }
}

/// app/(app)/regularization/approvals - direct reports' pending requests.
class RegularizationApprovalsScreen extends StatelessWidget {
  const RegularizationApprovalsScreen({super.key});

  static const _header = PageHeader(
    title: 'Regularization Approvals',
    description: "Your direct reports' pending regularization requests.",
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/regularization/approvals',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        ...cardList(
          data.l('requests'),
          'Nothing pending your approval.',
          (r) => MobileCard(
            onTap: () => context.push('/regularization/${r.s('id')}'),
            children: [
              MobileCardHeader(title: r.s('employeeName')),
              MobileCardRows(rows: [
                MobileCardRow(label: 'Type', value: r.s('typeLabel')),
                MobileCardRow(label: 'Date', value: fmtDate(r.at('date'))),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// app/(app)/regularization/queue - every pending request (HR).
class RegularizationQueueScreen extends StatelessWidget {
  const RegularizationQueueScreen({super.key});

  static const _header = PageHeader(
    title: 'Regularization Queue',
    description: 'Every request currently pending, company-wide.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/regularization/queue',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        ...cardList(
          data.l('requests'),
          'Nothing pending.',
          (r) => MobileCard(
            onTap: () => context.push('/regularization/${r.s('id')}'),
            children: [
              MobileCardHeader(title: r.s('employeeName'), action: queueBadge(r.s('status'))),
              MobileCardRows(rows: [
                MobileCardRow(label: 'Type', value: r.s('typeLabel')),
                MobileCardRow(label: 'Date', value: fmtDate(r.at('date'))),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// app/(app)/regularization/[id] - detail with approve/reject/cancel.
class RegularizationDetailScreen extends StatelessWidget {
  const RegularizationDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/regularization/$id',
      builder: (context, data, reload) => [
        PageHeader(
          title: '${data.s('typeLabel')} — ${data.s('employeeName')}',
          description: fmtDate(data.at('date')),
          actions: [statusBadge(data.s('status'))],
        ),
        TsCard(
          title: 'Details',
          child: DetailList(rows: [
            DetailRow(label: 'Reason', value: data.s('reason')),
            if (data.at('requestedPunchInAt') != null)
              DetailRow(label: 'Requested Punch In', value: fmtDateTime(data.at('requestedPunchInAt'))),
            if (data.at('requestedPunchOutAt') != null)
              DetailRow(label: 'Requested Punch Out', value: fmtDateTime(data.at('requestedPunchOutAt'))),
            ...decisionRows(data),
          ]),
        ),
        ...requestActionCards(
          data,
          id: id,
          managerApprove: 'leave.approveRegularizationAsManager',
          managerReject: 'leave.rejectRegularizationAsManager',
          hrApprove: 'leave.approveRegularizationAsHr',
          hrReject: 'leave.rejectRegularizationAsHr',
          cancel: 'leave.cancelRegularizationRequest',
        ),
      ],
    );
  }
}
