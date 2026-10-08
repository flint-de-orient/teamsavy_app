import '../../widgets/ts.dart';
import 'notices_screens.dart';
import 'widgets.dart';

const _description =
    'Draft with AI, review, and publish - published notices reach every concerned employee via WhatsApp.';

const _typeOptions = [
  SelectOption('CIRCULAR', 'Circular'),
  SelectOption('OFFICE_ORDER', 'Office Order'),
  SelectOption('NOTICE', 'Notice'),
];

const _typeSegment = {'CIRCULAR': 'CIRC', 'OFFICE_ORDER': 'OO', 'NOTICE': 'NOT'};

/// app/(app)/notices/new/page.tsx and [id]/edit/page.tsx (NoticeForm).
class NoticeFormScreen extends StatelessWidget {
  const NoticeFormScreen({super.key, this.noticeId});
  final String? noticeId;

  @override
  Widget build(BuildContext context) {
    final id = noticeId;
    final header = PageHeader(title: id == null ? 'New Circular / Office Order / Notice' : 'Edit Draft', description: _description);
    return ApiScreen(
      path: id == null ? '/notices/new' : '/notices/$id/edit',
      header: header,
      builder: (context, data, reload) {
        final redirect = data.sn('redirect');
        if (redirect != null) return redirectInstead(context, redirect);
        return [header, _NoticeForm(key: ValueKey(id), data: data)];
      },
    );
  }
}

class _NoticeForm extends StatefulWidget {
  const _NoticeForm({super.key, required this.data});
  final Json data;

  @override
  State<_NoticeForm> createState() => _NoticeFormState();
}

class _NoticeFormState extends State<_NoticeForm> {
  final _topic = TextEditingController();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  final _memoNo = TextEditingController();
  final _search = TextEditingController();

  late String _type;
  late String _memoNoMode;
  late String _issueDateMode;
  late String _issueDate;
  late String _audience;
  late Set<String> _departments;
  late Set<String> _employeeIds;

  bool _generating = false;
  String? _generateError;
  bool _saving = false;
  String? _saveError;
  bool _saveSuccess = false;
  bool _publishing = false;
  String? _publishError;
  bool _deleting = false;

  Json? get _existing => widget.data.mN('notice');

  @override
  void initState() {
    super.initState();
    final n = _existing ?? const <String, dynamic>{};
    _type = n.s('type', 'CIRCULAR');
    _subject.text = n.s('subject');
    _body.text = n.s('bodyText');
    _memoNoMode = n.s('memoNoMode', 'AUTO');
    _memoNo.text = n.s('memoNo');
    _issueDateMode = n.s('issueDateMode', 'AUTO');
    // toDateInputValue(new Date()) on the web - the UTC calendar date.
    _issueDate = n.sn('issueDate') ?? ymd(DateTime.now().toUtc());
    _audience = n.s('audience', 'ALL_EMPLOYEES');
    _departments = n.list<String>('departments').toSet();
    _employeeIds = n.list<String>('specificEmployeeIds').toSet();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_topic, _subject, _body, _memoNo, _search]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _memoPreview {
    final d = _issueDateMode == 'MANUAL' && _issueDate.isNotEmpty
        ? (DateTime.tryParse(_issueDate) ?? DateTime.now())
        : DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    final key = '${two(d.year % 100)}${two(d.month)}${two(d.day)}';
    return '${widget.data.s('companyAbbreviation', 'CO')}/HR/${_typeSegment[_type]}/${key}XX';
  }

  List<Json> get _filteredEmployees {
    final q = _search.text.trim().toLowerCase();
    final all = widget.data.l('employees');
    final matches = q.isEmpty
        ? all
        : all.where((e) => e.s('name').toLowerCase().contains(q) || e.s('department').toLowerCase().contains(q));
    return matches.take(30).toList();
  }

  /// NoticeForm's buildInput(), as form fields.
  Map<String, Object?> _input() => {
        'id': _existing?.s('id'),
        'type': _type,
        'subject': _subject.text,
        'bodyText': _body.text,
        'memoNoMode': _memoNoMode,
        if (_memoNoMode == 'MANUAL') 'memoNo': _memoNo.text,
        'issueDateMode': _issueDateMode,
        if (_issueDateMode == 'MANUAL') 'issueDate': _issueDate,
        'audience': _audience,
        'departments': _departments.toList(),
        'specificEmployeeIds': _employeeIds.toList(),
      };

  Future<void> _generate() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _generating = true;
      _generateError = null;
    });
    final r = await api.action('people.generateNoticeDraft', fields: {'type': _type, 'topic': _topic.text});
    if (!mounted) return;
    setState(() {
      _generating = false;
      if (!r.ok) {
        _generateError = r.error;
      } else {
        _subject.text = r.data?.s('subject') ?? '';
        _body.text = r.data?.s('body') ?? '';
      }
    });
  }

  Future<void> _saveDraft() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
      _saveSuccess = false;
    });
    final r = await runAction(context, () => api.action('people.saveNoticeDraft', fields: _input()));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = r.error;
      _saveSuccess = r.ok;
    });
    if (r.ok && _existing == null) {
      toast(context, 'Draft saved.');
      context.pushReplacement('/notices/${r.data?.s('id')}/edit');
    }
  }

  Future<void> _publish() async {
    FocusScope.of(context).unfocus();
    final ok = await confirmDialog(
      context,
      message:
          "Publish now? Every concerned employee will get a WhatsApp notification with a link to view it. This can't be undone.",
      confirmLabel: 'Publish',
    );
    if (!ok || !mounted) return;
    setState(() {
      _publishing = true;
      _publishError = null;
    });
    final saved = await api.action('people.saveNoticeDraft', fields: _input());
    if (!mounted) return;
    if (!saved.ok) {
      setState(() {
        _publishError = saved.error;
        _publishing = false;
      });
      return;
    }
    final id = saved.data?.s('id') ?? '';
    final r = await runAction(context, () => api.action('people.publishNotice', args: [id]));
    if (!mounted) return;
    setState(() {
      _publishing = false;
      _publishError = r.error;
    });
    if (r.ok) followRedirect(context, '/notices/$id');
  }

  Future<void> _delete() async {
    final existing = _existing;
    if (existing == null) return;
    final ok = await confirmDialog(
      context,
      message: "Delete this draft? This can't be undone.",
      confirmLabel: 'Delete Draft',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    final r = await runAction(
      context,
      () => api.action('people.deleteNoticeDraft', args: [existing.s('id')]),
      toastErrors: true,
    );
    if (!mounted) return;
    setState(() => _deleting = false);
    if (r.ok) followRedirect(context, '/notices');
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final departments = widget.data.list<String>('departments');
    return Gap(
      gap: 24,
      children: [
        TitledPanel(
          title: 'Type',
          children: [
            RadioRow<String>(value: _type, options: _typeOptions, onChanged: (v) => setState(() => _type = v)),
          ],
        ),
        TitledPanel(
          title: 'Draft with AI',
          tinted: true,
          description:
              'Describe the topic - include any specific names, dates, numbers, or amounts. AI writes the subject and '
              'full body; you can edit everything below afterward. AI also has access to your configured Leave, '
              'Attendance, and Holiday Calendar policies, so it can cite real numbers and dates for those topics. The '
              'company letterhead, Memo No., and Date are added automatically when you Publish - no need to mention '
              'them here.',
          children: [
            TsTextarea(
              controller: _topic,
              rows: 2,
              placeholder:
                  'e.g. "Revised office timings from 1st September - new hours 9:30 AM to 6:30 PM, effective for all departments except Sales"',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TsButton.secondary(
                label: 'Generate with AI',
                icon: LucideIcons.sparkles,
                pendingLabel: 'Drafting...',
                pending: _generating,
                onPressed: _generate,
              ),
            ),
            if (_generateError != null) StatusMessage.error(_generateError),
          ],
        ),
        TitledPanel(
          title: 'Content',
          children: [
            TsInput(controller: _subject, label: 'Subject', textCapitalization: TextCapitalization.sentences),
            TsInput(
              controller: _body,
              label: 'Body',
              minLines: 12,
              maxLines: 30,
              textCapitalization: TextCapitalization.sentences,
              hint: 'Blank line between paragraphs. For a list, start each line with "- ".',
            ),
          ],
        ),
        TsPanel(
          child: Gap(
            gap: 20,
            children: [
              Gap(
                gap: 8,
                children: [
                  const GroupLabel('Memo No.'),
                  RadioRow<String>(
                    value: _memoNoMode,
                    options: const [SelectOption('AUTO', 'Auto Generate'), SelectOption('MANUAL', 'Manual')],
                    onChanged: (v) => setState(() => _memoNoMode = v),
                  ),
                  _memoNoMode == 'MANUAL'
                      ? TsInput(controller: _memoNo, placeholder: 'e.g. ABC/HR/CIRC/26082601')
                      : Text('Next number will look like: $_memoPreview', style: tx(12, color: p.muted)),
                ],
              ),
              Gap(
                gap: 8,
                children: [
                  const GroupLabel('Date'),
                  RadioRow<String>(
                    value: _issueDateMode,
                    options: const [
                      SelectOption('AUTO', 'Today (at publish time)'),
                      SelectOption('MANUAL', 'Choose a date'),
                    ],
                    onChanged: (v) => setState(() => _issueDateMode = v),
                  ),
                  if (_issueDateMode == 'MANUAL')
                    TsDateField(value: _issueDate, onChanged: (v) => setState(() => _issueDate = v ?? '')),
                ],
              ),
            ],
          ),
        ),
        TitledPanel(
          title: 'Who should get this?',
          children: [
            TsSelect<String>(
              value: _audience,
              options: const [
                SelectOption('ALL_EMPLOYEES', 'All Employees'),
                SelectOption('DEPARTMENTS', 'Specific Departments'),
                SelectOption('SPECIFIC_EMPLOYEES', 'Specific Employees'),
              ],
              onChanged: (v) => setState(() => _audience = v ?? 'ALL_EMPLOYEES'),
            ),
            if (_audience == 'DEPARTMENTS')
              departments.isEmpty
                  ? const Muted('No departments found.')
                  : LayoutBuilder(
                      builder: (context, box) => Wrap(
                        children: [
                          for (final dept in departments)
                            SizedBox(
                              width: box.maxWidth / 2,
                              child: TsCheckbox(
                                label: dept,
                                value: _departments.contains(dept),
                                onChanged: (v) => setState(() => v ? _departments.add(dept) : _departments.remove(dept)),
                              ),
                            ),
                        ],
                      ),
                    ),
            if (_audience == 'SPECIFIC_EMPLOYEES') ...[
              TsInput(
                controller: _search,
                placeholder: 'Search employees by name or department...',
                prefix: Icon(LucideIcons.search, size: 16, color: p.muted),
              ),
              TsPanel(
                padding: const EdgeInsets.all(8),
                radius: Ts.rLg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final e in _filteredEmployees)
                      TsCheckbox(
                        label: e.s('name'),
                        hint: e.s('department'),
                        value: _employeeIds.contains(e.s('id')),
                        onChanged: (v) =>
                            setState(() => v ? _employeeIds.add(e.s('id')) : _employeeIds.remove(e.s('id'))),
                      ),
                    if (_filteredEmployees.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Muted('No matches.')),
                  ],
                ),
              ),
              Text('${_employeeIds.length} employee(s) selected.', style: tx(12, color: p.muted)),
            ],
          ],
        ),
        if (_saveError != null || (!_saving && _saveSuccess) || _publishError != null)
          Gap(
            gap: 8,
            children: [
              if (_saveError != null) StatusMessage.error(_saveError),
              if (!_saving && _saveSuccess) StatusMessage.success('Draft saved.'),
              if (_publishError != null) StatusMessage.error(_publishError),
            ],
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            TsButton.secondary(label: 'Save Draft', pendingLabel: 'Saving...', pending: _saving, onPressed: _saveDraft),
            TsButton(
              label: 'Publish',
              icon: LucideIcons.send,
              pendingLabel: 'Publishing...',
              pending: _publishing,
              onPressed: _publish,
            ),
            if (_existing != null)
              TsButton.danger(label: 'Delete Draft', pendingLabel: 'Deleting...', pending: _deleting, onPressed: _delete),
          ],
        ),
      ],
    );
  }
}
