import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/termination-letters/[id]/settlement/page.tsx. 404s (via
/// ApiScreen's own ErrorBlock) until the letter is ISSUED.
class SettlementScreen extends StatelessWidget {
  const SettlementScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/termination-letters/$id/settlement',
      builder: (context, data, reload) {
        final settlement = data.mN('settlement');
        final hasExisting = data.b('hasExisting');
        final taxWarnings = settlement?.list<String>('taxWarnings') ?? const [];
        final adjustments = settlement?.l('otherAdjustments') ?? const [];

        return [
          PageHeader(
            title: 'Final Settlement — ${data.s('employeeName')}',
            description:
                'A computed Full & Final statement. Auto-computed lines (prorated salary, leave encashment, '
                'gratuity, pending reimbursements, notice pay) are derived fresh each time you Generate/Regenerate.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TsLink('← Back to Termination Letter', onTap: () => context.pop()),
          ),
          TsCard(
            title: 'Generate',
            child: ActionButton(
              label: hasExisting ? 'Regenerate Auto-Computed Lines' : 'Generate Final Settlement',
              pendingLabel: 'Computing...',
              variant: hasExisting ? TsButtonVariant.secondary : TsButtonVariant.primary,
              run: () => api.action('termination.generateFinalSettlement', args: [id]),
            ),
          ),
          if (settlement != null) ...[
            TsCard(
              title: 'Computed Breakdown',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettlementLineRow(
                    'Prorated Salary',
                    '${rupee(settlement.at('proratedSalaryAmount'))} (${settlement.i('proratedSalaryDays')} day(s))',
                  ),
                  SettlementLineRow(
                    'Leave Encashment',
                    settlement.i('leaveEncashmentGross') > 0
                        ? '${rupee(settlement.at('leaveEncashmentGross'))} gross '
                            '(${settlement.d('leaveEncashmentDays')} day(s)) — '
                            '${rupee(settlement.at('leaveEncashmentExempt'))} exempt, '
                            '${rupee(settlement.at('leaveEncashmentTaxable'))} taxable'
                        : '—',
                  ),
                  SettlementLineRow(
                    'Gratuity',
                    settlement.b('gratuityEligible')
                        ? '${rupee(settlement.at('gratuityGross'))} gross '
                            '(${settlement.d('yearsOfService')} years of service) — '
                            '${rupee(settlement.at('gratuityExempt'))} exempt, '
                            '${rupee(settlement.at('gratuityTaxable'))} taxable'
                        : 'Not eligible — ${settlement.d('yearsOfService')} years served, 5 years required',
                  ),
                  SettlementLineRow('Notice Pay (in lieu)', rupee(settlement.at('noticePayAmount'))),
                  SettlementLineRow('Pending Reimbursement', rupee(settlement.at('pendingReimbursement'))),
                  if (adjustments.isNotEmpty)
                    SettlementLineRow(
                      'Other Adjustments',
                      adjustments.map((a) => '${a.s('label')}: ${rupee(a.at('amount'))}').join(', '),
                    ),
                  SettlementLineRow('Gross Total', rupee(settlement.at('grossTotal')), strong: true),
                  SettlementLineRow('Estimated TDS', rupee(settlement.at('estimatedTds'))),
                  SettlementLineRow('Net Payable', rupee(settlement.at('netPayable')), strong: true, last: true),
                ],
              ),
            ),
            if (taxWarnings.isNotEmpty)
              StatusMessage(
                'Consultant Review Needed:\n${taxWarnings.map((w) => '- $w').join('\n')}',
                kind: StatusKind.warning,
                boxed: true,
              ),
            Row(
              children: [
                Expanded(
                  child: TsButton.secondary(
                    label: 'View PDF',
                    onPressed: () => openTerminationFile(context, '/api/termination-letters/$id/settlement/pdf'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TsButton.secondary(
                    label: 'Download PDF',
                    onPressed: () =>
                        openTerminationFile(context, '/api/termination-letters/$id/settlement/pdf?download=1'),
                  ),
                ),
              ],
            ),
          ],
        ];
      },
    );
  }
}
