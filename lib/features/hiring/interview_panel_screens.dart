import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/interview-panel/page.tsx - any role's blind-scoring inbox.
class InterviewPanelScreen extends StatelessWidget {
  const InterviewPanelScreen({super.key});

  static const _description =
      "Interviews you've been assigned to score. Your score is blind - other panelists never see it.";

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/interview-panel',
      header: const PageHeader(title: 'Interview Panel', description: _description),
      builder: (context, data, reload) {
        if (!data.b('hasEmployee')) {
          return const [
            PageHeader(title: 'Interview Panel', description: "Interviews you've been assigned to score."),
            TsCard(child: Muted('No employee record is linked to your account.')),
          ];
        }
        final pending = data.l('pending');
        final submitted = data.l('submitted');
        return [
          const PageHeader(title: 'Interview Panel', description: _description),
          TsCard(
            title: 'Pending (${pending.length})',
            child: pending.isEmpty
                ? const Muted('Nothing waiting on your score right now.')
                : Gap(gap: 12, children: [for (final a in pending) _AssignmentRow(a)]),
          ),
          if (submitted.isNotEmpty)
            TsCard(
              title: 'Submitted',
              child: Gap(gap: 12, children: [for (final a in submitted) _AssignmentRow(a)]),
            ),
        ];
      },
    );
  }
}

class _AssignmentRow extends StatelessWidget {
  const _AssignmentRow(this.a);
  final Json a;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final line = '${a.s('jobTitle')} · ${a.s('nature')}'
        '${a.has('scheduledAt') ? ' · ${fmtDateTime(a.at('scheduledAt'))}' : ''}'
        '${a.sn('scheduledVenue') != null ? ' · ${a.s('scheduledVenue')}' : ''}';
    return TsPanel(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push('/interview-panel/${a.s('id')}'),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [StrongText(a.s('candidateName')), MutedLine(line)],
            ),
          ),
          const SizedBox(width: 12),
          Text(a.b('submitted') ? 'View' : 'Score', style: tx(14, weight: FontWeight.w600, color: p.primary)),
          Icon(LucideIcons.chevronRight, size: 16, color: p.primary),
        ],
      ),
    );
  }
}

/// app/(app)/interview-panel/[panelScoreId]/page.tsx.
class PanelScoreScreen extends StatelessWidget {
  const PanelScoreScreen({super.key, required this.panelScoreId});
  final String panelScoreId;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/interview-panel/$panelScoreId',
      builder: (context, data, reload) {
        final p = Ts.of(context);
        final finalized = data.b('finalized');
        return [
          PageHeader(title: data.s('candidateName'), description: '${data.s('jobTitle')} · ${data.s('nature')} Interview'),
          TsCard(
            title: 'Interview Details',
            child: DetailList(rows: [
              if (data.has('scheduledAt')) DetailRow(label: 'When', value: fmtDateTime(data.at('scheduledAt'))),
              if (data.sn('scheduledVenue') != null) DetailRow(label: 'Where', value: data.s('scheduledVenue')),
            ]),
          ),
          TsCard(
            title: 'Your Score',
            child: finalized
                ? Gap(
                    gap: 8,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Muted('This interview has been finalized - your score can no longer be changed.'),
                      if (data.has('score')) ...[
                        Text.rich(
                          TextSpan(children: [
                            const TextSpan(text: 'Your score:', style: TextStyle(fontWeight: FontWeight.w600)),
                            TextSpan(text: ' ${data.s('score')}/10'),
                          ]),
                          style: tx(14, color: p.foreground),
                        ),
                        if (data.sn('remarks') != null) Text(data.s('remarks'), style: tx(14, color: p.foreground)),
                      ] else
                        Text('You did not submit a score before this was finalized.', style: tx(14, color: p.foreground)),
                    ],
                  )
                : _ScoreForm(
                    panelScoreId: panelScoreId,
                    initialScore: data.iN('score'),
                    initialRemarks: data.s('remarks'),
                  ),
          ),
        ];
      },
    );
  }
}

/// score-form.tsx.
class _ScoreForm extends StatefulWidget {
  const _ScoreForm({required this.panelScoreId, required this.initialScore, required this.initialRemarks});
  final String panelScoreId;
  final int? initialScore;
  final String initialRemarks;

  @override
  State<_ScoreForm> createState() => _ScoreFormState();
}

class _ScoreFormState extends State<_ScoreForm> {
  late final _score = TextEditingController(text: widget.initialScore?.toString() ?? '');
  late final _remarks = TextEditingController(text: widget.initialRemarks);
  bool _pending = false;
  String? _error;
  bool _success = false;

  @override
  void dispose() {
    _score.dispose();
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _pending = true;
      _error = null;
      _success = false;
    });
    final r = await runAction(
      context,
      () => api.action('hiring.submitPanelistScore',
          args: [widget.panelScoreId], fields: {'score': _score.text, 'remarks': _remarks.text}),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
      _success = r.ok;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Gap(
      gap: 16,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TsInput(
          controller: _score,
          label: 'Score (1-10)',
          hint: 'Your score is never shown to other panelists.',
          keyboardType: TextInputType.number,
          inputFormatters: TsInput.digitsOnly,
          maxLength: 2,
        ),
        TsTextarea(controller: _remarks, label: 'Remarks (optional)', rows: 4),
        if (_error != null) StatusMessage.error(_error),
        if (_success) StatusMessage.success('Score submitted. You can still edit it until this interview is finalized.'),
        TsButton(
          label: widget.initialScore != null ? 'Update Score' : 'Submit Score',
          pendingLabel: 'Submitting...',
          pending: _pending,
          onPressed: _submit,
        ),
      ],
    );
  }
}
