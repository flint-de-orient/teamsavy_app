import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/tasks/[id]/page.tsx + task-actions.tsx. The server decides
/// which action cards apply (owner / verifier x status); there are no
/// success messages - after an action the page reloads and the cards change.
class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/tasks/$id',
      builder: (context, data, reload) {
        final t = data.m('task');
        final status = t.s('status');
        final type = t.s('type');
        final weight = t.i('weight');
        return [
          PageHeader(
            title: t.s('title'),
            description: '${typeLabelOf(type)} · ${t.s('assignedToName')} · Due ${fmtDate(t.at('dueDate'))}',
            actions: [TaskStatusBadge(status)],
          ),
          TsCard(
            title: 'Details',
            icon: LucideIcons.fileText,
            child: DetailList(rows: _detailRows(t, status, type, weight)),
          ),
          if (data.b('canSubmit'))
            TsCard(
              key: ValueKey('submit-$status'),
              title: status == 'SENT_BACK' ? 'Revise & Resubmit' : 'Submit',
              icon: status == 'SENT_BACK' ? LucideIcons.rotateCcw : LucideIcons.send,
              child: _SubmitTaskForm(taskId: id, isGoal: type == 'GOAL'),
            ),
          if (data.b('canVerifyOrSendBack'))
            TsCard(
              key: const ValueKey('verify'),
              title: 'Verify',
              icon: LucideIcons.badgeCheck,
              child: _VerifyOrSendBackPanel(taskId: id),
            ),
          if (data.b('canCancel'))
            TsCard(
              key: const ValueKey('cancel'),
              title: 'Cancel',
              icon: LucideIcons.circleX,
              child: _CancelTaskForm(taskId: id),
            ),
        ];
      },
    );
  }

  static String _quoted(String? note) => note == null ? '' : ' — "$note"';

  List<DetailRow> _detailRows(Json t, String status, String type, int weight) {
    final percent = t.iN('percentAchieved');
    final lateFactor = t.dN('lateFactor');
    return [
      if (t.sn('description') != null) DetailRow(label: 'Description', value: t.s('description')),
      DetailRow(label: 'Weight', value: '$weight point(s)'),
      DetailRow(label: 'Assigned By', value: t.s('assignedByName')),
      DetailRow(label: 'Assigned On', value: fmtDate(t.at('assignedAt'))),
      if (t.sn('submittedAt') != null)
        DetailRow(
          label: 'Submitted',
          value: '${fmtDate(t.at('submittedAt'))}'
              '${type == 'GOAL' && percent != null ? ' — $percent% achieved' : ''}'
              '${_quoted(t.sn('submissionNote'))}',
        ),
      if (status == 'VERIFIED') ...[
        DetailRow(
          label: 'Verified',
          value: '${fmtDate(t.at('verifiedAt'))} by ${t.sn('verifiedByName') ?? '—'}${_quoted(t.sn('verificationNote'))}',
        ),
        DetailRow(
          label: 'Earned Points',
          value: '${t.s('earnedPointsLabel')} of $weight'
              '${lateFactor != null && lateFactor < 1 ? ' (reduced for late submission)' : ''}',
        ),
      ],
      if (status == 'SENT_BACK' && t.sn('verificationNote') != null)
        DetailRow(label: 'Sent Back — Reason', value: t.s('verificationNote')),
      if (status == 'CANCELLED')
        DetailRow(
          label: 'Cancelled',
          value: '${fmtDate(t.at('cancelledAt'))} by ${t.sn('cancelledByName') ?? '—'}${_quoted(t.sn('cancellationNote'))}',
        ),
    ];
  }
}

class _SubmitTaskForm extends StatefulWidget {
  const _SubmitTaskForm({required this.taskId, required this.isGoal});
  final String taskId;
  final bool isGoal;

  @override
  State<_SubmitTaskForm> createState() => _SubmitTaskFormState();
}

class _SubmitTaskFormState extends State<_SubmitTaskForm> {
  final _percent = TextEditingController();
  final _note = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _percent.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('tasks.submitTask', args: [widget.taskId], fields: {
        if (widget.isGoal) 'percentAchieved': _percent.text,
        'submissionNote': _note.text,
      }),
      followRedirects: false,
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
      children: [
        if (widget.isGoal)
          TsInput(
            label: 'Percent Achieved',
            controller: _percent,
            keyboardType: TextInputType.number,
            inputFormatters: TsInput.digitsOnly,
            maxLength: 3,
            hint: 'E.g. 80 for 80% of target - partial credit is applied automatically.',
          ),
        TsTextarea(label: 'Note (optional)', controller: _note, rows: 3),
        if (_error != null) StatusMessage.error(_error),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton(label: 'Submit', pendingLabel: 'Submitting...', pending: _pending, onPressed: _submit),
        ),
      ],
    );
  }
}

/// Two independent forms (Verify, Send Back) sharing one error line.
class _VerifyOrSendBackPanel extends StatefulWidget {
  const _VerifyOrSendBackPanel({required this.taskId});
  final String taskId;

  @override
  State<_VerifyOrSendBackPanel> createState() => _VerifyOrSendBackPanelState();
}

class _VerifyOrSendBackPanelState extends State<_VerifyOrSendBackPanel> {
  final _verifyNote = TextEditingController();
  final _reason = TextEditingController();
  bool _verifying = false;
  bool _sendingBack = false;
  String? _verifyError;
  String? _sendBackError;

  @override
  void dispose() {
    _verifyNote.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _verifying = true;
      _verifyError = null;
    });
    final r = await runAction(
      context,
      () => api.action('tasks.verifyTask', args: [widget.taskId], fields: {'verificationNote': _verifyNote.text}),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _verifying = false;
      _verifyError = r.error;
    });
  }

  Future<void> _sendBack() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _sendingBack = true;
      _sendBackError = null;
    });
    final r = await runAction(
      context,
      () => api.action('tasks.sendBackTask', args: [widget.taskId], fields: {'verificationNote': _reason.text}),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _sendingBack = false;
      _sendBackError = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final error = _verifyError ?? _sendBackError;
    return Gap(
      children: [
        TsTextarea(label: 'Note (optional)', controller: _verifyNote, rows: 2),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton(
            label: 'Verify',
            pendingLabel: 'Verifying...',
            pending: _verifying,
            icon: LucideIcons.check,
            onPressed: _sendingBack ? null : _verify,
          ),
        ),
        Divider(height: 8, color: p.border),
        TsTextarea(label: 'Reason (required to send back)', controller: _reason, rows: 2),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton.danger(
            label: 'Send Back',
            pendingLabel: 'Sending Back...',
            pending: _sendingBack,
            icon: LucideIcons.undo2,
            onPressed: _verifying ? null : _sendBack,
          ),
        ),
        if (error != null) StatusMessage.error(error),
      ],
    );
  }
}

class _CancelTaskForm extends StatefulWidget {
  const _CancelTaskForm({required this.taskId});
  final String taskId;

  @override
  State<_CancelTaskForm> createState() => _CancelTaskFormState();
}

class _CancelTaskFormState extends State<_CancelTaskForm> {
  final _note = TextEditingController();
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('tasks.cancelTask', args: [widget.taskId], fields: {'cancellationNote': _note.text}),
      followRedirects: false,
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
      children: [
        TsTextarea(label: 'Note (optional)', controller: _note, rows: 2),
        if (_error != null) StatusMessage.error(_error),
        Align(
          alignment: Alignment.centerLeft,
          child: TsButton.danger(
            label: 'Cancel Task',
            pendingLabel: 'Cancelling...',
            pending: _pending,
            onPressed: _cancel,
          ),
        ),
      ],
    );
  }
}
