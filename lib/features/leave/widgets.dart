import '../../widgets/ts.dart';

// Pieces shared by the leave, leave-encashment and regularization screens.
// The three web flows reuse the same status maps, approve/reject panel and
// cancel button, so the app does too.

/// Request status on "my" lists and detail pages (all three request kinds).
const kStatusLabel = {
  'PENDING_MANAGER': 'Pending Manager',
  'PENDING_HR': 'Pending HR',
  'APPROVED': 'Approved',
  'REJECTED': 'Rejected',
  'CANCELLED': 'Cancelled',
};

const _statusTone = {
  'PENDING_MANAGER': BadgeTone.amber,
  'PENDING_HR': BadgeTone.amber,
  'APPROVED': BadgeTone.green,
  'REJECTED': BadgeTone.red,
  'CANCELLED': BadgeTone.slate,
};

/// HR queue pages colour "Pending HR" blue, unlike every other page.
const _queueTone = {'PENDING_MANAGER': BadgeTone.amber, 'PENDING_HR': BadgeTone.blue};

TsBadge statusBadge(String status) =>
    TsBadge(kStatusLabel[status] ?? status, tone: _statusTone[status] ?? BadgeTone.slate);

TsBadge queueBadge(String status) =>
    TsBadge(kStatusLabel[status] ?? status, tone: _queueTone[status] ?? BadgeTone.slate);

/// LEAVE_TYPE_LABELS, in the order every web select lists them.
const kLeaveTypes = [
  SelectOption('EARNED', 'Earned Leave'),
  SelectOption('CASUAL', 'Casual Leave'),
  SelectOption('SICK', 'Sick Leave'),
  SelectOption('MATERNITY', 'Maternity Leave'),
  SelectOption('PATERNITY', 'Paternity Leave'),
  SelectOption('BEREAVEMENT', 'Bereavement Leave'),
  SelectOption('COMPENSATORY_OFF', 'Compensatory Off'),
  SelectOption('LEAVE_WITHOUT_PAY', 'Leave Without Pay'),
];

const kRegularizationTypes = [
  SelectOption('MISSING_PUNCH_IN', 'Missing Punch In'),
  SelectOption('MISSING_PUNCH_OUT', 'Missing Punch Out'),
  SelectOption('WRONG_TIME', 'Wrong Time'),
  SelectOption('FORGOT_TO_PUNCH', 'Forgot to Punch'),
];

/// `{start} – {end}` with the web's en dash.
String dateRange(Object? start, Object? end) => '${fmtDate(start)} – ${fmtDate(end)}';

/// The phone list body: MobileCards, or the empty state.
List<Widget> cardList(List<Json> items, String empty, Widget Function(Json item) card) =>
    items.isEmpty ? [EmptyState(empty)] : [for (final item in items) card(item)];

/// The detail pages' "Approve with optional note / Reject with required
/// reason" pair (ApproveRejectPanel in each web *-actions.tsx). Two
/// independent forms sharing one error line; on success the page reloads
/// and, since the request is no longer pending, the panel disappears.
class ApproveRejectPanel extends StatefulWidget {
  const ApproveRejectPanel({super.key, required this.id, required this.approveAction, required this.rejectAction});
  final String id;
  final String approveAction;
  final String rejectAction;

  @override
  State<ApproveRejectPanel> createState() => _ApproveRejectPanelState();
}

class _ApproveRejectPanelState extends State<ApproveRejectPanel> {
  final _approveNote = TextEditingController();
  final _rejectNote = TextEditingController();
  bool _approving = false;
  bool _rejecting = false;
  String? _approveError;
  String? _rejectError;

  @override
  void dispose() {
    _approveNote.dispose();
    _rejectNote.dispose();
    super.dispose();
  }

  Future<void> _run({required bool approve}) async {
    setState(() {
      if (approve) {
        _approving = true;
      } else {
        _rejecting = true;
      }
    });
    final r = await runAction(
      context,
      () => api.action(
        approve ? widget.approveAction : widget.rejectAction,
        args: [widget.id],
        fields: {'note': (approve ? _approveNote : _rejectNote).text},
      ),
    );
    if (!mounted) return;
    setState(() {
      if (approve) {
        _approving = false;
        _approveError = r.error;
      } else {
        _rejecting = false;
        _rejectError = r.error;
      }
    });
  }

  Widget _form({required TextEditingController note, required String label, required Widget button}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: TsTextarea(controller: note, label: label, rows: 2)),
        const SizedBox(width: 12),
        button,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _approving || _rejecting;
    final error = _approveError ?? _rejectError;
    return Gap(
      gap: 12,
      children: [
        _form(
          note: _approveNote,
          label: 'Note (optional)',
          button: TsButton(
            label: 'Approve',
            pendingLabel: 'Approving...',
            pending: _approving,
            onPressed: busy ? null : () => _run(approve: true),
          ),
        ),
        _form(
          note: _rejectNote,
          label: 'Reason (required to reject)',
          button: TsButton.danger(
            label: 'Reject',
            pendingLabel: 'Rejecting...',
            pending: _rejecting,
            onPressed: busy ? null : () => _run(approve: false),
          ),
        ),
        if (error != null) StatusMessage.error(error),
      ],
    );
  }
}

/// CancelRequestButton: a danger "Cancel Request" with its error above it.
class CancelRequestButton extends StatefulWidget {
  const CancelRequestButton({super.key, required this.id, required this.action});
  final String id;
  final String action;

  @override
  State<CancelRequestButton> createState() => _CancelRequestButtonState();
}

class _CancelRequestButtonState extends State<CancelRequestButton> {
  bool _pending = false;
  String? _error;

  Future<void> _cancel() async {
    setState(() => _pending = true);
    final r = await runAction(context, () => api.action(widget.action, args: [widget.id]));
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Gap(
      gap: 8,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null) StatusMessage.error(_error),
        TsButton.danger(label: 'Cancel Request', pendingLabel: 'Cancelling...', pending: _pending, onPressed: _cancel),
      ],
    );
  }
}

/// The Manager Approval / HR Approval / Cancel cards every request detail
/// page shows, driven by the flags its endpoint computes.
List<Widget> requestActionCards(
  Json data, {
  required String id,
  required String managerApprove,
  required String managerReject,
  required String hrApprove,
  required String hrReject,
  required String cancel,
}) =>
    [
      if (data.b('canManagerAct'))
        TsCard(
          title: 'Manager Approval',
          child: ApproveRejectPanel(id: id, approveAction: managerApprove, rejectAction: managerReject),
        ),
      if (data.b('canHrAct'))
        TsCard(
          title: 'HR Approval',
          child: ApproveRejectPanel(id: id, approveAction: hrApprove, rejectAction: hrReject),
        ),
      if (data.b('canCancel')) TsCard(title: 'Cancel', child: CancelRequestButton(id: id, action: cancel)),
    ];

/// The "Manager Decision" / "HR Decision" rows, shown once someone acted.
List<DetailRow> decisionRows(Json data) => [
      if (data.sn('managerDecision') != null) DetailRow(label: 'Manager Decision', value: data.s('managerDecision')),
      if (data.sn('hrDecision') != null) DetailRow(label: 'HR Decision', value: data.s('hrDecision')),
    ];

/// `<input type="datetime-local">`: value "YYYY-MM-DDTHH:mm" (IST wall
/// clock, exactly what the web form posts), picked as a date then a time.
/// The box reads like an en-IN browser's: "07/10/2026, 06:45 pm".
class DateTimeLocalField extends StatelessWidget {
  const DateTimeLocalField({super.key, required this.label, required this.value, required this.onChanged, this.initialDate});
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  /// Where the date picker opens when nothing is chosen yet.
  final DateTime? initialDate;

  DateTime? get _parsed => value == null ? null : DateTime.tryParse(value!);

  String _display(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    return '${two(d.day)}/${two(d.month)}/${d.year}, ${two(h)}:${two(d.minute)} ${d.hour < 12 ? 'am' : 'pm'}';
  }

  Future<void> _pick(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final current = _parsed;
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current ?? initialDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: _pickerTheme,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null ? const TimeOfDay(hour: 9, minute: 30) : TimeOfDay.fromDateTime(current),
      builder: _pickerTheme,
    );
    if (time == null) return;
    onChanged('${ymd(date)}T${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final parsed = _parsed;
    return FieldWrapper(
      label: label,
      child: FieldBox(
        onTap: () => _pick(context),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  parsed == null ? 'dd/mm/yyyy, --:--' : _display(parsed),
                  style: tx(14, color: parsed == null ? p.muted.withValues(alpha: 0.7) : p.foreground),
                ),
              ),
            ),
            if (parsed != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(LucideIcons.x, size: 16, color: p.muted),
                ),
              ),
            Icon(LucideIcons.calendarClock, size: 16, color: p.muted),
          ],
        ),
      ),
    );
  }
}

// Same picker styling as the shared date/time fields.
Widget _pickerTheme(BuildContext context, Widget? child) {
  final p = Ts.of(context);
  final theme = Theme.of(context);
  return Theme(
    data: theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        primary: p.dark ? p.accentViolet : const Color(0xFF3B2FA6),
        onPrimary: Colors.white,
        surface: p.surface,
        onSurface: p.foreground,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ts.r3xl)),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Ts.r3xl)),
      ),
    ),
    child: child!,
  );
}

/// A secondary button that downloads one of the web's file routes (report
/// exports, attachments) and opens it, showing a spinner meanwhile.
class OpenFileButton extends StatefulWidget {
  const OpenFileButton({super.key, required this.label, required this.path, this.icon});
  final String label;
  final String path;
  final IconData? icon;

  @override
  State<OpenFileButton> createState() => _OpenFileButtonState();
}

class _OpenFileButtonState extends State<OpenFileButton> {
  bool _pending = false;

  Future<void> _open() async {
    setState(() => _pending = true);
    await openFileOrToast(context, widget.path);
    if (mounted) setState(() => _pending = false);
  }

  @override
  Widget build(BuildContext context) =>
      TsButton.secondary(label: widget.label, icon: widget.icon, pending: _pending, onPressed: _open);
}

Future<void> openFileOrToast(BuildContext context, String path) async {
  try {
    await api.openFile(path);
  } catch (e) {
    if (context.mounted) toast(context, e is ApiException ? e.message : "Couldn't open this file.", error: true);
  }
}
