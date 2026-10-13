import 'package:intl/intl.dart';

// Dart port of lib/billing/gst.ts + lib/billing/money.ts's pure functions -
// kept BY HAND in sync with those two files (same "independent mirror, not
// a shared module" convention as every lib/mobile/*.ts <-> *_screen.dart
// pair - see lib/mobile/billing.ts's header comment). Run on-device so the
// Billing screen's Max Seats input can recompute pricing live as the admin
// types, instead of a server round-trip per keystroke - web does the exact
// same thing in app/(app)/settings/billing/billing-panel.tsx.

const _gstRateBasisPoints = 1800; // 18.00%, see GST_RATE_BASIS_POINTS.

class GstBreakdown {
  const GstBreakdown({required this.cgst, required this.sgst, required this.igst, required this.gstAmount, required this.totalAmount});
  final int cgst;
  final int sgst;
  final int igst;
  final int gstAmount;
  final int totalAmount;
}

/// subtotalPaise must be a non-negative integer. gstType is 'CGST_SGST' or
/// 'IGST'. Rounds to the nearest paisa, same as the web's Math.round.
GstBreakdown computeGst(int subtotalPaise, String gstType) {
  final gstAmount = ((subtotalPaise * _gstRateBasisPoints) / 10000).round();
  final totalAmount = subtotalPaise + gstAmount;
  if (gstType == 'CGST_SGST') {
    final cgst = gstAmount ~/ 2;
    return GstBreakdown(cgst: cgst, sgst: gstAmount - cgst, igst: 0, gstAmount: gstAmount, totalAmount: totalAmount);
  }
  return GstBreakdown(cgst: 0, sgst: 0, igst: gstAmount, gstAmount: gstAmount, totalAmount: totalAmount);
}

/// Plan.pricePerEmployeeAnnual is the effective MONTHLY rate billed
/// annually - the real once-a-year charge is this times 12. See
/// annualChargePerEmployeePaise's own comment in lib/billing/money.ts for
/// why this is the ONLY place x12 happens.
int annualChargePerEmployeePaise(int pricePerEmployeeAnnualPaise) => pricePerEmployeeAnnualPaise * 12;

final _rupeeFormat = NumberFormat('#,##,##0.00', 'en_IN');

/// "₹50.00" - the exact Dart equivalent of formatPaiseAsRupees.
String formatPaiseAsRupees(int paise) => '₹${_rupeeFormat.format(paise / 100)}';
