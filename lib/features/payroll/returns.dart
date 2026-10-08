import '../../widgets/ts.dart';
import 'widgets.dart';

const _hub = '/payroll/returns';

/// app/(app)/payroll/returns/page.tsx
class StatutoryReturnsScreen extends StatelessWidget {
  const StatutoryReturnsScreen({super.key});

  static PageHeader _header(BuildContext context) => PageHeader(
        title: 'Statutory Returns',
        description:
            'Track and generate the compliance files HR files with EPFO, ESIC, the state PT department, and the Income Tax Department. Generate each return from its own page below; this view tracks due dates and filing status across all of them.',
        actions: [
          for (final (href, label) in const [
            ('/payroll/returns/pf', 'PF (ECR)'),
            ('/payroll/returns/esi', 'ESI'),
            ('/payroll/returns/professional-tax', 'Professional Tax'),
            ('/payroll/returns/tds', 'TDS (24Q & Form 16)'),
          ])
            TsButton.secondary(label: label, compact: true, onPressed: () => context.push(href)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/payroll/returns',
      header: _header(context),
      builder: (context, data, reload) {
        final returns = data.l('returns');
        return [
          _header(context),
          if (returns.isEmpty) const EmptyState('No statutory returns generated yet.', icon: LucideIcons.scrollText),
          for (final r in returns)
            MobileCard(
              children: [
                MobileCardHeader(
                  title: '${r.s('typeLabel')} - ${r.s('period')}',
                  action: TsBadge(r.s('statusLabel'), tone: badgeToneFrom(r.s('statusTone'))),
                ),
                MobileCardRows(rows: [
                  if (r.sn('state') != null) MobileCardRow(label: 'State', value: r.s('state')),
                  MobileCardRow(label: 'Due Date', value: r.s('dueDate')),
                ]),
                if (r.b('generated'))
                  MobileCardFooter(
                    child: MarkFiledControl(
                      key: ValueKey('filed-${r.s('id')}-${r.b('filed')}'),
                      returnId: r.s('id'),
                      filed: r.b('filed'),
                      referenceNumber: r.sn('referenceNumber'),
                    ),
                  ),
              ],
            ),
        ];
      },
    );
  }
}

/// mark-filed-form.tsx: "Mark Filed" expands to the reference/notes form;
/// a filed row shows its reference and a "Clear" link instead.
class MarkFiledControl extends StatefulWidget {
  const MarkFiledControl({super.key, required this.returnId, required this.filed, this.referenceNumber});
  final String returnId;
  final bool filed;
  final String? referenceNumber;

  @override
  State<MarkFiledControl> createState() => _MarkFiledControlState();
}

class _MarkFiledControlState extends State<MarkFiledControl> {
  bool _open = false;
  bool _pending = false;
  String? _error;
  final _reference = TextEditingController();
  final _notes = TextEditingController();

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('payroll.markReturnFiled',
          args: [widget.returnId], fields: {'referenceNumber': _reference.text, 'notes': _notes.text}),
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
    final p = Ts.of(context);
    if (widget.filed) {
      return Row(
        children: [
          if (widget.referenceNumber != null)
            Expanded(child: Text('Ref: ${widget.referenceNumber}', style: tx(12, color: p.muted)))
          else
            const Spacer(),
          TsLink(
            'Clear',
            size: 12,
            color: p.muted,
            onTap: _pending
                ? null
                : () async {
                    setState(() => _pending = true);
                    await runAction(context, () => api.action('payroll.clearReturnFiled', args: [widget.returnId]),
                        followRedirects: false, toastErrors: true);
                    if (mounted) setState(() => _pending = false);
                  },
          ),
        ],
      );
    }
    if (!_open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TsLink('Mark Filed', size: 13, weight: FontWeight.w600, onTap: () => setState(() => _open = true)),
      );
    }
    return Gap(
      gap: 10,
      children: [
        TsInput(controller: _reference, label: 'Reference / Challan Number', placeholder: 'Optional'),
        TsInput(controller: _notes, label: 'Notes', placeholder: 'Optional'),
        if (_error != null) Text(_error!, style: tx(12, color: p.danger)),
        Row(
          children: [
            TsButton(label: 'Confirm Filed', pendingLabel: 'Saving...', pending: _pending, compact: true, onPressed: _confirm),
            const SizedBox(width: 8),
            TsButton.secondary(label: 'Cancel', compact: true, onPressed: () => setState(() => _open = false)),
          ],
        ),
      ],
    );
  }
}

/// The GET filter forms' "Month" picker + secondary "Go" button.
class _MonthGo extends StatefulWidget {
  const _MonthGo({required this.month, required this.onGo});
  final String month;
  final ValueChanged<String> onGo;

  @override
  State<_MonthGo> createState() => _MonthGoState();
}

class _MonthGoState extends State<_MonthGo> {
  late String _month = widget.month;

  @override
  void didUpdateWidget(covariant _MonthGo old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) _month = widget.month;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: TsMonthField(label: 'Month', value: _month, onChanged: (v) => setState(() => _month = v))),
        const SizedBox(width: 10),
        TsButton.secondary(label: 'Go', onPressed: () => widget.onGo(_month)),
      ],
    );
  }
}

/// The amber "no run yet" / "not locked" notices every generator page shows.
List<Widget> _runNotices(Json data) {
  final status = data.sn('runStatus');
  return [
    if (status == null)
      NoticeBox(
        text:
            'No payroll run exists for ${data.s('label')} yet. Process and lock it under Payroll Runs before generating this return.',
      ),
    if (status != null && status != 'LOCKED')
      NoticeBox(text: "This month's payroll run is ${status.toLowerCase()}, not locked. Lock it under Payroll Runs first."),
  ];
}

/// A muted paragraph with one tappable link in the middle (the pages'
/// "...under Settings → Statutory Returns - ..." footers).
class _LinkedText extends StatelessWidget {
  const _LinkedText({required this.before, required this.link, required this.href, this.after = ''});
  final String before;
  final String link;
  final String href;
  final String after;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (before.isNotEmpty) Text(before, style: tx(14, color: p.muted, height: 1.5)),
        TsLink(link, onTap: () => context.push(href)),
        if (after.isNotEmpty) Text(after, style: tx(14, color: p.muted, height: 1.5)),
      ],
    );
  }
}

/// app/(app)/payroll/returns/pf/page.tsx
class PfReturnScreen extends StatelessWidget {
  const PfReturnScreen({super.key, this.month});
  final String? month;

  static const _title = 'PF Return (ECR)';

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/payroll/returns/pf',
      query: {'month': month},
      header: const PageHeader(title: _title),
      builder: (context, data, reload) {
        final value = data.s('month');
        final missingUan = data.list<String>('missingUan');
        final missingDob = data.list<String>('missingDob');
        return [
          PageHeader(
            title: _title,
            description:
                "EPFO's Electronic Challan cum Return for ${data.s('label')}. Generates from this month's LOCKED payroll run - EPS/EDLI wage split computed per employee, pension contribution zeroed once a member turns 58.",
            actions: [
              ...monthNavButtons(
                context,
                back: _hub,
                prev: '/payroll/returns/pf?month=${data.s('prevMonth')}',
                next: '/payroll/returns/pf?month=${data.s('nextMonth')}',
              ),
              DownloadButton(
                key: ValueKey('pf-$value'),
                label: 'Generate & Download',
                path: '/api/payroll/returns/pf-ecr?month=$value',
                disabled: data.i('activeEpfCount') == 0,
              ),
            ],
          ),
          _MonthGo(month: value, onGo: (m) => context.replace('/payroll/returns/pf?month=$m')),
          ..._runNotices(data),
          if (data.i('activeEpfCount') == 0)
            const NoticeBox(
              text:
                  "No active employee has PF type set to EPF yet, so there's nothing to generate. Check the PF Type on each employee's Payroll Profile.",
            ),
          if (missingUan.isNotEmpty || missingDob.isNotEmpty)
            TsCard(
              title: "Data gaps (won't block generation, but check before filing)",
              icon: LucideIcons.triangleAlert,
              child: Gap(
                gap: 10,
                children: [
                  if (missingUan.isNotEmpty) _GapLine(badge: 'No UAN', text: missingUan.join(', ')),
                  if (missingDob.isNotEmpty)
                    _GapLine(badge: 'No Date of Birth', text: '${missingDob.join(', ')} - treated as under 58 for EPS.'),
                ],
              ),
            ),
          const _LinkedText(
            before: 'The ECR column delimiter is configurable under ',
            link: 'Settings → Statutory Returns',
            href: '/settings/statutory-returns',
            after:
                " - EPFO's exact format has shifted between sources, so verify the downloaded file against whatever EPFO's portal currently accepts before filing.",
          ),
        ];
      },
    );
  }
}

class _GapLine extends StatelessWidget {
  const _GapLine({required this.badge, required this.text});
  final String badge;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TsBadge(badge, tone: BadgeTone.amber),
        const SizedBox(height: 6),
        Muted(text),
      ],
    );
  }
}

/// app/(app)/payroll/returns/esi/page.tsx
class EsiReturnScreen extends StatelessWidget {
  const EsiReturnScreen({super.key, this.month});
  final String? month;

  static const _title = 'ESI Return';

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/payroll/returns/esi',
      query: {'month': month},
      header: const PageHeader(title: _title),
      builder: (context, data, reload) {
        final value = data.s('month');
        final missing = data.list<String>('missingEsiNumber');
        return [
          PageHeader(
            title: _title,
            description:
                "ESIC's monthly contribution file for ${data.s('label')}. Generates from this month's LOCKED payroll run - only employees flagged ESI-applicable with an ESI number on file are included.",
            actions: [
              ...monthNavButtons(
                context,
                back: _hub,
                prev: '/payroll/returns/esi?month=${data.s('prevMonth')}',
                next: '/payroll/returns/esi?month=${data.s('nextMonth')}',
              ),
              DownloadButton(
                key: ValueKey('esi-$value'),
                label: 'Generate & Download',
                path: '/api/payroll/returns/esi?month=$value',
                disabled: data.i('activeEsiCount') == 0,
              ),
            ],
          ),
          _MonthGo(month: value, onGo: (m) => context.replace('/payroll/returns/esi?month=$m')),
          ..._runNotices(data),
          if (data.i('activeEsiCount') == 0)
            const NoticeBox(
              text:
                  "No active employee is flagged ESI-applicable yet, so there's nothing to generate. Mark the relevant employees ESI-applicable on their Payroll Profile first.",
            ),
          if (missing.isNotEmpty)
            TsCard(
              title: 'Data gap (excluded from the file below)',
              icon: LucideIcons.triangleAlert,
              child: _GapLine(badge: 'No ESI Number', text: missing.join(', ')),
            ),
        ];
      },
    );
  }
}

/// app/(app)/payroll/returns/professional-tax/page.tsx
class PtReturnScreen extends StatefulWidget {
  const PtReturnScreen({super.key, this.month, this.state, this.templateId});
  final String? month;
  final String? state;
  final String? templateId;

  @override
  State<PtReturnScreen> createState() => _PtReturnScreenState();
}

class _PtReturnScreenState extends State<PtReturnScreen> {
  String? _month;
  String? _state;
  String? _templateId;

  static const _title = 'Professional Tax Return';

  String _href(String month, String? state, String? templateId) =>
      '/payroll/returns/professional-tax?month=$month&state=${Uri.encodeQueryComponent(state ?? '')}&templateId=${templateId ?? ''}';

  @override
  void didUpdateWidget(covariant PtReturnScreen old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month || old.state != widget.state || old.templateId != widget.templateId) {
      _month = null;
      _state = null;
      _templateId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/payroll/returns/professional-tax',
      query: {'month': widget.month, 'state': widget.state, 'templateId': widget.templateId},
      header: const PageHeader(title: _title),
      builder: (context, data, reload) {
        final p = Ts.of(context);
        final value = data.s('month');
        final selectedState = data.sn('selectedState');
        final selectedTemplate = data.sn('selectedTemplateId');
        final templates = data.l('templates');
        final downloadUrl = data.sn('downloadUrl');

        final draftState = _state ?? selectedState;
        final forState = templates.where((t) => t.s('state') == draftState).toList();
        final draftTemplate = forState.any((t) => t.s('id') == (_templateId ?? selectedTemplate))
            ? (_templateId ?? selectedTemplate)
            : (forState.isEmpty ? null : forState.first.s('id'));

        return [
          PageHeader(
            title: _title,
            description:
                'State-specific Professional Tax return for ${data.s('label')}. No national standard exists, so define a return file template per state under Settings first.',
            actions: [
              ...monthNavButtons(
                context,
                back: _hub,
                prev: _href(data.s('prevMonth'), selectedState, selectedTemplate),
                next: _href(data.s('nextMonth'), selectedState, selectedTemplate),
              ),
              if (downloadUrl != null)
                DownloadButton(key: ValueKey(downloadUrl), label: 'Generate & Download', path: downloadUrl),
            ],
          ),
          if (!data.b('hasTemplates'))
            NoticeBox(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('No Professional Tax return file templates defined yet. ', style: tx(14, color: p.dark ? p.warning : p.foreground)),
                  TsLink('Create one', weight: FontWeight.w700, onTap: () => context.push('/settings/return-templates')),
                  Text(' for each state you need to file in.', style: tx(14, color: p.dark ? p.warning : p.foreground)),
                ],
              ),
            )
          else
            TsCard(
              child: Gap(
                gap: 14,
                children: [
                  TsMonthField(label: 'Month', value: _month ?? value, onChanged: (v) => setState(() => _month = v)),
                  TsSelect<String>(
                    label: 'State',
                    value: draftState,
                    options: [for (final s in data.list<String>('states')) SelectOption(s, s)],
                    onChanged: (v) => setState(() {
                      _state = v;
                      _templateId = null;
                    }),
                  ),
                  TsSelect<String>(
                    label: 'Template',
                    value: draftTemplate,
                    options: [for (final t in forState) SelectOption(t.s('id'), t.s('name'))],
                    onChanged: (v) => setState(() => _templateId = v),
                  ),
                  TsButton.secondary(
                    label: 'Go',
                    expand: true,
                    onPressed: () => context.replace(_href(_month ?? value, draftState, draftTemplate)),
                  ),
                ],
              ),
            ),
          ..._runNotices(data),
          const Muted(
            "Employees with no work state on file are silently excluded from every state's Professional Tax calculation today - check each employee's Payroll Profile if a return looks short a few names.",
          ),
        ];
      },
    );
  }
}

/// app/(app)/payroll/returns/tds/page.tsx
class TdsReturnScreen extends StatefulWidget {
  const TdsReturnScreen({super.key, this.period, this.fy});
  final String? period;
  final String? fy;

  @override
  State<TdsReturnScreen> createState() => _TdsReturnScreenState();
}

class _TdsReturnScreenState extends State<TdsReturnScreen> {
  String? _period;
  String? _fy;

  static const _header = PageHeader(
    title: 'TDS (Form 24Q)',
    description:
        "Quarterly deductee-wise working data for import into NSDL's RPU, and per-employee Form 16 TDS summaries. The byte-exact FVU-ready text file is not generated here yet - this working data and RPU are the path to that today.",
  );

  @override
  void didUpdateWidget(covariant TdsReturnScreen old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period || old.fy != widget.fy) {
      _period = null;
      _fy = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/payroll/returns/tds',
      query: {'period': widget.period, 'fy': widget.fy},
      header: _header,
      builder: (context, data, reload) {
        final p = Ts.of(context);
        final period = data.s('period');
        final fy = data.s('fy');
        final employees = data.l('employees');
        return [
          PageHeader(
            title: _header.title,
            description: _header.description,
            actions: [TsButton.secondary(label: 'Back to Statutory Returns', onPressed: () => followRedirect(context, _hub))],
          ),
          Block(
            title: 'Quarterly Working Data (Form 24Q)',
            uppercase: true,
            child: Gap(
              gap: 12,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TsSelect<String>(
                        label: 'Quarter',
                        value: _period ?? period,
                        options: [for (final q in data.list<String>('quarterOptions')) SelectOption(q, q)],
                        onChanged: (v) => setState(() => _period = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TsButton.secondary(
                      label: 'Go',
                      onPressed: () => context.replace('/payroll/returns/tds?period=${_period ?? period}&fy=$fy'),
                    ),
                  ],
                ),
                if (data.b('allLocked'))
                  DownloadButton(
                    key: ValueKey('24q-$period'),
                    label: 'Download Working Data',
                    path: '/api/payroll/returns/form24q?period=$period',
                  )
                else
                  Text(
                    "Every month in $period (${data.list<String>('months').join(', ')}) must have a LOCKED payroll run before this quarter's working data can be generated.",
                    style: tx(14, color: p.warning, height: 1.5),
                  ),
              ],
            ),
          ),
          Block(
            title: 'Form 16 (Per Employee)',
            uppercase: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TsSelect<String>(
                    label: 'Financial Year',
                    value: _fy ?? fy,
                    options: [for (final y in data.list<String>('fyOptions')) SelectOption(y, y)],
                    onChanged: (v) => setState(() => _fy = v),
                  ),
                ),
                const SizedBox(width: 10),
                TsButton.secondary(
                  label: 'Go',
                  onPressed: () => context.replace('/payroll/returns/tds?period=$period&fy=${_fy ?? fy}'),
                ),
              ],
            ),
          ),
          if (employees.isEmpty) const EmptyState('No active employees.', icon: LucideIcons.users),
          for (final e in employees)
            MobileCard(
              children: [
                MobileCardHeader(
                  title: e.s('name'),
                  subtitle: e.sn('designation'),
                  action: DownloadButton(
                    key: ValueKey('f16-${e.s('id')}-$fy'),
                    label: 'Download',
                    link: true,
                    path: '/api/payroll/returns/form16/${e.s('id')}?fy=$fy',
                  ),
                ),
              ],
            ),
          const _LinkedText(
            before: 'Statutory return settings (due-day defaults) live under ',
            link: 'Settings → Statutory Returns',
            href: '/settings/statutory-returns',
            after: '.',
          ),
        ];
      },
    );
  }
}
