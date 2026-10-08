import 'package:flutter/services.dart';

import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/kpi/page.tsx - My KPI (?month=YYYY-MM). The web's three score
/// cards (Effective, Computed, Points Assigned) are shown as one scorecard
/// with the effective score as a ring; numbers and labels are the web's.
class MyKpiScreen extends StatefulWidget {
  const MyKpiScreen({super.key, this.month});
  final String? month;

  @override
  State<MyKpiScreen> createState() => _MyKpiScreenState();
}

class _MyKpiScreenState extends State<MyKpiScreen> {
  late String _month = widget.month ?? currentMonthValue();

  void _go(String month) => setState(() => _month = month);

  PageHeader _header(String label, {String? prev, String? next}) => PageHeader(
        title: 'My KPI',
        description: 'Scorecard for $label.',
        actions: monthNavButtons(
          onPrevious: () => _go(prev ?? shiftMonth(_month, -1)),
          onNext: () => _go(next ?? shiftMonth(_month, 1)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      // A new key per month so switching shows the loading state instead of
      // the previous month's numbers.
      key: ValueKey(_month),
      path: '/kpi',
      query: {'month': _month},
      header: _header(monthLabel(_month)),
      builder: (context, data, reload) {
        final p = Ts.of(context);
        final label = data.s('month.label');
        final summary = data.m('summary');
        final tasks = data.l('tasks');
        final overridden = summary.has('overrideScore');
        return [
          _header(label, prev: data.s('month.prevValue'), next: data.s('month.nextValue')),
          TsCard(
            tone: CardTone.primary,
            title: 'Effective Score',
            icon: LucideIcons.gauge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    ScoreRing(
                      score: summary.dN('effectiveScore'),
                      label: summary.s('effectiveLabel', '—'),
                      caption: label,
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Figure(
                            label: 'Computed Score',
                            value: summary.s('computedLabel', '—'),
                            note: overridden ? 'Overridden by HR - see below.' : null,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Divider(height: 1, color: p.foreground.withValues(alpha: 0.08)),
                          ),
                          _Figure(label: 'Points Assigned This Month', value: summary.s('totalAssignedWeight', '0')),
                        ],
                      ),
                    ),
                  ],
                ),
                if (tasks.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  TaskStatusBreakdown(statuses: [for (final t in tasks) t.s('status')]),
                ],
              ],
            ),
          ),
          if (overridden) _OverridePanel(label: label, score: summary.s('overrideLabel'), reason: summary.sn('overrideReason')),
          if (tasks.isEmpty) EmptyState('No tasks due in $label.', icon: LucideIcons.calendarDays),
          for (final t in tasks)
            MobileCard(
              onTap: () => context.push('/tasks/${t.s('id')}'),
              children: [
                MobileCardHeader(title: t.s('title'), action: TaskStatusBadge(t.s('status'))),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Weight', value: t.s('weight')),
                  MobileCardRow(label: 'Due', value: fmtDate(t.at('dueDate'))),
                  MobileCardRow(label: 'Earned', value: t.s('earnedLabel', '—')),
                ]),
              ],
            ),
        ];
      },
    );
  }
}

/// One labelled number inside the scorecard.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.note});
  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tx(12, weight: FontWeight.w600, color: p.muted)),
        const SizedBox(height: 2),
        Text(value, style: tx(22, weight: FontWeight.w800, color: p.foreground, tracking: kTight)),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(note!, style: tx(12, color: p.muted)),
          ),
      ],
    );
  }
}

class _OverridePanel extends StatelessWidget {
  const _OverridePanel({required this.label, required this.score, required this.reason});
  final String label;
  final String score;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return TsPanel(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: p.purpleLight, borderRadius: BorderRadius.circular(Ts.rXl)),
            child: Icon(LucideIcons.shieldCheck, size: 16, color: p.purple),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HR Override', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    style: tx(14, color: p.muted, height: 1.5),
                    children: [
                      TextSpan(text: 'Your score for $label was set to '),
                      TextSpan(text: score, style: tx(14, weight: FontWeight.w700, color: p.foreground, height: 1.5)),
                      TextSpan(text: ' by HR${reason != null ? ': "$reason"' : '.'}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// app/(app)/kpi/report/page.tsx - every employee's scorecard for a month
/// (HR only). Unlike the web's phone layout, the override controls are
/// available here too: Override/Edit opens the OverrideCell form in a sheet.
class KpiReportScreen extends StatefulWidget {
  const KpiReportScreen({super.key, this.month});
  final String? month;

  @override
  State<KpiReportScreen> createState() => _KpiReportScreenState();
}

class _KpiReportScreenState extends State<KpiReportScreen> {
  late String _month = widget.month ?? currentMonthValue();

  void _go(String month) => setState(() => _month = month);

  PageHeader _header(String label, {String? prev, String? next}) => PageHeader(
        title: 'KPI Report',
        description: "Every employee's scorecard for $label. HR/Admin can override a score below.",
        actions: monthNavButtons(
          onPrevious: () => _go(prev ?? shiftMonth(_month, -1)),
          onNext: () => _go(next ?? shiftMonth(_month, 1)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      key: ValueKey(_month),
      path: '/kpi/report',
      query: {'month': _month},
      header: _header(monthLabel(_month)),
      builder: (context, data, reload) {
        final rows = data.l('rows');
        final month = data.s('month.value', _month);
        return [
          _header(data.s('month.label'), prev: data.s('month.prevValue'), next: data.s('month.nextValue')),
          if (rows.isEmpty) const EmptyState('No employees yet.', icon: LucideIcons.users),
          for (final r in rows) _KpiReportCard(row: r, month: month, monthLabel: data.s('month.label')),
        ];
      },
    );
  }
}

class _KpiReportCard extends StatelessWidget {
  const _KpiReportCard({required this.row, required this.month, required this.monthLabel});
  final Json row;
  final String month;
  final String monthLabel;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final employeeId = row.s('employeeId');
    final hasOverride = row.has('overrideScore');
    final reason = row.sn('overrideReason');
    return MobileCard(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push('/employees/$employeeId'),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    row.s('name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tx(16, weight: FontWeight.w700, color: p.foreground, tracking: kTight),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(LucideIcons.chevronRight, size: 16, color: p.muted),
                const Spacer(),
                Text(row.s('effectiveLabel', '—'),
                    style: tx(16, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: ScoreBar(score: row.dN('effectiveScore')),
        ),
        MobileCardRows(rows: [
          MobileCardRow(label: 'Points Assigned', value: row.s('totalAssignedWeight', '0')),
          MobileCardRow(label: 'Computed', value: row.s('computedLabel', '—')),
          MobileCardRow(label: 'Effective', value: row.s('effectiveLabel', '—')),
          MobileCardRow(
            label: 'Override',
            child: hasOverride
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(row.s('overrideLabel'), style: tx(14, weight: FontWeight.w600, color: p.foreground)),
                      if (reason != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('"$reason"', textAlign: TextAlign.right, style: tx(12, color: p.muted)),
                        ),
                    ],
                  )
                : Text('—', style: tx(14, color: p.muted)),
          ),
        ]),
        MobileCardFooter(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              TsButton.secondary(
                label: hasOverride ? 'Edit' : 'Override',
                icon: LucideIcons.pencil,
                compact: true,
                onPressed: () => _OverrideSheet.show(
                  context,
                  employeeId: employeeId,
                  name: row.s('name'),
                  month: month,
                  monthLabel: monthLabel,
                  score: row.dN('overrideScore'),
                  reason: reason,
                ),
              ),
              if (hasOverride)
                ActionButton(
                  label: 'Clear',
                  variant: TsButtonVariant.danger,
                  compact: true,
                  followRedirects: false,
                  run: () => api.action('tasks.clearKpiOverride', args: [employeeId, month]),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The OverrideCell's edit mode: score + reason, Save / Cancel.
class _OverrideSheet extends StatefulWidget {
  const _OverrideSheet({
    required this.employeeId,
    required this.name,
    required this.month,
    required this.monthLabel,
    this.score,
    this.reason,
  });
  final String employeeId;
  final String name;
  final String month;
  final String monthLabel;
  final double? score;
  final String? reason;

  static Future<void> show(
    BuildContext context, {
    required String employeeId,
    required String name,
    required String month,
    required String monthLabel,
    double? score,
    String? reason,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => _OverrideSheet(
        employeeId: employeeId,
        name: name,
        month: month,
        monthLabel: monthLabel,
        score: score,
        reason: reason,
      ),
    );
  }

  @override
  State<_OverrideSheet> createState() => _OverrideSheetState();
}

class _OverrideSheetState extends State<_OverrideSheet> {
  late final _score = TextEditingController(text: _initialScore());
  late final _reason = TextEditingController(text: widget.reason ?? '');
  bool _pending = false;
  String? _error;

  String _initialScore() {
    final s = widget.score;
    if (s == null) return '';
    return s == s.roundToDouble() ? s.toInt().toString() : s.toString();
  }

  @override
  void dispose() {
    _score.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action(
        'tasks.setKpiOverride',
        args: [widget.employeeId, widget.month],
        fields: {'overrideScore': _score.text, 'reason': _reason.text},
      ),
      followRedirects: false,
    );
    if (!mounted) return;
    if (r.ok) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Gap(
          gap: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.name, style: tx(18, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
                const SizedBox(height: 2),
                Text(widget.monthLabel, style: tx(14, color: p.muted)),
              ],
            ),
            TsInput(
              controller: _score,
              placeholder: 'Score 0-100',
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            ),
            TsTextarea(controller: _reason, rows: 2, placeholder: 'Reason (required)'),
            if (_error != null) Text(_error!, style: tx(12, color: p.danger)),
            Row(
              children: [
                TsButton(label: 'Save', pendingLabel: 'Saving...', pending: _pending, onPressed: _save),
                const SizedBox(width: 8),
                TsButton.secondary(label: 'Cancel', onPressed: () => Navigator.of(context).pop()),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
