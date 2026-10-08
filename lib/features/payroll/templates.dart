import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';

import '../../widgets/ts.dart';
import 'settings.dart' show RemoveLink;

/// Which of the two column-mapping template kinds a screen is for: bank
/// file templates (/settings/bank-templates) or Professional Tax return
/// templates (/settings/return-templates).
enum TemplateKind { bank, ptReturn }

extension on TemplateKind {
  String get base => this == TemplateKind.bank ? '/settings/bank-templates' : '/settings/return-templates';
  String get saveAction => this == TemplateKind.bank ? 'payroll.saveBankFileTemplate' : 'payroll.saveReturnFileTemplate';
  String get deleteAction => this == TemplateKind.bank ? 'payroll.deleteBankFileTemplate' : 'payroll.deleteReturnFileTemplate';
}

/// app/(app)/settings/bank-templates/page.tsx
class BankTemplatesScreen extends StatelessWidget {
  const BankTemplatesScreen({super.key});

  static const _title = 'Bank File Templates';
  static const _description =
      "Define the column layout your bank's net-banking bulk salary upload expects - every bank's format is different, so map it here once and reuse it whenever you export a locked payroll run.";

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/bank-templates',
      header: const PageHeader(title: _title, description: _description),
      builder: (context, data, reload) {
        final canWrite = data.b('canWrite');
        final templates = data.l('templates');
        return [
          PageHeader(
            title: _title,
            description: _description,
            actions: [
              if (canWrite)
                TsButton(
                  label: 'New Template',
                  icon: LucideIcons.plus,
                  onPressed: () => context.push('/settings/bank-templates/new'),
                ),
            ],
          ),
          if (templates.isEmpty) const EmptyState('No bank file templates yet.', icon: LucideIcons.fileSpreadsheet),
          for (final t in templates)
            _TemplateCard(kind: TemplateKind.bank, template: t, title: t.s('name'), canWrite: canWrite),
        ];
      },
    );
  }
}

/// app/(app)/settings/return-templates/page.tsx
class ReturnTemplatesScreen extends StatelessWidget {
  const ReturnTemplatesScreen({super.key});

  static const _title = 'Professional Tax Return Templates';
  static const _description =
      "Define the column layout each state's Professional Tax return expects - there's no national standard, so map it here once per state and reuse it whenever you generate a return.";

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/return-templates',
      header: const PageHeader(title: _title, description: _description),
      builder: (context, data, reload) {
        final canWrite = data.b('canWrite');
        final templates = data.l('templates');
        return [
          PageHeader(
            title: _title,
            description: _description,
            actions: [
              TsButton.secondary(label: 'Back to Statutory Returns', onPressed: () => followRedirect(context, '/payroll/returns')),
              if (canWrite)
                TsButton(
                  label: 'New Template',
                  icon: LucideIcons.plus,
                  onPressed: () => context.push('/settings/return-templates/new'),
                ),
            ],
          ),
          if (templates.isEmpty) const EmptyState('No return file templates yet.', icon: LucideIcons.fileSpreadsheet),
          for (final t in templates)
            _TemplateCard(
              kind: TemplateKind.ptReturn,
              template: t,
              title: '${t.s('state')} - ${t.s('name')}',
              canWrite: canWrite,
            ),
        ];
      },
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.kind, required this.template, required this.title, required this.canWrite});
  final TemplateKind kind;
  final Json template;
  final String title;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final edit = '${kind.base}/${template.s('id')}/edit';
    return MobileCard(
      onTap: canWrite ? () => context.push(edit) : null,
      children: [
        MobileCardHeader(
          title: title,
          action: canWrite ? Icon(LucideIcons.chevronRight, size: 18, color: Ts.of(context).muted) : null,
        ),
        MobileCardRows(rows: [
          MobileCardRow(label: 'Format', value: template.s('fileFormat')),
          MobileCardRow(label: 'Columns', value: '${template.i('columnCount')}'),
        ]),
        if (canWrite)
          MobileCardFooter(
            child: Row(
              children: [
                TsLink('Edit', onTap: () => context.push(edit)),
                const Spacer(),
                RemoveLink(action: kind.deleteAction, id: template.s('id')),
              ],
            ),
          ),
      ],
    );
  }
}

/// /settings/{bank,return}-templates/new and /[id]/edit.
class TemplateFormScreen extends StatelessWidget {
  const TemplateFormScreen({super.key, required this.kind, this.id});
  final TemplateKind kind;
  final String? id;

  String get _title {
    final noun = kind == TemplateKind.bank ? 'Bank File Template' : 'Professional Tax Return Template';
    return id == null ? 'New $noun' : 'Edit $noun';
  }

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(title: _title);
    return ApiScreen(
      path: id == null ? '${kind.base}/new' : '${kind.base}/$id/edit',
      header: header,
      builder: (context, data, reload) => [
        header,
        _TemplateForm(
          key: ValueKey(id ?? 'new'),
          kind: kind,
          fields: data.l('fields'),
          template: data.mN('template'),
        ),
      ],
    );
  }
}

class _Column {
  _Column(String header, this.field) : header = TextEditingController(text: header);
  final TextEditingController header;
  String field;
  final key = UniqueKey();
}

/// bank-template-form.tsx / return-template-form.tsx
class _TemplateForm extends StatefulWidget {
  const _TemplateForm({super.key, required this.kind, required this.fields, this.template});
  final TemplateKind kind;
  final List<Json> fields;
  final Json? template;

  @override
  State<_TemplateForm> createState() => _TemplateFormState();
}

class _TemplateFormState extends State<_TemplateForm> {
  late final _state = TextEditingController(text: widget.template?.s('state') ?? '');
  late final _name = TextEditingController(text: widget.template?.s('name') ?? '');
  late String _format = widget.template?.s('fileFormat', 'CSV') ?? 'CSV';
  late final List<_Column> _columns = [
    for (final c in widget.template?.l('columns') ?? const <Json>[]) _Column(c.s('header'), c.s('field')),
  ];
  String? _sampleName;
  bool _pending = false;
  String? _error;

  bool get _isBank => widget.kind == TemplateKind.bank;

  // Removed rows' fields are still mounted until the next frame.
  void _disposeLater(List<TextEditingController> controllers) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final c in controllers) {
        c.dispose();
      }
    });
  }

  @override
  void dispose() {
    _state.dispose();
    _name.dispose();
    for (final c in _columns) {
      c.header.dispose();
    }
    super.dispose();
  }

  /// BankTemplateForm's parseCsvHeaderLine: a plain comma split of the
  /// header row, honouring double quotes.
  List<String> _parseHeaderLine(String line) {
    final result = <String>[];
    final cur = StringBuffer();
    var inQuotes = false;
    for (final ch in line.split('')) {
      if (ch == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (ch == ',' && !inQuotes) {
        result.add(cur.toString().trim());
        cur.clear();
        continue;
      }
      cur.write(ch);
    }
    result.add(cur.toString().trim());
    return result.where((h) => h.isNotEmpty).toList();
  }

  Future<void> _pickSample() async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: const ['csv']);
    final path = picked?.files.single.path;
    if (path == null) return;
    String firstLine;
    try {
      final text = await File(path).readAsString();
      firstLine = text.split(RegExp(r'\r?\n')).first.replaceFirst('﻿', '');
    } catch (_) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _disposeLater(_columns.map((c) => c.header).toList());
      _columns
        ..clear()
        ..addAll(_parseHeaderLine(firstLine).map((h) => _Column(h, '')));
      _sampleName = picked!.files.single.name;
    });
  }

  Future<void> _save() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final columns = jsonEncode([
      for (final c in _columns) {'header': c.header.text, 'field': c.field},
    ]);
    final r = await runAction(
      context,
      () => api.action(widget.kind.saveAction, fields: {
        if (widget.template != null) 'id': widget.template!.s('id'),
        if (!_isBank) 'state': _state.text.trim(),
        'name': _name.text.trim(),
        'fileFormat': _format,
        'columns': columns,
      }),
      followRedirects: false,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
    if (r.ok) followRedirect(context, widget.kind.base);
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final fieldOptions = [
      const SelectOption('', '— Select —'),
      for (final f in widget.fields) SelectOption(f.s('key'), f.s('label')),
    ];
    return Gap(
      gap: 16,
      children: [
        TsCard(
          child: Gap(
            gap: 16,
            children: [
              if (!_isBank)
                TsInput(
                  controller: _state,
                  label: 'State',
                  placeholder: 'Maharashtra',
                  hint: 'Professional Tax has no national standard - one template per state.',
                  textCapitalization: TextCapitalization.words,
                ),
              TsInput(
                controller: _name,
                label: 'Template Name',
                placeholder: _isBank ? 'HDFC Corporate Salary Upload' : 'Maharashtra PT Monthly Return',
              ),
              TsSelect<String>(
                label: 'Output File Format',
                value: _format,
                options: const [SelectOption('CSV', 'CSV'), SelectOption('XLSX', 'Excel (XLSX)')],
                onChanged: (v) => setState(() => _format = v ?? 'CSV'),
              ),
              if (_isBank)
                FieldWrapper(
                  label: 'Upload a sample file to prefill column headers (optional)',
                  hint: 'Reads only the first (header) row of a CSV file, entirely on your device - nothing is uploaded.',
                  child: FieldBox(
                    onTap: _pickSample,
                    child: Row(
                      children: [
                        Icon(_sampleName == null ? LucideIcons.upload : LucideIcons.fileCheck,
                            size: 16, color: _sampleName == null ? p.muted : p.success),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              _sampleName ?? 'Choose a CSV file',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tx(14, color: _sampleName == null ? p.muted.withValues(alpha: 0.7) : p.foreground),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        TsCard(
          title: 'Columns, in output order',
          icon: LucideIcons.columns3,
          child: Gap(
            gap: 12,
            children: [
              if (_columns.isEmpty)
                Muted(_isBank
                    ? 'No columns yet - upload a sample file above, or add one manually.'
                    : 'No columns yet - add one below.'),
              for (var i = 0; i < _columns.length; i++)
                TsPanel(
                  key: _columns[i].key,
                  padding: const EdgeInsets.all(14),
                  child: Gap(
                    gap: 12,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: p.primaryLight, shape: BoxShape.circle),
                            child: Text('${i + 1}', style: tx(12, weight: FontWeight.w700, color: p.primary)),
                          ),
                          const Spacer(),
                          TsButton.danger(
                            label: 'Remove',
                            compact: true,
                            onPressed: () => setState(() => _disposeLater([_columns.removeAt(i).header])),
                          ),
                        ],
                      ),
                      TsInput(controller: _columns[i].header, label: 'Column Header'),
                      TsSelect<String>(
                        label: 'Maps To',
                        value: _columns[i].field,
                        options: fieldOptions,
                        onChanged: (v) => setState(() => _columns[i].field = v ?? ''),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TsButton.secondary(
                  label: 'Add Column',
                  icon: LucideIcons.plus,
                  onPressed: () => setState(() => _columns.add(_Column('', ''))),
                ),
              ),
            ],
          ),
        ),
        if (_error != null) StatusMessage.error(_error),
        TsButton(label: 'Save Template', pendingLabel: 'Saving...', pending: _pending, expand: true, onPressed: _save),
      ],
    );
  }
}
