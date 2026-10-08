import '../../widgets/ts.dart';

/// app/(app)/expenses/new/page.tsx + apply-expense-claim-form.tsx. One
/// category, description, amount, date and an optional receipt, which can
/// be photographed with the camera. Success redirects to the new claim.
class ApplyExpenseScreen extends StatelessWidget {
  const ApplyExpenseScreen({super.key});

  static const _header = PageHeader(title: 'Submit an Expense Claim');

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/expenses/new',
      header: _header,
      builder: (context, data, reload) => [
        _header,
        _ApplyExpenseForm(
          categories: [for (final c in data.l('categories')) SelectOption(c.s('value'), c.s('label'))],
          defaultCategory: data.s('defaultCategory', 'TRAVEL'),
        ),
      ],
    );
  }
}

class _ApplyExpenseForm extends StatefulWidget {
  const _ApplyExpenseForm({required this.categories, required this.defaultCategory});
  final List<SelectOption<String>> categories;
  final String defaultCategory;

  @override
  State<_ApplyExpenseForm> createState() => _ApplyExpenseFormState();
}

class _ApplyExpenseFormState extends State<_ApplyExpenseForm> {
  final _description = TextEditingController();
  final _amount = TextEditingController();
  late String _category = widget.defaultCategory;
  String? _expenseDate;
  UploadFile? _receipt;
  bool _pending = false;
  String? _error;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _pending = true;
      _error = null;
    });
    // Empty strings, not nulls: the action reads missing fields as null,
    // and a null expenseDate would coerce to 1970 instead of failing.
    final r = await runAction(
      context,
      () => api.action(
        'expenses.applyForExpenseClaim',
        fields: {
          'category': _category,
          'description': _description.text.trim(),
          'amount': _amount.text.trim(),
          'expenseDate': _expenseDate ?? '',
        },
        files: {'receipt': _receipt},
      ),
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TsCard(
      child: Gap(
        gap: 16,
        children: [
          TsSelect<String>(
            label: 'Category',
            value: _category,
            options: widget.categories,
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          TsTextarea(controller: _description, label: 'Description', rows: 3),
          TsInput(
            controller: _amount,
            label: 'Amount (₹)',
            keyboardType: TextInputType.number,
            inputFormatters: TsInput.digitsOnly,
          ),
          TsDateField(
            label: 'Expense Date',
            value: _expenseDate,
            onChanged: (v) => setState(() => _expenseDate = v),
          ),
          TsFileField(
            label: 'Receipt (optional)',
            file: _receipt,
            accept: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
            onChanged: (f) => setState(() => _receipt = f),
          ),
          if (_error != null) StatusMessage.error(_error),
          Align(
            alignment: Alignment.centerLeft,
            child: TsButton(
              label: 'Submit Claim',
              pendingLabel: 'Submitting...',
              pending: _pending,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
