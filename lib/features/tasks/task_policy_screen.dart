import '../../widgets/ts.dart';

/// app/(app)/settings/task-policy/page.tsx + task-policy-form.tsx. HR can
/// open it, but saving is TENANT_ADMIN-only - the action's own error says so.
class TaskPolicyScreen extends StatelessWidget {
  const TaskPolicyScreen({super.key});

  static const _header = PageHeader(
    title: 'Task Policy',
    description: "Controls how a late task's KPI points decay. Entitlements/weights/due dates are set per task, not here.",
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/task-policy',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        _TaskPolicyForm(initial: data.i('taskLatePenaltyPercentPerDay', 10)),
      ],
    );
  }
}

class _TaskPolicyForm extends StatefulWidget {
  const _TaskPolicyForm({required this.initial});
  final int initial;

  @override
  State<_TaskPolicyForm> createState() => _TaskPolicyFormState();
}

class _TaskPolicyFormState extends State<_TaskPolicyForm> {
  late final _penalty = TextEditingController(text: '${widget.initial}');
  bool _pending = false;
  String? _error;
  bool _saved = false;

  @override
  void dispose() {
    _penalty.dispose();
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
      () => api.action('tasks.updateTaskPolicy', fields: {'taskLatePenaltyPercentPerDay': _penalty.text}),
      followRedirects: false,
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
    return TsCard(
      child: Gap(
        children: [
          TsInput(
            label: 'Late Penalty (% of points lost per day late)',
            controller: _penalty,
            keyboardType: TextInputType.number,
            inputFormatters: TsInput.digitsOnly,
            maxLength: 3,
            hint: 'E.g. 10 means a task submitted 3 days late earns 70% of its points. '
                'Floors at 0 - a task never earns negative points.',
          ),
          if (_error != null) StatusMessage.error(_error),
          if (_saved) StatusMessage.success('Saved.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton(label: 'Save', pendingLabel: 'Saving...', pending: _pending, onPressed: _save),
          ),
        ],
      ),
    );
  }
}
