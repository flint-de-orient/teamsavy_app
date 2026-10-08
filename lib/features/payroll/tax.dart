import '../../widgets/ts.dart';
import 'widgets.dart';

/// app/(app)/payroll/tax-declarations/page.tsx
class TaxDeclarationsScreen extends StatelessWidget {
  const TaxDeclarationsScreen({super.key});

  static String _description(String fy) =>
      'Declare your deductions and choose your Income Tax Regime for FY $fy - this determines the TDS deducted from your salary each month.';

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/payroll/tax-declarations',
      header: const PageHeader(title: 'Tax Declarations'),
      builder: (context, data, reload) {
        final fy = data.s('financialYear');
        final c = data.m('confirmed');
        return [
          PageHeader(title: 'Tax Declarations', description: _description(fy)),
          if (data.b('alreadyConfirmed'))
            TsCard(
              title: 'Confirmed for FY $fy',
              icon: LucideIcons.badgeCheck,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LineRow('Regime', c.s('taxRegime') == 'OLD' ? 'Old' : 'New'),
                  LineRow('Confirmed on', fmtDateTime(c.at('taxRegimeSelectedAt')), last: c.s('taxRegime') != 'OLD'),
                  if (c.s('taxRegime') == 'OLD') ...[
                    LineRow('Rent Paid / Month', c.at('rentPaidPerMonth') == null ? '—' : rupee(c.at('rentPaidPerMonth'))),
                    LineRow('Section 80C Declared', rupee(c.at('section80CDeclared'))),
                    LineRow('Section 80D Declared', rupee(c.at('section80DDeclared'))),
                    LineRow('Home Loan Interest Declared', rupee(c.at('homeLoanInterestDeclared')), last: true),
                  ],
                  const SizedBox(height: 12),
                  Muted('This is locked for FY $fy - contact HR if you need to change it.', size: 12),
                ],
              ),
            )
          else
            TaxDeclarationsForm(key: ValueKey('tax-form-$fy'), financialYear: fy, defaults: data.m('defaults')),
        ];
      },
    );
  }
}

/// tax-declarations-form.tsx
class TaxDeclarationsForm extends StatefulWidget {
  const TaxDeclarationsForm({super.key, required this.financialYear, required this.defaults});
  final String financialYear;
  final Json defaults;

  @override
  State<TaxDeclarationsForm> createState() => _TaxDeclarationsFormState();
}

class _TaxDeclarationsFormState extends State<TaxDeclarationsForm> {
  late String _regime = widget.defaults.s('taxRegime', 'NEW');
  late String _cityType = widget.defaults.s('cityType', 'NON_METRO');
  late final _rent = TextEditingController(text: widget.defaults.sn('rentPaidPerMonth') ?? '');
  late final _c80 = TextEditingController(text: widget.defaults.s('section80CDeclared', '0'));
  late final _d80 = TextEditingController(text: widget.defaults.s('section80DDeclared', '0'));
  late final _homeLoan = TextEditingController(text: widget.defaults.s('homeLoanInterestDeclared', '0'));

  bool _comparing = false;
  Json? _comparison;
  String? _compareError;
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _rent.dispose();
    _c80.dispose();
    _d80.dispose();
    _homeLoan.dispose();
    super.dispose();
  }

  num _n(TextEditingController c) => num.tryParse(c.text.trim()) ?? 0;

  Future<void> _compare() async {
    setState(() {
      _comparing = true;
      _compareError = null;
    });
    try {
      final json = await api.post('/payroll/tax-comparison', {
        'cityType': _cityType,
        'rentPaidPerMonth': _rent.text.trim().isEmpty ? null : num.tryParse(_rent.text.trim()),
        'section80CDeclared': _n(_c80),
        'section80DDeclared': _n(_d80),
        'homeLoanInterestDeclared': _n(_homeLoan),
      });
      if (!mounted) return;
      setState(() => _comparison = json);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _comparison = null;
        _compareError = e.code == 'network' || e.code == 'timeout'
            ? "Couldn't reach the server. Please try again."
            : (e.status == 0 ? "Couldn't compute the comparison." : e.message);
      });
    } finally {
      if (mounted) setState(() => _comparing = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      () => api.action('payroll.saveTaxDeclarations', fields: {
        'taxRegime': _regime,
        'cityType': _cityType,
        'rentPaidPerMonth': _rent.text.trim(),
        'section80CDeclared': _c80.text.trim(),
        'section80DDeclared': _d80.text.trim(),
        'homeLoanInterestDeclared': _homeLoan.text.trim(),
      }),
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
    final fy = widget.financialYear;
    final cmp = _comparison;
    final oldTax = cmp?.d('old.annualTaxPayable') ?? 0;
    final newTax = cmp?.d('new.annualTaxPayable') ?? 0;
    return Gap(
      gap: 16,
      children: [
        TsCard(
          title: 'Deductions (Old Regime only)',
          icon: LucideIcons.receipt,
          child: Gap(
            gap: 14,
            children: [
              const Muted(
                "These only reduce your tax under the Old Regime - the New Regime doesn't allow them, but filling them in still lets you compare both accurately.",
                size: 12,
              ),
              TsSelect<String>(
                label: 'City Type',
                value: _cityType,
                options: const [SelectOption('NON_METRO', 'Non-Metro'), SelectOption('METRO', 'Metro')],
                onChanged: (v) => setState(() => _cityType = v ?? 'NON_METRO'),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TsInput(controller: _rent, label: 'Rent Paid per Month (₹)', keyboardType: TextInputType.number, inputFormatters: TsInput.digitsOnly),
                  const InfoDisclosure(
                    summary: 'What counts for HRA exemption?',
                    text:
                        "Rent you actually pay for the home you live in (not one you own). Leave blank if you live in your own home or don't pay rent.",
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TsInput(controller: _c80, label: 'Section 80C Declared (₹)', keyboardType: TextInputType.number, inputFormatters: TsInput.digitsOnly),
                  const InfoDisclosure(
                    summary: 'What counts under 80C?',
                    text:
                        "EPF/VPF, PPF, ELSS mutual funds, LIC/life insurance premiums, home loan principal repayment, 5-year tax-saving FDs, NSC, Sukanya Samriddhi, children's tuition fees (up to 2 children). Your own PF contribution is added automatically - you don't need to include it here.",
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TsInput(controller: _d80, label: 'Section 80D Declared (₹)', keyboardType: TextInputType.number, inputFormatters: TsInput.digitsOnly),
                  const InfoDisclosure(
                    summary: 'What counts under 80D?',
                    text: 'Health insurance premiums for yourself, your spouse, children, or parents.',
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TsInput(
                    controller: _homeLoan,
                    label: 'Home Loan Interest Declared (₹)',
                    keyboardType: TextInputType.number,
                    inputFormatters: TsInput.digitsOnly,
                  ),
                  const InfoDisclosure(
                    summary: 'What counts here?',
                    text: 'Interest paid on a home loan for a self-occupied property (Section 24(b)).',
                  ),
                ],
              ),
            ],
          ),
        ),
        TsCard(
          title: 'Compare Both Regimes',
          icon: LucideIcons.scale,
          action: TsButton.secondary(
            label: 'Compare Regimes',
            pendingLabel: 'Comparing...',
            pending: _comparing,
            compact: true,
            onPressed: _compare,
          ),
          child: Gap(
            gap: 12,
            children: [
              if (_compareError != null) StatusMessage.error(_compareError),
              if (cmp != null) ...[
                Row(
                  children: [
                    Expanded(child: _TaxTile(label: 'Old Regime — Annual Tax', value: inr(oldTax), best: oldTax < newTax)),
                    const SizedBox(width: 12),
                    Expanded(child: _TaxTile(label: 'New Regime — Annual Tax', value: inr(newTax), best: newTax < oldTax)),
                  ],
                ),
                Text(
                  oldTax == newTax
                      ? 'Both regimes come out the same for you.'
                      : "${oldTax < newTax ? 'Old' : 'New'} Regime saves you ${inr((oldTax - newTax).abs())} a year based on what you've entered.",
                  style: tx(12, color: p.muted, height: 1.5),
                ),
              ],
            ],
          ),
        ),
        TsCard(
          title: 'Choose Your Regime for FY $fy',
          icon: LucideIcons.listChecks,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 16,
                children: [
                  RadioRow(label: 'Old Regime', value: 'OLD', group: _regime, onChanged: (v) => setState(() => _regime = v)),
                  RadioRow(label: 'New Regime', value: 'NEW', group: _regime, onChanged: (v) => setState(() => _regime = v)),
                ],
              ),
              const SizedBox(height: 6),
              Text('This is locked for FY $fy once saved - only HR can change it after that.',
                  style: tx(12, color: p.warning, height: 1.5)),
            ],
          ),
        ),
        if (_error != null) StatusMessage.error(_error),
        TsButton(
          label: 'Save & Confirm Regime',
          pendingLabel: 'Saving...',
          pending: _pending,
          expand: true,
          onPressed: _save,
        ),
      ],
    );
  }
}

class _TaxTile extends StatelessWidget {
  const _TaxTile({required this.label, required this.value, required this.best});
  final String label;
  final String value;
  final bool best;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: best ? p.successLight : p.surface,
        borderRadius: BorderRadius.circular(Ts.rXl),
        border: Border.all(color: best ? p.success.withValues(alpha: 0.4) : p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tx(12, color: p.muted)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: tx(18, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
          ),
        ],
      ),
    );
  }
}

/// app/(app)/payroll/tax-preview/page.tsx
class TaxPreviewScreen extends StatefulWidget {
  const TaxPreviewScreen({super.key, this.employeeId, this.month});
  final String? employeeId;
  final String? month;

  @override
  State<TaxPreviewScreen> createState() => _TaxPreviewScreenState();
}

class _TaxPreviewScreenState extends State<TaxPreviewScreen> {
  // The applied GET query, and the form's not-yet-submitted values.
  late String? _employeeId = widget.employeeId;
  late String? _month = widget.month;
  String? _draftEmployee;
  String? _draftMonth;

  static const _header = PageHeader(
    title: 'Tax Preview',
    description:
        "Pick an employee and month to see a projected PF/ESI/Professional Tax/TDS breakdown at their current pay rate - for sanity-checking configuration, not a real payslip. Nothing here is saved or affects any employee's data.",
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/payroll/tax-preview',
      query: {'employeeId': _employeeId, 'month': _month},
      header: _header,
      builder: (context, data, reload) {
        final employee = _draftEmployee ?? data.sn('employeeId') ?? '';
        final month = _draftMonth ?? data.s('month');
        final preview = data.mN('preview');
        return [
          _header,
          TsCard(
            child: Gap(
              gap: 14,
              children: [
                TsSelect<String>(
                  label: 'Employee',
                  value: employee,
                  options: [
                    const SelectOption('', '— Select an employee —'),
                    for (final e in data.l('employees'))
                      SelectOption(
                        e.s('id'),
                        '${e.s('name')}${e.b('hasPayBand') ? '' : ' (no pay band)'}',
                        disabled: !e.b('hasPayBand'),
                      ),
                  ],
                  onChanged: (v) => setState(() => _draftEmployee = v ?? ''),
                ),
                TsMonthField(label: 'Month', value: month, onChanged: (v) => setState(() => _draftMonth = v)),
                TsButton.secondary(
                  label: 'Preview',
                  icon: LucideIcons.calculator,
                  expand: true,
                  onPressed: () => setState(() {
                    _employeeId = employee.isEmpty ? null : employee;
                    _month = month;
                  }),
                ),
              ],
            ),
          ),
          if (preview == null)
            const Muted('Select an employee to see a preview.')
          else if (preview.has('error'))
            _PreviewError(preview: preview)
          else
            ..._previewResult(context, preview),
        ];
      },
    );
  }

  List<Widget> _previewResult(BuildContext context, Json r) {
    final isOld = r.s('regime') == 'OLD';
    final pfType = r.s('pf.type');
    final warnings = r.list<String>('warnings');
    return [
      Muted(r.s('caption')),
      if (warnings.isNotEmpty) NoticeBox(title: 'Consultant Review Needed', bullets: warnings),
      LineSection(title: 'Monthly Gross', icon: LucideIcons.banknote, rows: [
        LineRow('Basic', inr(r.at('monthly.basic'))),
        LineRow('Dearness Allowance', inr(r.at('monthly.da'))),
        LineRow('HRA', inr(r.at('monthly.hra'))),
        LineRow('Special / Other Allowance', inr(r.at('monthly.specialAllowance'))),
        LineRow('Gross Cash Earnings', inr(r.at('monthly.grossCashEarnings')), strong: true),
      ]),
      if (r.b('pf.computed'))
        LineSection(title: 'Provident Fund ($pfType)', icon: LucideIcons.landmark, rows: [
          LineRow('Wage Base (Basic + DA)', inr(r.at('pf.wageBase'))),
          LineRow('Employee Contribution', inr(r.at('pf.employeeAmount'))),
          LineRow('Employer Contribution', inr(r.at('pf.employerAmount'))),
        ])
      else
        TsCard(
          title: 'Provident Fund ($pfType)',
          icon: LucideIcons.landmark,
          child: Muted(pfType == 'EXEMPT' ? 'Exempt - no PF contribution.' : 'Not auto-computed for this PF type.'),
        ),
      if (r.b('esi.applicable'))
        LineSection(title: 'ESI', icon: LucideIcons.shieldCheck, rows: [
          LineRow('Wage Base (Gross Cash Earnings)', inr(r.at('esi.wageBase'))),
          LineRow('Employee Contribution', inr(r.at('esi.employeeAmount'))),
          LineRow('Employer Contribution', inr(r.at('esi.employerAmount'))),
        ])
      else
        const TsCard(title: 'ESI', icon: LucideIcons.shieldCheck, child: Muted('Not applicable.')),
      LineSection(
        title: 'Professional Tax',
        icon: LucideIcons.mapPin,
        rows: [LineRow('Monthly Amount', inr(r.at('professionalTax')))],
      ),
      LineSection(
        title: 'Gratuity — CTC Accrual (Informational)',
        icon: LucideIcons.piggyBank,
        rows: [LineRow('Monthly Accrual', inr(r.at('gratuityAccrual')))],
        footer: 'Bookkeeping allocation only, not the statutory entitlement payable at separation. Never deducted from net pay.',
      ),
      LineSection(
        title: 'Income Tax (TDS)',
        icon: LucideIcons.receipt,
        rows: [
          LineRow('Projected Annual Gross', inr(r.at('tax.projectedAnnualGross'))),
          if (isOld) LineRow('HRA Exemption', inr(r.at('tax.hraExemption'))),
          if (isOld) LineRow('Chapter VI-A Deductions (80C/80D/Home Loan)', inr(r.at('tax.chapterViaDeductions'))),
          LineRow('Standard Deduction', inr(r.at('tax.standardDeduction'))),
          LineRow('Taxable Income (Annual)', inr(r.at('tax.taxableIncomeAnnual'))),
          LineRow('Tax Before Rebate', inr(r.at('tax.taxBeforeRebate'))),
          LineRow('Section 87A Rebate', inr(r.at('tax.rebateApplied'))),
          LineRow('Surcharge', inr(r.at('tax.surchargeAmount'))),
          LineRow('Cess', inr(r.at('tax.cessAmount'))),
          LineRow('Annual Tax Payable', inr(r.at('tax.annualTaxPayable')), strong: true),
          LineRow('Projected Monthly TDS', inr(r.at('tax.tdsThisMonth')), strong: true),
        ],
        footer: r.b('tax.marginalReliefApplied')
            ? 'Marginal relief applied - the surcharge is capped so crossing into this slab never costs more than the income crossed over.'
            : null,
      ),
      LineSection(
        title: 'Net Pay (this month, before Attendance deductions)',
        highlight: true,
        rows: [LineRow('Gross − PF(EE) − ESI(EE) − PT − TDS', inr(r.at('netPay')), strong: true)],
        footer:
            "Attendance-based deductions (LWP/half-day) and any approved Leave Encashment credit aren't included in this preview - those are computed when an actual Payroll Run is processed.",
      ),
    ];
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.preview});
  final Json preview;

  @override
  Widget build(BuildContext context) {
    final error = preview.s('error');
    if (!preview.b('boxed')) return StatusMessage.error(error);
    final link = preview.sn('link');
    return NoticeBox(
      kind: StatusKind.error,
      text: error,
      child: link == null
          ? null
          : Align(
              alignment: Alignment.centerLeft,
              child: TsLink('Settings → Tax Settings', onTap: () => context.push(link), color: Ts.of(context).danger),
            ),
    );
  }
}
