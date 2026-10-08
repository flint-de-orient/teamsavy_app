import '../../widgets/ts.dart';

/// app/(app)/tasks/assign/page.tsx + assign-task-form.tsx.
class AssignTaskScreen extends StatelessWidget {
  const AssignTaskScreen({super.key});

  static PageHeader _header(bool isHr) => PageHeader(
        title: 'Assign Task',
        description: isHr
            ? 'Assign an ad-hoc task or goal to anyone in the organization.'
            : 'Assign an ad-hoc task or goal to one of your direct reports.',
      );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/tasks/assign',
      header: _header(session.me?.isHr ?? false),
      builder: (context, data, reload) => [
        _header(data.b('isHr')),
        _AssignTaskForm(employees: data.l('employees')),
      ],
    );
  }
}

class _AssignTaskForm extends StatefulWidget {
  const _AssignTaskForm({required this.employees});
  final List<Json> employees;

  @override
  State<_AssignTaskForm> createState() => _AssignTaskFormState();
}

class _AssignTaskFormState extends State<_AssignTaskForm> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _weight = TextEditingController(text: '10');
  String? _assignedToId;
  String _type = 'AD_HOC';
  String? _dueDate;
  bool _pending = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
      _success = false;
    });
    // Empty strings, not nulls: the web form posts every field, and the
    // action's validation messages depend on seeing "" for a blank one.
    final r = await runAction(
      context,
      () => api.action('tasks.createTask', fields: {
        'assignedToId': _assignedToId ?? '',
        'type': _type,
        'title': _title.text,
        'description': _description.text,
        'weight': _weight.text,
        'dueDate': _dueDate ?? '',
      }),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _success = r.ok;
      if (r.ok) {
        // The web form resets its uncontrolled fields after a successful
        // submit; only the controlled Type select keeps its value.
        _assignedToId = null;
        _title.clear();
        _description.clear();
        _weight.text = '10';
        _dueDate = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return TsCard(
      child: Gap(
        children: [
          TsSelect<String>(
            label: 'Assign To',
            value: _assignedToId,
            placeholder: 'Select an employee',
            options: [
              for (final e in widget.employees) SelectOption(e.s('id'), '${e.s('name')} — ${e.s('designation')}'),
            ],
            onChanged: (v) => setState(() => _assignedToId = v),
          ),
          TsSelect<String>(
            label: 'Type',
            value: _type,
            options: const [
              SelectOption('AD_HOC', 'Ad-hoc task'),
              SelectOption('GOAL', 'Goal (periodic target)'),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'AD_HOC'),
          ),
          TsInput(label: 'Title', controller: _title, textCapitalization: TextCapitalization.sentences),
          TsTextarea(label: 'Description (optional)', controller: _description, rows: 3),
          TsInput(
            label: 'Weight (points toward KPI)',
            controller: _weight,
            keyboardType: TextInputType.number,
            inputFormatters: TsInput.digitsOnly,
            hint: 'How much this task is worth relative to everything else assigned this month.',
          ),
          TsDateField(
            label: 'Due Date',
            value: _dueDate,
            onChanged: (v) => setState(() => _dueDate = v),
          ),
          if (_type == 'GOAL')
            Text(
              'The employee will report a percent achieved (e.g. "80% of target") when they submit this goal - '
              'partial credit is applied automatically.',
              style: tx(12, color: Ts.of(context).muted, height: 1.5),
            ),
          if (_error != null) StatusMessage.error(_error),
          if (_success) StatusMessage.success('Task assigned.'),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton(
              label: 'Assign Task',
              pendingLabel: 'Assigning...',
              pending: _pending,
              icon: LucideIcons.listTodo,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
