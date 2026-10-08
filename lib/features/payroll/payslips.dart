import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/payroll/payslips/page.tsx
class MyPayslipsScreen extends StatelessWidget {
  const MyPayslipsScreen({super.key});

  static const _header = PageHeader(title: 'My Payslips', description: 'Every processed payslip for your own record.');

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/payroll/payslips',
      header: _header,
      builder: (context, data, reload) {
        final payslips = data.l('payslips');
        return [
          _header,
          if (payslips.isEmpty) const EmptyState('No payslips yet.', icon: LucideIcons.receipt),
          for (final p in payslips)
            MobileCard(
              onTap: () => context.push('/payroll/payslips/${p.s('id')}'),
              children: [
                MobileCardHeader(
                  title: p.s('month'),
                  subtitle: monthLabel(p.s('month')),
                  action: Icon(LucideIcons.chevronRight, size: 18, color: Ts.of(context).muted),
                ),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Gross', value: inr(p.at('gross'))),
                  MobileCardRow(label: 'Net Pay', value: inr(p.at('netPay'))),
                ]),
              ],
            ),
        ];
      },
    );
  }
}

/// app/(app)/payroll/payslips/[id]/page.tsx
class PayslipScreen extends StatelessWidget {
  const PayslipScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final pdf = '/api/payroll/payslips/$id/pdf?download=1';
    return ApiScreen(
      path: '/payroll/payslips/$id',
      header: const PageHeader(title: 'Payslip'),
      builder: (context, d, reload) {
        final warnings = d.list<String>('warnings');
        final days = d.d('attendanceDeductionDays');
        final daysText = numText(days);
        return [
          PageHeader(
            title: 'Payslip — ${d.s('month')}',
            description: d.s('employeeName'),
            actions: [
              TsButton.secondary(
                label: 'Download PDF',
                icon: LucideIcons.download,
                onPressed: () => openPayrollFile(context, pdf),
              ),
            ],
          ),
          _NetPayHero(data: d),
          if (warnings.isNotEmpty) NoticeBox(title: 'Consultant Review Needed', bullets: warnings),
          LineSection(
            title: 'Earnings',
            icon: LucideIcons.trendingUp,
            rows: [
              LineRow('Basic', inr(d.at('basic'))),
              LineRow('Dearness Allowance', inr(d.at('da'))),
              LineRow('HRA', inr(d.at('hra'))),
              LineRow('Special / Other Allowance', inr(d.at('specialAllowance'))),
              if (d.i('encashmentAmount') > 0) LineRow('Earned Leave Encashment', inr(d.at('encashmentAmount'))),
              LineRow('Total Earnings', inr(d.at('totalEarnings')), strong: true),
            ],
          ),
          LineSection(
            title: 'Deductions',
            icon: LucideIcons.trendingDown,
            rows: [
              if (d.i('attendanceDeductionAmount') > 0)
                LineRow('Loss of Pay ($daysText day${days == 1 ? '' : 's'})', inr(d.at('attendanceDeductionAmount'))),
              LineRow('Provident Fund', inr(d.at('pfEmployeeAmount'))),
              if (d.i('esiEmployeeAmount') > 0) LineRow('ESI', inr(d.at('esiEmployeeAmount'))),
              if (d.i('professionalTax') > 0) LineRow('Professional Tax', inr(d.at('professionalTax'))),
              LineRow('Income Tax (TDS)', inr(d.at('tdsAmount'))),
              LineRow('Total Deductions', inr(d.at('totalDeductions')), strong: true),
            ],
          ),
          LineSection(
            title: 'Net Pay',
            highlight: true,
            rows: [LineRow('Total Earnings − Total Deductions', inr(d.at('netPay')), strong: true)],
          ),
          if (d.i('gratuityContribution') > 0)
            LineSection(
              title: 'Gratuity — CTC Accrual (Informational)',
              icon: LucideIcons.piggyBank,
              rows: [LineRow("This Month's Accrual", inr(d.at('gratuityContribution')))],
              footer:
                  'Bookkeeping allocation only, not the statutory entitlement payable at separation. Never deducted from net pay.',
            ),
          if (d.b('isHr'))
            LineSection(
              title: 'Employer Contributions (not part of net pay)',
              icon: LucideIcons.building2,
              rows: [
                LineRow('Employer PF', inr(d.at('pfEmployerAmount'))),
                if (d.i('esiEmployerAmount') > 0) LineRow('Employer ESI', inr(d.at('esiEmployerAmount'))),
              ],
            ),
        ];
      },
    );
  }
}

/// Top-of-payslip summary: the month, net pay large, and the earnings /
/// deductions totals the sections below break down.
class _NetPayHero extends StatelessWidget {
  const _NetPayHero({required this.data});
  final Json data;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final fg = p.primaryForeground;
    Widget figure(String label, String value) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(Ts.r2xl),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tx(12, color: fg.withValues(alpha: 0.8))),
                const SizedBox(height: 2),
                Text(value, style: tx(16, weight: FontWeight.w700, color: fg, tracking: kTight)),
              ],
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: p.gradientPrimary,
        borderRadius: BorderRadius.circular(Ts.r3xl),
        boxShadow: p.shadowButton,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.wallet, size: 16, color: fg.withValues(alpha: 0.85)),
              const SizedBox(width: 8),
              Text(monthLabel(data.s('month')), style: tx(13, weight: FontWeight.w600, color: fg.withValues(alpha: 0.85))),
            ],
          ),
          const SizedBox(height: 14),
          Text('Net Pay', style: tx(13, color: fg.withValues(alpha: 0.8))),
          const SizedBox(height: 2),
          Text(inr(data.at('netPay')), style: tx(34, weight: FontWeight.w800, color: fg, tracking: -0.02)),
          const SizedBox(height: 16),
          Row(
            children: [
              figure('Total Earnings', inr(data.at('totalEarnings'))),
              const SizedBox(width: 10),
              figure('Total Deductions', inr(data.at('totalDeductions'))),
            ],
          ),
        ],
      ),
    );
  }
}
