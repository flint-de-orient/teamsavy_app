import '../../widgets/ts.dart';

// Pieces shared by the Termination Letters list/detail/form/settlement
// screens - mirrors app/(app)/termination-letters/*'s own small shared
// constants (REASON_OPTIONS in termination-letter-form.tsx, REASON_LABEL
// in [id]/page.tsx).

const kTerminationReasonOptions = [
  SelectOption('PERFORMANCE', 'Performance'),
  SelectOption('MISCONDUCT', 'Misconduct'),
  SelectOption('REDUNDANCY', 'Redundancy'),
  SelectOption('RESIGNATION', 'Resignation (accepted)'),
  SelectOption('CONTRACT_END', 'End of Contract'),
  SelectOption('MUTUAL_SEPARATION', 'Mutual Separation'),
  SelectOption('OTHER', 'Other'),
];

TsBadge terminationStatusBadge(String status) => status == 'ISSUED'
    ? const TsBadge('Issued', tone: BadgeTone.green)
    : const TsBadge('Draft', tone: BadgeTone.amber);

/// The detail page's "Notice Period" row value - byte-for-byte mirror of
/// [id]/page.tsx's own ternary.
String noticePeriodSummary(Json letter) {
  if (letter.b('noticePeriodServed')) {
    final days = letter.iN('noticePeriodDays');
    return 'Served${days != null ? ' — $days day(s) contractual' : ''}';
  }
  final payInLieuDays = letter.iN('payInLieuDays');
  if (payInLieuDays == 0) {
    return 'Waived — ${letter.sn('noticeWaiverReason') ?? 'no reason recorded'}';
  }
  return 'Pay in lieu${payInLieuDays != null ? ' — $payInLieuDays day(s)' : ''}';
}

/// The detail page's "Settlement" row value - byte-for-byte mirror of
/// [id]/page.tsx's own ternary.
String settlementSummary(Json letter) {
  if (letter.s('settlementStatus') == 'SETTLED') {
    final ref = letter.sn('settlementReference');
    return 'Settled — ${rupee(letter.at('settlementAmount'))} on ${fmtDate(letter.at('settlementPaidOn'))}'
        '${ref != null ? ' (Ref: $ref)' : ''}';
  }
  return 'Pending — due by ${fmtDate(letter.at('settlementDueBy'))}';
}

/// Opens one of the web app's protected file routes (letter/settlement
/// PDFs) and toasts the failure, if any - same pattern as every other
/// module's own openXFile helper (openWebFile, openHiringFile, ...).
Future<void> openTerminationFile(BuildContext context, String path) async {
  try {
    await api.openFile(path);
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.message, error: true);
  } catch (_) {
    if (context.mounted) toast(context, "Couldn't open this file.", error: true);
  }
}

/// A row of `<input type="radio">` + label pairs - same small widget each
/// feature module keeps its own copy of (see people/widgets.dart's
/// RadioRow, hiring/widgets.dart's RadioGroupRow).
class RadioRow<T> extends StatelessWidget {
  const RadioRow({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final List<SelectOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: [
        for (final o in options)
          InkWell(
            borderRadius: BorderRadius.circular(Ts.rXl),
            onTap: () => onChanged(o.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: p.surface,
                      border: Border.all(
                        color: o.value == value ? p.primary : p.border,
                        width: o.value == value ? 5 : 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(o.label, style: tx(14, color: p.foreground)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// A money line item in the Final Settlement breakdown - same look as
/// payroll/widgets.dart's own module-local LineRow.
class SettlementLineRow extends StatelessWidget {
  const SettlementLineRow(this.label, this.value, {super.key, this.strong = false, this.last = false});
  final String label;
  final String value;
  final bool strong;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: tx(14, color: strong ? p.foreground : p.muted, weight: strong ? FontWeight.w600 : FontWeight.w400),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            textAlign: TextAlign.right,
            style: tx(strong ? 15 : 14, weight: strong ? FontWeight.w700 : FontWeight.w500, color: p.foreground),
          ),
        ],
      ),
    );
  }
}
