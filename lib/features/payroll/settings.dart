import '../../widgets/ts.dart';
import 'widgets.dart';

/// A useActionState-style form submit: pending flag, error / success text.
mixin _FormSubmit<T extends StatefulWidget> on State<T> {
  bool pending = false;
  String? error;
  bool saved = false;

  /// Runs [action]; returns true on success.
  Future<bool> submit(String action, Map<String, Object?> fields) async {
    setState(() {
      pending = true;
      error = null;
      saved = false;
    });
    final r = await runAction(context, () => api.action(action, fields: fields), followRedirects: false);
    if (!mounted) return r.ok;
    setState(() {
      pending = false;
      error = r.error;
      saved = r.ok;
    });
    return r.ok;
  }
}

TextEditingController _ctrl(Object? value) => TextEditingController(text: value == null ? '' : numText(value));

/// The small red "Remove" text button on the settings tables - submits the
/// row's delete action straight away, like the web.
class RemoveLink extends StatefulWidget {
  const RemoveLink({super.key, required this.action, required this.id});
  final String action;
  final String id;

  @override
  State<RemoveLink> createState() => _RemoveLinkState();
}

class _RemoveLinkState extends State<RemoveLink> {
  bool _pending = false;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return TsLink(
      'Remove',
      size: 12,
      color: p.danger,
      onTap: _pending
          ? null
          : () async {
              setState(() => _pending = true);
              await runAction(context, () => api.action(widget.action, fields: {'id': widget.id}),
                  followRedirects: false, toastErrors: true);
              if (mounted) setState(() => _pending = false);
            },
    );
  }
}

/// `₹{min} – ₹{max}` or `₹{min} – and above`.
String slabRange(Json s) =>
    '${rupee(s.at('minIncome'))} – ${s.at('maxIncome') == null ? 'and above' : rupee(s.at('maxIncome'))}';

/// One compact table row: main text, muted meta line, trailing value and
/// an optional Remove link.
class SettingRow extends StatelessWidget {
  const SettingRow({super.key, required this.title, this.meta, this.trailing, this.remove});
  final String title;
  final String? meta;
  final Widget? trailing;
  final Widget? remove;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tx(14, weight: FontWeight.w600, color: p.foreground)),
                if (meta != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(meta!, style: tx(12, color: p.muted))),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          if (remove != null) ...[const SizedBox(width: 12), remove!],
        ],
      ),
    );
  }
}

/// Rows separated by hairlines, or the table's empty text.
class DividedRows extends StatelessWidget {
  const DividedRows({super.key, required this.children, required this.empty});
  final List<Widget> children;
  final String empty;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    if (children.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(empty, textAlign: TextAlign.center, style: tx(14, color: p.muted)),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, color: p.border),
          children[i],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// /settings/pf

class PfSettingsScreen extends StatelessWidget {
  const PfSettingsScreen({super.key});

  static const _header = PageHeader(
    title: 'PF Settings',
    description: 'Provident Fund contribution rates and the default PF type assigned to new employees.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/pf',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        if (!data.b('canWrite'))
          const Muted('Contact your tenant admin to change PF settings.')
        else
          _PfForm(settings: data.m('settings')),
      ],
    );
  }
}

class _PfForm extends StatefulWidget {
  const _PfForm({required this.settings});
  final Json settings;

  @override
  State<_PfForm> createState() => _PfFormState();
}

class _PfFormState extends State<_PfForm> with _FormSubmit {
  late final _pf = _ctrl(widget.settings.at('employeePfPercent'));
  late String _type = widget.settings.s('defaultPfType', 'EPF');
  late bool _ceiling = widget.settings.b('applyWageCeiling');
  late final _pfCeiling = _ctrl(widget.settings.at('pfWageCeiling'));
  late final _eps = _ctrl(widget.settings.at('epsPercent'));
  late final _epsCeiling = _ctrl(widget.settings.at('epsWageCeiling'));

  @override
  void dispose() {
    for (final c in [_pf, _pfCeiling, _eps, _epsCeiling]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TsCard(
      child: Gap(
        gap: 16,
        children: [
          TsInput(controller: _pf, label: 'Employee PF Contribution (% of Basic + DA)', keyboardType: numberKeyboard),
          TsSelect<String>(
            label: 'Default PF Type for New Employees',
            value: _type,
            options: const [
              SelectOption('EPF', 'EPF'),
              SelectOption('GPF', 'GPF'),
              SelectOption('CPF', 'CPF'),
              SelectOption('EXEMPT', 'Exempt'),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'EPF'),
          ),
          TsCheckbox(
            label: 'Apply the statutory PF wage ceiling',
            value: _ceiling,
            onChanged: (v) => setState(() => _ceiling = v),
          ),
          TsInput(controller: _pfCeiling, label: 'PF Wage Ceiling (₹)', keyboardType: numberKeyboard),
          TsInput(
            controller: _eps,
            label: 'EPS (Pension) Contribution (% of Basic + DA)',
            keyboardType: numberKeyboard,
            hint: 'Employer PF statutorily splits into EPF + EPS + EDLI. Kept for accuracy - actual EPFO filing is out of scope.',
          ),
          TsInput(controller: _epsCeiling, label: 'EPS Wage Ceiling (₹)', keyboardType: numberKeyboard),
          if (error != null) StatusMessage.error(error),
          if (saved) StatusMessage.success('PF settings saved.'),
          TsButton(
            label: 'Save PF Settings',
            pendingLabel: 'Saving...',
            pending: pending,
            expand: true,
            onPressed: () => submit('payroll.updatePfSettings', {
              'employeePfPercent': _pf.text.trim(),
              'defaultPfType': _type,
              if (_ceiling) 'applyWageCeiling': 'on',
              'pfWageCeiling': _pfCeiling.text.trim(),
              'epsPercent': _eps.text.trim(),
              'epsWageCeiling': _epsCeiling.text.trim(),
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// /settings/esi

class EsiSettingsScreen extends StatelessWidget {
  const EsiSettingsScreen({super.key});

  static const _header = PageHeader(
    title: 'ESI Settings',
    description: 'Employee State Insurance contribution rates and the wage-eligibility threshold.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/esi',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        if (!data.b('canWrite'))
          const Muted('Contact your tenant admin to change ESI settings.')
        else
          _EsiForm(settings: data.m('settings')),
      ],
    );
  }
}

class _EsiForm extends StatefulWidget {
  const _EsiForm({required this.settings});
  final Json settings;

  @override
  State<_EsiForm> createState() => _EsiFormState();
}

class _EsiFormState extends State<_EsiForm> with _FormSubmit {
  late bool _enabled = widget.settings.b('enabled');
  late final _employee = _ctrl(widget.settings.at('employeeEsiPercent'));
  late final _employer = _ctrl(widget.settings.at('employerEsiPercent'));
  late final _threshold = _ctrl(widget.settings.at('wageThreshold'));

  @override
  void dispose() {
    for (final c in [_employee, _employer, _threshold]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TsCard(
      child: Gap(
        gap: 16,
        children: [
          TsCheckbox(label: 'ESI applies to this company', value: _enabled, onChanged: (v) => setState(() => _enabled = v)),
          TsInput(controller: _employee, label: 'Employee ESI Contribution (%)', keyboardType: numberKeyboard),
          TsInput(controller: _employer, label: 'Employer ESI Contribution (%)', keyboardType: numberKeyboard),
          TsInput(
            controller: _threshold,
            label: 'Wage Eligibility Threshold (₹/month)',
            keyboardType: numberKeyboard,
            hint:
                "ESI's semi-annual contribution-period lock-in isn't automated - once you mark an employee ESI-applicable on their Payroll Profile, it's your call when to turn it off after a raise crosses this threshold mid-period.",
          ),
          if (error != null) StatusMessage.error(error),
          if (saved) StatusMessage.success('ESI settings saved.'),
          TsButton(
            label: 'Save ESI Settings',
            pendingLabel: 'Saving...',
            pending: pending,
            expand: true,
            onPressed: () => submit('payroll.updateEsiSettings', {
              if (_enabled) 'enabled': 'on',
              'employeeEsiPercent': _employee.text.trim(),
              'employerEsiPercent': _employer.text.trim(),
              'wageThreshold': _threshold.text.trim(),
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// /settings/tax

const _ageBracketLabels = {
  'ALL': 'All ages',
  'BELOW_60': 'Below 60',
  'SENIOR_60_80': '60–80 (Senior)',
  'SUPER_SENIOR_80_PLUS': '80+ (Super Senior)',
};

const _regimeOptions = [SelectOption('NEW', 'New'), SelectOption('OLD', 'Old')];

String _regimeLabel(String regime) => regime == 'OLD' ? 'Old' : 'New';

class TaxSettingsScreen extends StatelessWidget {
  const TaxSettingsScreen({super.key});

  static const _header = PageHeader(
    title: 'Tax Settings',
    description:
        'Income tax configuration for TDS, versioned by regime and financial year since standard deduction, the Section 87A rebate, slabs, and surcharge all change every Union Budget.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/tax',
      header: _header,
      builder: (context, data, reload) {
        final canWrite = data.b('canWrite');
        return [
          _header,
          const Muted(
            "Surcharge and marginal relief are computed automatically from the Surcharge Slabs below. Section 80D's senior-citizen-parent sub-limit is still not modeled - only a flat cap - the payslip will show a warning banner when it may apply. Verify these numbers with your tax consultant before relying on them.",
          ),
          const SectionTitle(
            'Regime Configuration',
            description:
                'Standard deduction and Section 87A rebate, per regime and financial year. The Old-regime-only columns (Chapter VI-A caps, HRA city %) show “—” for New regime rows, which don\'t use them. Adding a config for a (regime, FY) that already exists updates it in place - existing config for other years stays untouched for reference.',
          ),
          if (data.l('configs').isEmpty) const EmptyState('No regime configuration yet.'),
          for (final c in data.l('configs'))
            MobileCard(
              children: [
                MobileCardHeader(
                  title: 'FY ${c.s('financialYear')}',
                  subtitle: '${_regimeLabel(c.s('regime'))} regime',
                  action: canWrite ? RemoveLink(action: 'payroll.deleteTaxRegimeConfig', id: c.s('id')) : null,
                ),
                MobileCardRows(rows: [
                  MobileCardRow(label: 'Std. Deduction', value: rupee(c.at('standardDeduction'))),
                  MobileCardRow(label: '87A Threshold', value: rupee(c.at('rebateIncomeThreshold'))),
                  MobileCardRow(label: '87A Max Rebate', value: rupee(c.at('rebateMaxAmount'))),
                  MobileCardRow(label: 'Cess', value: '${numText(c.at('cessPercent'))}%'),
                  MobileCardRow(label: '80C Cap', value: c.at('section80CCap') == null ? '—' : rupee(c.at('section80CCap'))),
                  MobileCardRow(label: '80D Cap', value: c.at('section80DCap') == null ? '—' : rupee(c.at('section80DCap'))),
                  MobileCardRow(
                    label: 'Home Loan Cap',
                    value: c.at('homeLoanInterestCap') == null ? '—' : rupee(c.at('homeLoanInterestCap')),
                  ),
                  MobileCardRow(
                    label: 'HRA Metro%',
                    value: c.at('hraMetroPercent') == null ? '—' : '${numText(c.at('hraMetroPercent'))}%',
                  ),
                  MobileCardRow(
                    label: 'HRA Non-Metro%',
                    value: c.at('hraNonMetroPercent') == null ? '—' : '${numText(c.at('hraNonMetroPercent'))}%',
                  ),
                ]),
              ],
            ),
          if (canWrite) const _RegimeConfigForm(),
          const SectionTitle(
            'Slabs',
            top: 16,
            description:
                'Progressive slabs applied to taxable income, per regime/financial year/age bracket. Leave Max Income blank for the top, unbounded slab.',
          ),
          TsCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: DividedRows(
              empty: 'No slabs configured yet.',
              children: [
                for (final s in data.l('slabs'))
                  SettingRow(
                    title: slabRange(s),
                    meta:
                        '${s.s('financialYear')} · ${_regimeLabel(s.s('regime'))} · ${_ageBracketLabels[s.s('ageBracket')] ?? s.s('ageBracket')}',
                    trailing: TsPill('${numText(s.at('ratePercent'))}%', tone: BadgeTone.purple),
                    remove: canWrite ? RemoveLink(action: 'payroll.deleteTaxSlab', id: s.s('id')) : null,
                  ),
              ],
            ),
          ),
          if (canWrite) const _SlabForm(surcharge: false),
          const SectionTitle(
            'Surcharge Slabs',
            top: 16,
            description:
                'Surcharge on income tax above statutory thresholds (e.g. ₹50L/1Cr/2Cr/5Cr), per regime and financial year - not age-differentiated. Marginal relief is applied automatically at each threshold, so the tax+surcharge increase from crossing into a slab never exceeds the income crossed over. Leave Max Income blank for the top, unbounded slab.',
          ),
          TsCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: DividedRows(
              empty: 'No surcharge slabs configured yet.',
              children: [
                for (final s in data.l('surchargeSlabs'))
                  SettingRow(
                    title: slabRange(s),
                    meta: '${s.s('financialYear')} · ${_regimeLabel(s.s('regime'))}',
                    trailing: TsPill('${numText(s.at('ratePercent'))}%', tone: BadgeTone.purple),
                    remove: canWrite ? RemoveLink(action: 'payroll.deleteSurchargeSlab', id: s.s('id')) : null,
                  ),
              ],
            ),
          ),
          if (canWrite) const _SlabForm(surcharge: true),
        ];
      },
    );
  }
}

class _RegimeConfigForm extends StatefulWidget {
  const _RegimeConfigForm();

  @override
  State<_RegimeConfigForm> createState() => _RegimeConfigFormState();
}

class _RegimeConfigFormState extends State<_RegimeConfigForm> with _FormSubmit {
  String _regime = 'NEW';
  final _fy = TextEditingController();
  final _std = TextEditingController();
  final _threshold = TextEditingController();
  final _rebate = TextEditingController();
  final _cess = TextEditingController(text: '4');
  final _c80 = TextEditingController();
  final _d80 = TextEditingController();
  final _homeLoan = TextEditingController();
  final _hraMetro = TextEditingController();
  final _hraNonMetro = TextEditingController();

  List<TextEditingController> get _all => [_fy, _std, _threshold, _rebate, _cess, _c80, _d80, _homeLoan, _hraMetro, _hraNonMetro];

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await submit('payroll.upsertTaxRegimeConfig', {
      'regime': _regime,
      'financialYear': _fy.text.trim(),
      'standardDeduction': _std.text.trim(),
      'rebateIncomeThreshold': _threshold.text.trim(),
      'rebateMaxAmount': _rebate.text.trim(),
      'cessPercent': _cess.text.trim(),
      if (_regime == 'OLD') ...{
        'section80CCap': _c80.text.trim(),
        'section80DCap': _d80.text.trim(),
        'homeLoanInterestCap': _homeLoan.text.trim(),
        'hraMetroPercent': _hraMetro.text.trim(),
        'hraNonMetroPercent': _hraNonMetro.text.trim(),
      },
    });
    // A submitted <form> resets its uncontrolled fields.
    if (ok && mounted) {
      setState(() {
        for (final c in _all) {
          c.clear();
        }
        _cess.text = '4';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final old = _regime == 'OLD';
    return TsPanel(
      child: Gap(
        gap: 14,
        children: [
          TsSelect<String>(
            label: 'Regime',
            value: _regime,
            options: _regimeOptions,
            onChanged: (v) => setState(() => _regime = v ?? 'NEW'),
          ),
          TsInput(controller: _fy, label: 'Financial Year', placeholder: '2026-27'),
          TsInput(controller: _std, label: 'Standard Deduction (₹)', keyboardType: numberKeyboard),
          TsInput(controller: _threshold, label: '87A Rebate Income Threshold (₹)', keyboardType: numberKeyboard),
          TsInput(controller: _rebate, label: '87A Max Rebate (₹)', keyboardType: numberKeyboard),
          TsInput(controller: _cess, label: 'Cess (%)', keyboardType: numberKeyboard),
          if (old) ...[
            TsInput(controller: _c80, label: 'Section 80C Cap (₹)', placeholder: '1,50,000', keyboardType: numberKeyboard),
            TsInput(controller: _d80, label: 'Section 80D Cap (₹)', placeholder: '25,000', keyboardType: numberKeyboard),
            TsInput(controller: _homeLoan, label: 'Home Loan Interest Cap (₹)', placeholder: '2,00,000', keyboardType: numberKeyboard),
            TsInput(controller: _hraMetro, label: 'HRA Metro %', placeholder: '50', keyboardType: numberKeyboard),
            TsInput(controller: _hraNonMetro, label: 'HRA Non-Metro %', placeholder: '40', keyboardType: numberKeyboard),
          ],
          if (error != null) StatusMessage.error(error),
          TsButton(label: 'Save', pendingLabel: 'Saving...', pending: pending, expand: true, onPressed: _save),
        ],
      ),
    );
  }
}

class _SlabForm extends StatefulWidget {
  const _SlabForm({required this.surcharge});
  final bool surcharge;

  @override
  State<_SlabForm> createState() => _SlabFormState();
}

class _SlabFormState extends State<_SlabForm> with _FormSubmit {
  String _regime = 'NEW';
  String _age = 'ALL';
  final _fy = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _rate = TextEditingController();

  @override
  void dispose() {
    for (final c in [_fy, _min, _max, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _add() async {
    final ok = await submit(widget.surcharge ? 'payroll.addSurchargeSlab' : 'payroll.addTaxSlab', {
      'regime': _regime,
      'financialYear': _fy.text.trim(),
      if (!widget.surcharge) 'ageBracket': _age,
      'minIncome': _min.text.trim(),
      'maxIncome': _max.text.trim(),
      'ratePercent': _rate.text.trim(),
    });
    if (ok && mounted) {
      setState(() {
        for (final c in [_fy, _min, _max, _rate]) {
          c.clear();
        }
        _regime = 'NEW';
        _age = 'ALL';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TsPanel(
      child: Gap(
        gap: 14,
        children: [
          TsSelect<String>(
            label: 'Regime',
            value: _regime,
            options: _regimeOptions,
            onChanged: (v) => setState(() => _regime = v ?? 'NEW'),
          ),
          TsInput(controller: _fy, label: 'Financial Year', placeholder: '2026-27'),
          if (!widget.surcharge)
            TsSelect<String>(
              label: 'Age Bracket',
              value: _age,
              options: const [
                SelectOption('ALL', 'All ages'),
                SelectOption('BELOW_60', 'Below 60'),
                SelectOption('SENIOR_60_80', '60–80'),
                SelectOption('SUPER_SENIOR_80_PLUS', '80+'),
              ],
              onChanged: (v) => setState(() => _age = v ?? 'ALL'),
            ),
          TsInput(controller: _min, label: 'Min Income (₹)', keyboardType: numberKeyboard),
          TsInput(controller: _max, label: 'Max Income (₹, blank = top slab)', keyboardType: numberKeyboard),
          TsInput(controller: _rate, label: 'Rate (%)', keyboardType: numberKeyboard),
          if (error != null) StatusMessage.error(error),
          TsButton(label: 'Add Slab', pendingLabel: 'Adding...', pending: pending, expand: true, onPressed: _add),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// /settings/professional-tax

class ProfessionalTaxScreen extends StatelessWidget {
  const ProfessionalTaxScreen({super.key});

  static const _header = PageHeader(
    title: 'Professional Tax',
    description:
        "State-specific monthly Professional Tax slabs, deducted from employee pay. An employee's applicable state is set on their Payroll Profile, falling back to an org-level default.",
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/professional-tax',
      header: _header,
      builder: (context, data, reload) {
        final canWrite = data.b('canWrite');
        return [
          _header,
          const Muted(
            "Some states adjust the February amount to round out the annual total - that quirk isn't modeled here, so a small February discrepancy against a consultant's numbers is expected for those states.",
          ),
          TsCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: DividedRows(
              empty: 'No Professional Tax slabs configured yet.',
              children: [
                for (final s in data.l('slabs'))
                  SettingRow(
                    title: s.s('state'),
                    meta: slabRange(s),
                    trailing: Text(rupee(s.at('monthlyAmount')),
                        style: tx(14, weight: FontWeight.w700, color: Ts.of(context).foreground)),
                    remove: canWrite ? RemoveLink(action: 'payroll.deleteProfessionalTaxSlab', id: s.s('id')) : null,
                  ),
              ],
            ),
          ),
          if (canWrite) const _PtSlabForm(),
        ];
      },
    );
  }
}

class _PtSlabForm extends StatefulWidget {
  const _PtSlabForm();

  @override
  State<_PtSlabForm> createState() => _PtSlabFormState();
}

class _PtSlabFormState extends State<_PtSlabForm> with _FormSubmit {
  final _state = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _amount = TextEditingController();

  @override
  void dispose() {
    for (final c in [_state, _min, _max, _amount]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _add() async {
    final ok = await submit('payroll.addProfessionalTaxSlab', {
      'state': _state.text.trim(),
      'minIncome': _min.text.trim(),
      'maxIncome': _max.text.trim(),
      'monthlyAmount': _amount.text.trim(),
    });
    if (ok && mounted) {
      setState(() {
        for (final c in [_state, _min, _max, _amount]) {
          c.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TsPanel(
      child: Gap(
        gap: 14,
        children: [
          TsInput(controller: _state, label: 'State', placeholder: 'West Bengal', textCapitalization: TextCapitalization.words),
          TsInput(controller: _min, label: 'Min Income (₹/month)', keyboardType: numberKeyboard),
          TsInput(controller: _max, label: 'Max Income (₹, blank = top slab)', keyboardType: numberKeyboard),
          TsInput(controller: _amount, label: 'Monthly Amount (₹)', keyboardType: numberKeyboard),
          if (error != null) StatusMessage.error(error),
          TsButton(label: 'Add Slab', pendingLabel: 'Adding...', pending: pending, expand: true, onPressed: _add),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// /settings/statutory-returns

class StatutoryReturnSettingsScreen extends StatelessWidget {
  const StatutoryReturnSettingsScreen({super.key});

  static const _title = 'Statutory Return Settings';
  static const _description =
      'Defaults feeding statutory-return generation under Payroll → Statutory Returns. Per-state Professional Tax file layouts live separately under Return File Templates.';

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/statutory-returns',
      header: const PageHeader(title: _title, description: _description),
      builder: (context, data, reload) => [
        PageHeader(
          title: _title,
          description: _description,
          actions: [
            TsButton.secondary(label: 'Back to Statutory Returns', onPressed: () => followRedirect(context, '/payroll/returns')),
          ],
        ),
        _StatutoryReturnSettingsForm(settings: data.m('settings')),
        Align(
          alignment: Alignment.centerLeft,
          child: TsLink('Manage Professional Tax return file templates →',
              onTap: () => context.push('/settings/return-templates')),
        ),
      ],
    );
  }
}

class _StatutoryReturnSettingsForm extends StatefulWidget {
  const _StatutoryReturnSettingsForm({required this.settings});
  final Json settings;

  @override
  State<_StatutoryReturnSettingsForm> createState() => _StatutoryReturnSettingsFormState();
}

class _StatutoryReturnSettingsFormState extends State<_StatutoryReturnSettingsForm> with _FormSubmit {
  late final _delimiter = TextEditingController(text: widget.settings.s('ecrDelimiter'));
  late final _pf = _ctrl(widget.settings.at('pfReturnDueDay'));
  late final _esi = _ctrl(widget.settings.at('esiReturnDueDay'));
  late final _pt = _ctrl(widget.settings.at('ptReturnDueDay'));
  late final _tds = _ctrl(widget.settings.at('tdsReturnDueOffset'));

  @override
  void dispose() {
    for (final c in [_delimiter, _pf, _esi, _pt, _tds]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TsCard(
      child: Gap(
        gap: 16,
        children: [
          TsInput(
            controller: _delimiter,
            label: 'PF ECR Column Delimiter',
            hint:
                'EPFO sources disagree on this - "#~#" and "||" have both been documented. Verify against whatever EPFO\'s portal currently accepts before filing, and correct it here if it rejects the download.',
          ),
          TsInput(
            controller: _pf,
            label: 'PF Return Due Day (day of next month)',
            keyboardType: TextInputType.number,
            inputFormatters: TsInput.digitsOnly,
          ),
          TsInput(
            controller: _esi,
            label: 'ESI Return Due Day (day of next month)',
            keyboardType: TextInputType.number,
            inputFormatters: TsInput.digitsOnly,
          ),
          TsInput(
            controller: _pt,
            label: 'Professional Tax Return Due Day (day of next month)',
            keyboardType: TextInputType.number,
            inputFormatters: TsInput.digitsOnly,
          ),
          TsInput(
            controller: _tds,
            label: 'TDS (24Q) Due Offset (days after quarter-end)',
            keyboardType: TextInputType.number,
            inputFormatters: TsInput.digitsOnly,
            hint: 'A suggestion only - actual 24Q due dates are set by CBDT notification and shift year to year.',
          ),
          if (error != null) StatusMessage.error(error),
          if (saved) StatusMessage.success('Saved.'),
          TsButton(
            label: 'Save',
            pendingLabel: 'Saving...',
            pending: pending,
            expand: true,
            onPressed: () => submit('payroll.updateStatutoryReturnSettings', {
              'ecrDelimiter': _delimiter.text,
              'pfReturnDueDay': _pf.text.trim(),
              'esiReturnDueDay': _esi.text.trim(),
              'ptReturnDueDay': _pt.text.trim(),
              'tdsReturnDueOffset': _tds.text.trim(),
            }),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// /settings/payout

BadgeTone _connectionTone(String status) => switch (status) {
      'ACTIVE' => BadgeTone.green,
      'ERROR' => BadgeTone.red,
      _ => BadgeTone.slate,
    };

class PayoutSettingsScreen extends StatelessWidget {
  const PayoutSettingsScreen({super.key});

  static const _header = PageHeader(
    title: 'Payout Integration',
    description:
        'Connect your own Cashfree Payouts account so Salary and Expense disbursement can pay via API, instead of only generating a beneficiary file for manual netbanking upload. Money always moves through your own bank-linked account - TeamSavy never holds or routes funds.',
  );

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/payout',
      header: _header,
      builder: (context, data, reload) {
        final p = Ts.of(context);
        final connection = data.mN('connection');
        if (!data.b('canManage')) {
          return [
            _header,
            TsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (connection != null)
                    Row(
                      children: [
                        Text('Cashfree Payouts', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
                        const SizedBox(width: 10),
                        TsBadge(connection.s('status'), tone: _connectionTone(connection.s('status'))),
                      ],
                    )
                  else
                    const Muted('No payout provider connected yet.'),
                  const SizedBox(height: 8),
                  const Muted('Contact your tenant admin to manage the payout connection.', size: 12),
                ],
              ),
            ),
          ];
        }
        return [
          _header,
          if (connection != null) _ConnectionCard(connection: connection),
          SectionTitle(connection != null ? 'Update Connection' : 'Connect a Payout Provider', top: 0),
          _ConnectionForm(connection: connection),
        ];
      },
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.connection});
  final Json connection;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final status = connection.s('status');
    final id = connection.s('id');
    return TsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('Cashfree Payouts', style: tx(14, weight: FontWeight.w600, color: p.foreground)),
              TsBadge(status, tone: _connectionTone(status)),
              TsBadge(connection.s('environment'), tone: BadgeTone.slate),
            ],
          ),
          if (connection.has('lastVerifiedAt'))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Last verified ${fmtDateTime(connection.at('lastVerifiedAt'))}', style: tx(12, color: p.muted)),
            ),
          if (connection.sn('lastErrorMessage') != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Last error: ${connection.s('lastErrorMessage')}', style: tx(12, color: p.danger)),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionButton(
                label: status == 'ACTIVE' ? 'Pause' : 'Resume',
                variant: TsButtonVariant.secondary,
                followRedirects: false,
                run: () => api.action(
                  status == 'ACTIVE' ? 'payroll.pausePayoutConnection' : 'payroll.resumePayoutConnection',
                  fields: {'id': id},
                ),
              ),
              ActionButton(
                label: 'Disconnect',
                variant: TsButtonVariant.danger,
                followRedirects: false,
                run: () => api.action('payroll.deletePayoutConnection', fields: {'id': id}),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConnectionForm extends StatefulWidget {
  const _ConnectionForm({required this.connection});
  final Json? connection;

  @override
  State<_ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends State<_ConnectionForm> with _FormSubmit {
  late String _environment = widget.connection?.s('environment', 'TEST') ?? 'TEST';
  final _provider = TextEditingController(text: 'Cashfree Payouts');
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();

  @override
  void dispose() {
    for (final c in [_provider, _clientId, _clientSecret]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final connected = widget.connection != null;
    return TsCard(
      child: Gap(
        gap: 16,
        children: [
          TsInput(controller: _provider, label: 'Provider', readOnly: true, hint: 'RazorpayX support is coming soon.'),
          TsSelect<String>(
            label: 'Environment',
            value: _environment,
            options: const [SelectOption('TEST', 'Test / Sandbox'), SelectOption('LIVE', 'Live')],
            onChanged: (v) => setState(() => _environment = v ?? 'TEST'),
          ),
          TsInput(controller: _clientId, label: 'Client ID', placeholder: connected ? 'Re-enter to change' : null),
          TsInput(
            controller: _clientSecret,
            label: 'Client Secret',
            obscure: true,
            placeholder: connected ? 'Leave blank to keep the current secret' : null,
          ),
          TsButton(
            label: connected ? 'Save & Re-verify' : 'Connect Cashfree',
            pendingLabel: 'Verifying...',
            pending: pending,
            expand: true,
            onPressed: () => submit('payroll.savePayoutConnection', {
              'environment': _environment,
              'clientId': _clientId.text.trim(),
              'clientSecret': _clientSecret.text,
            }),
          ),
          if (error != null) StatusMessage.error(error),
          if (saved) StatusMessage.success('Connected and verified.'),
        ],
      ),
    );
  }
}
