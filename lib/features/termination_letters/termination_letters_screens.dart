import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/termination-letters/page.tsx - the list, HR/Admin only (the
/// server 403s anyone else, surfaced via ApiScreen's own ErrorBlock).
class TerminationLettersScreen extends StatelessWidget {
  const TerminationLettersScreen({super.key});

  static const _header = PageHeader(title: 'Termination Letters');

  @override
  Widget build(BuildContext context) {
    final header = PageHeader(
      title: 'Termination Letters',
      actions: [
        TsButton(label: 'New', icon: LucideIcons.plus, onPressed: () => context.push('/termination-letters/new')),
      ],
    );
    return ApiScreen(
      path: '/termination-letters',
      header: _header,
      builder: (context, data, reload) {
        final letters = data.l('letters');
        return [
          header,
          if (letters.isEmpty) const EmptyState('No termination letters yet.', icon: LucideIcons.userMinus),
          for (final l in letters) _LetterCard(l),
        ];
      },
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard(this.l);
  final Json l;

  @override
  Widget build(BuildContext context) {
    final id = l.s('id');
    return MobileCard(
      onTap: () => context.push('/termination-letters/$id'),
      children: [
        MobileCardHeader(title: l.s('employeeName'), action: terminationStatusBadge(l.s('status'))),
        MobileCardRows(rows: [
          MobileCardRow(label: 'Designation', value: l.s('designation')),
          MobileCardRow(label: 'Memo No.', value: l.sn('memoNo') ?? '—'),
          MobileCardRow(label: 'Last Working Day', value: fmtDate(l.at('lastWorkingDay'))),
        ]),
      ],
    );
  }
}

/// app/(app)/termination-letters/[id]/page.tsx.
class TerminationLetterDetailScreen extends StatelessWidget {
  const TerminationLetterDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/termination-letters/$id',
      builder: (context, data, reload) {
        final letter = data.m('letter');
        final isDraft = data.b('isDraft');
        final memoPreview = data.s('memoPreview');
        final p = Ts.of(context);

        return [
          PageHeader(
            title: letter.s('employeeName'),
            description: '${letter.s('designation')} — ${isDraft ? 'Draft' : 'Issued'}',
            actions: [
              if (isDraft)
                TsButton.secondary(label: 'Edit', onPressed: () => context.push('/termination-letters/$id/edit')),
              TsButton.secondary(
                label: isDraft ? 'Preview PDF' : 'View PDF',
                onPressed: () => openTerminationFile(context, '/api/termination-letters/$id/pdf'),
              ),
              TsButton(
                label: 'Download PDF',
                onPressed: () => openTerminationFile(context, '/api/termination-letters/$id/pdf?download=1'),
              ),
            ],
          ),
          TsCard(
            child: DetailList(rows: [
              DetailRow(label: 'Employee', value: letter.s('employeeName')),
              DetailRow(label: 'Memo No.', value: letter.sn('memoNo') ?? '$memoPreview (pending issuance)'),
              DetailRow(
                label: 'Date',
                value: letter.has('issueDate') ? fmtDate(letter.at('issueDate')) : '(pending issuance)',
              ),
              DetailRow(label: 'Reason', value: letter.s('reasonLabel')),
              if (letter.sn('reasonDetails') != null) DetailRow(label: 'Reason Details', value: letter.s('reasonDetails')),
              DetailRow(label: 'Last Working Day', value: fmtDate(letter.at('lastWorkingDay'))),
              DetailRow(label: 'Notice Period', value: noticePeriodSummary(letter)),
              DetailRow(label: 'Settlement', value: settlementSummary(letter)),
              if (letter.sn('additionalRemarks') != null)
                DetailRow(label: 'Additional Remarks', value: letter.s('additionalRemarks'), last: true),
            ]),
          ),
          if (!isDraft)
            TsCard(
              title: 'Final Settlement Statement',
              child: Gap(
                gap: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Muted(
                    'A computed Full & Final statement (prorated salary, leave encashment, gratuity, pending '
                    'reimbursements, notice pay, and any manual adjustments) with an estimated TDS on the taxable '
                    'lump sum.',
                  ),
                  TsButton.secondary(
                    label: 'Open Final Settlement',
                    onPressed: () => context.push('/termination-letters/$id/settlement'),
                  ),
                ],
              ),
            ),
          if (isDraft)
            TsCard(
              title: 'Issue this Termination Letter',
              child: Gap(
                gap: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'This will assign memo no. '),
                        TextSpan(text: memoPreview, style: TextStyle(fontWeight: FontWeight.w700, color: p.foreground)),
                        const TextSpan(
                          text:
                              ", freeze the letter's data, generate the final PDF, and record the employee's Last "
                              "Working Day on their profile. This cannot be undone.",
                        ),
                      ],
                    ),
                    style: tx(14, color: p.muted, height: 1.5),
                  ),
                  ActionButton(
                    label: 'Issue Termination Letter',
                    pendingLabel: 'Issuing...',
                    run: () => api.action('termination.issueTerminationLetter', args: [id]),
                    onDone: (r) {
                      // "Letter issued, but PDF generation failed" is an error
                      // that still changed the letter - reload so the Retry
                      // section appears, as the web's revalidatePath does.
                      if (!r.ok && context.mounted) {
                        toast(context, r.error!, error: true);
                        refreshBus.bump();
                      }
                    },
                  ),
                ],
              ),
            ),
          if (!isDraft) _IssuanceRecord(id: id, letter: letter),
          if (isDraft)
            TsCard(
              title: 'Danger Zone',
              child: Gap(
                gap: 12,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Muted('This draft has not been issued yet - deleting it is permanent.'),
                  ActionButton(
                    label: 'Delete Draft',
                    pendingLabel: 'Deleting...',
                    variant: TsButtonVariant.danger,
                    confirm: 'Delete this termination letter draft? This cannot be undone.',
                    run: () => api.action('termination.deleteTerminationLetter', fields: {'id': id}),
                    onDone: (r) {
                      if (r.ok && context.mounted) context.go('/termination-letters');
                    },
                  ),
                ],
              ),
            ),
        ];
      },
    );
  }
}

class _IssuanceRecord extends StatelessWidget {
  const _IssuanceRecord({required this.id, required this.letter});
  final String id;
  final Json letter;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final hasPdf = letter.b('hasPdf');
    final viewToken = letter.sn('viewToken');
    return TsCard(
      title: 'Issuance Record',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailList(rows: [
            DetailRow(label: 'Issued By', value: letter.sn('issuedByName') ?? '—'),
            DetailRow(label: 'Issued At', value: letter.has('issuedAt') ? fmtDateTime(letter.at('issuedAt')) : '—'),
            DetailRow(label: 'Created By', value: letter.s('createdByName'), last: viewToken == null && hasPdf),
          ]),
          if (!hasPdf) ...[
            const SizedBox(height: 16),
            StatusMessage.error('PDF has not been generated successfully yet.'),
            const SizedBox(height: 8),
            ActionButton(
              label: 'Retry PDF Generation',
              pendingLabel: 'Retrying...',
              variant: TsButtonVariant.danger,
              run: () => api.action('termination.retryTerminationLetterPdf', args: [id]),
            ),
          ],
          if (viewToken != null) ...[
            const SizedBox(height: 16),
            Text("Employee's No-Login View Link", style: tx(14, weight: FontWeight.w600, color: p.foreground)),
            const SizedBox(height: 6),
            TsPanel(
              radius: Ts.rXl,
              child: Text(
                '/termination-letter/view/$viewToken',
                style: tx(12, color: p.muted),
              ),
            ),
            const SizedBox(height: 6),
            Muted('Sent automatically via WhatsApp on issuance (pending Meta\'s approval of the template).', size: 12),
          ],
        ],
      ),
    );
  }
}
