import '../../widgets/ts.dart';
import 'widgets.dart';

String _amount(Json r) => r.at('computedAmount') == null ? '—' : rupee(r.at('computedAmount'));

/// app/(app)/leave-encashment - the employee's encashment requests and how
/// much Earned Leave they can encash right now.
class MyEncashmentScreen extends StatelessWidget {
  const MyEncashmentScreen({super.key});

  static const _header = PageHeader(title: 'Leave Encashment');

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/leave-encashment',
      header: _header,
      builder: (context, data, reload) {
        final max = data.d('maxEncashable');
        return [
          PageHeader(
            title: 'Leave Encashment',
            description:
                'Current Earned Leave balance: ${data.s('balance')} day(s). Up to ${data.s('maxEncashable')} day(s) can be encashed while retaining the required ${data.s('minBalance')}.',
            actions: [TsButton(label: 'Apply', onPressed: max > 0 ? () => context.push('/leave-encashment/new') : null)],
          ),
          ...cardList(
            data.l('requests'),
            'No leave encashment requests yet.',
            (r) => MobileCard(
              onTap: () => context.push('/leave-encashment/${r.s('id')}'),
              children: [
                MobileCardHeader(title: fmtDate(r.at('createdAt')), action: statusBadge(r.s('status'))),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Days', value: r.s('requestedDays')),
                  MobileCardRow(label: 'Amount', value: _amount(r)),
                ]),
              ],
            ),
          ),
        ];
      },
    );
  }
}

/// app/(app)/leave-encashment/new. Like the web form it stays put on
/// success, shows "Request submitted." and clears the fields.
class ApplyEncashmentScreen extends StatefulWidget {
  const ApplyEncashmentScreen({super.key});

  @override
  State<ApplyEncashmentScreen> createState() => _ApplyEncashmentScreenState();
}

class _ApplyEncashmentScreenState extends State<ApplyEncashmentScreen> {
  static const _header = PageHeader(title: 'Apply for Leave Encashment');

  final _days = TextEditingController();
  final _reason = TextEditingController();
  bool _pending = false;
  String? _error;
  bool _submitted = false;

  @override
  void dispose() {
    _days.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
      _submitted = false;
    });
    final r = await runAction(
      context,
      () => api.action(
        'leave.applyForLeaveEncashment',
        fields: {'requestedDays': _days.text, 'reason': _reason.text},
      ),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _submitted = r.ok;
      if (r.ok) {
        _days.clear();
        _reason.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/leave-encashment/new',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        Muted(
          'Your current Earned Leave balance is ${data.s('currentBalance')} day(s). Company policy requires at least ${data.s('minBalanceRetained')} to remain after encashing, so you can encash up to ${data.s('maxEncashable')} day(s) right now.',
        ),
        TsInput(
          label: 'Days to Encash',
          controller: _days,
          keyboardType: TextInputType.number,
          inputFormatters: TsInput.digitsOnly,
        ),
        TsTextarea(label: 'Reason', controller: _reason, rows: 3),
        if (_error != null) StatusMessage.error(_error),
        if (_submitted) StatusMessage.success('Request submitted.'),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton(label: 'Submit Request', pendingLabel: 'Submitting...', pending: _pending, onPressed: _submit),
        ),
      ],
    );
  }
}

/// app/(app)/leave-encashment/approvals - direct reports' pending requests.
class EncashmentApprovalsScreen extends StatelessWidget {
  const EncashmentApprovalsScreen({super.key});

  static const _header = PageHeader(
    title: 'Leave Encashment Approvals',
    description: "Your direct reports' pending leave encashment requests.",
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/leave-encashment/approvals',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        ...cardList(
          data.l('requests'),
          'Nothing pending your approval.',
          (r) => MobileCard(
            onTap: () => context.push('/leave-encashment/${r.s('id')}'),
            children: [
              MobileCardHeader(title: r.s('employeeName')),
              MobileCardRows(rows: [
                MobileCardRow(label: 'Applied On', value: fmtDate(r.at('createdAt'))),
                MobileCardRow(label: 'Days', value: r.s('requestedDays')),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// app/(app)/leave-encashment/queue - every pending request (HR).
class EncashmentQueueScreen extends StatelessWidget {
  const EncashmentQueueScreen({super.key});

  static const _header = PageHeader(
    title: 'Leave Encashment Queue',
    description: 'Every request currently pending, company-wide.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/leave-encashment/queue',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        ...cardList(
          data.l('requests'),
          'Nothing pending.',
          (r) => MobileCard(
            onTap: () => context.push('/leave-encashment/${r.s('id')}'),
            children: [
              MobileCardHeader(title: r.s('employeeName'), action: queueBadge(r.s('status'))),
              MobileCardRows(rows: [
                MobileCardRow(label: 'Applied On', value: fmtDate(r.at('createdAt'))),
                MobileCardRow(label: 'Days', value: r.s('requestedDays')),
              ]),
            ],
          ),
        ),
      ],
    );
  }
}

/// app/(app)/leave-encashment/[id] - detail with approve/reject/cancel.
class EncashmentDetailScreen extends StatelessWidget {
  const EncashmentDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/leave-encashment/$id',
      builder: (context, data, reload) => [
        PageHeader(
          title: 'Leave Encashment — ${data.s('employeeName')}',
          description: 'Applied ${fmtDate(data.at('createdAt'))}',
          actions: [statusBadge(data.s('status'))],
        ),
        TsCard(
          title: 'Details',
          child: DetailList(rows: [
            DetailRow(label: 'Days Requested', value: data.s('requestedDays')),
            DetailRow(label: 'Reason', value: data.s('reason')),
            if (data.at('computedAmount') != null) DetailRow(label: 'Amount', value: _amount(data)),
            ...decisionRows(data),
          ]),
        ),
        ...requestActionCards(
          data,
          id: id,
          managerApprove: 'leave.approveEncashmentAsManager',
          managerReject: 'leave.rejectEncashmentAsManager',
          hrApprove: 'leave.approveEncashmentAsHr',
          hrReject: 'leave.rejectEncashmentAsHr',
          cancel: 'leave.cancelLeaveEncashmentRequest',
        ),
      ],
    );
  }
}
