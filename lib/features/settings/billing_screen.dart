import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../widgets/ts.dart';

/// app/(app)/settings/billing/page.tsx + billing-panel.tsx. TENANT_ADMIN
/// only on the web (requireTenantAdmin(), not requireHrAdmin() like
/// Company/Policy Settings) - lib/mobile/billing.ts's getBillingSettingsData
/// enforces the same 403 for any other role, so this screen can assume a
/// 403 ErrorBlock is what a non-admin sees, same as every other admin-only
/// screen in this app.
///
/// RAZORPAY SUBSCRIPTION CHECKOUT - READ BEFORE TOUCHING THIS FILE:
/// razorpay_flutter's own docs only show `order_id`/`amount` in their
/// `open()` examples; there is no documented `subscription_id` option. This
/// screen passes `subscription_id` anyway, based on reading the installed
/// package's OWN SOURCE directly (pub cache: razorpay_flutter-1.4.6):
///   - Dart's `Razorpay.open()` -> `_validateOptions()` only checks that
///     `key` is present; every other key in the map (including
///     `subscription_id`) is passed through completely unvalidated.
///   - The Android native delegate (RazorpayDelegate.java's
///     `openCheckout()`) does `new JSONObject(arguments)` on the ENTIRE
///     options map and hands that raw JSON straight to Razorpay's native
///     `CheckoutActivity` - no field allowlist/filtering anywhere in this
///     plugin, on either platform.
/// So nothing in razorpay_flutter itself blocks `subscription_id`. What
/// COULDN'T be verified by reading source: whether Razorpay's own closed
/// native Android/iOS Checkout SDK (not vendored in this repo) correctly
/// honors `subscription_id` the same way Checkout.js does on web. It is
/// architecturally very likely (native Android/iOS Razorpay SDKs share
/// Checkout.js's options schema), but UNCONFIRMED without a real device
/// test. Similarly, `PaymentSuccessResponse` has no typed `subscriptionId`
/// field - `fromMap()` only pulls out paymentId/orderId/signature as typed
/// fields, but keeps the FULL raw native response map as `.data`, so if the
/// native SDK echoes `razorpay_subscription_id` on success it will only be
/// reachable via `response.data?['razorpay_subscription_id']`, read
/// defensively below. If it isn't present at all, that's fine: exactly
/// like the web flow, the webhook (not this client response) is the real
/// source of truth for activation - see _confirmPayment() below, which
/// never blocks or changes UI state on its own success/failure.
///
/// DO NOT treat "the checkout sheet opens and fires a success callback" as
/// proof this works end-to-end. The only real proof is the
/// subscription.authenticated/.activated webhook actually arriving for
/// this subscription afterward (checkable via the Subscription row's
/// razorpaySubscriptionId/status in the DB) - that requires one real,
/// human-present test transaction before this ships to real tenants.
class BillingSettingsScreen extends StatefulWidget {
  const BillingSettingsScreen({super.key});

  @override
  State<BillingSettingsScreen> createState() => _BillingSettingsScreenState();
}

const _statusLabel = {
  'TRIALING': 'Free trial',
  'ACTIVE': 'Active',
  'PAST_DUE': 'Payment failed',
  'CANCELED': 'Canceled',
};

class _BillingSettingsScreenState extends State<BillingSettingsScreen> {
  late final Razorpay _razorpay = Razorpay();
  String? _pendingKey;
  String? _error;
  bool _confirming = false;
  Future<void> Function()? _reload;

  @override
  void initState() {
    super.initState();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onPaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onPaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    setState(() {
      _confirming = true;
      _pendingKey = null;
    });
    // See this file's header comment: no typed `subscriptionId` field on
    // PaymentSuccessResponse - read defensively off the raw native map if
    // present at all. Debug-only visibility; never trusted for anything
    // (the webhook's own razorpaySubscriptionId lookup is what matters).
    if (kDebugMode) {
      debugPrint('[billing] checkout success, native subscription id: ${response.data?['razorpay_subscription_id']}');
    }
    // Fire-and-forget, UX nicety only - see this file's header comment and
    // app/actions/billing.ts's confirmCheckoutPayment: the webhook is the
    // real source of truth, so this call's outcome never gates anything
    // here. api.action() itself never throws (failures come back as
    // ActionResult.failure), so no catchError needed.
    unawaited(api.action(
      'billing.confirmCheckoutPayment',
      fields: {'razorpayPaymentId': response.paymentId, 'razorpaySignature': response.signature},
    ));
    _pollForActivation();
  }

  void _onPaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _pendingKey = null;
      _error = response.code == Razorpay.PAYMENT_CANCELLED
          ? null // user closed the sheet - not a real error.
          : (response.message ?? 'Payment failed. Try again.');
    });
  }

  void _pollForActivation() {
    var attempts = 0;
    Future<void> tick() async {
      if (!mounted) return;
      attempts++;
      await _reload?.call();
      if (!mounted) return;
      if (attempts < 10) {
        await Future.delayed(const Duration(seconds: 3));
        await tick();
      } else {
        setState(() => _confirming = false);
      }
    }
    tick();
  }

  Future<void> _subscribe(String planId, String cycle, String planName, Future<void> Function() reload) async {
    setState(() {
      _pendingKey = '$planId:$cycle';
      _error = null;
    });
    final r = await api.action(
      'billing.initiateSubscriptionCheckout',
      fields: {'planId': planId, 'billingCycle': cycle},
    );
    if (!mounted) return;
    if (!r.ok) {
      setState(() {
        _pendingKey = null;
        _error = r.error;
      });
      return;
    }
    final subscriptionId = r.data?.sn('checkoutSubscriptionId');
    final keyId = r.data?.sn('checkoutKeyId');
    if (subscriptionId == null || keyId == null) {
      setState(() {
        _pendingKey = null;
        _error = "Couldn't start checkout. Try again.";
      });
      return;
    }
    _reload = reload;
    _razorpay.open({
      'key': keyId,
      // See this file's header comment: subscription_id (not order_id or
      // amount) for subscription-mode checkout - Razorpay determines the
      // mandate-setup amount server-side from the Subscription itself.
      'subscription_id': subscriptionId,
      'name': 'TeamSavy',
      'description': '$planName - ${cycle == 'MONTHLY' ? 'Monthly' : 'Annual'}',
      'prefill': {'name': session.me?.name ?? '', 'email': session.me?.email ?? ''},
      'theme': {'color': '#6d28d9'},
    });
  }

  Future<void> _switchPlan(String planId, String cycle, Future<void> Function() reload) async {
    setState(() {
      _pendingKey = '$planId:$cycle';
      _error = null;
    });
    final r = await api.action(
      'billing.changeSubscriptionPlan',
      fields: {'planId': planId, 'billingCycle': cycle},
    );
    if (!mounted) return;
    setState(() {
      _pendingKey = null;
      _error = r.ok ? null : r.error;
    });
    if (r.ok) await reload();
  }

  Future<void> _cancel(String? currentPeriodEndIso, Future<void> Function() reload) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Cancel subscription?',
      message: 'Your org will keep full access until the end of the current billing period'
          '${currentPeriodEndIso != null ? ' (${fmtDateMedium(currentPeriodEndIso)})' : ''}. '
          "It will not renew after that, and this can't be undone from here - you'd need to subscribe again to "
          'restart billing.',
      confirmLabel: 'Cancel Subscription',
      danger: true,
    );
    if (!confirmed) return;
    final r = await api.action('billing.cancelSubscription', fields: const {});
    if (!mounted) return;
    if (!r.ok) {
      setState(() => _error = r.error);
      return;
    }
    await reload();
  }

  @override
  Widget build(BuildContext context) {
    return ApiScreen(
      path: '/settings/billing',
      header: const PageHeader(title: 'Billing', description: 'Your subscription, plan, and invoice history.'),
      builder: (context, data, reload) {
        _reload = reload;
        final subscription = data.mN('subscription');
        final plans = data.l('planOptions');
        final employeeCount = data.i('employeeCount');
        final invoices = data.l('invoices');
        final hasRazorpaySubscription = subscription?.b('hasRazorpaySubscription') ?? false;

        return [
          const PageHeader(title: 'Billing', description: 'Your subscription, plan, and invoice history.'),
          _StatusCard(subscription: subscription, employeeCount: employeeCount),
          if (_confirming)
            const StatusMessage(
              'Payment received - activating your subscription. This usually takes a few seconds.',
              kind: StatusKind.info,
              boxed: true,
            ),
          if (_error != null) StatusMessage.error(_error),
          SectionTitle(hasRazorpaySubscription ? 'Change Plan' : 'Choose a Plan'),
          if (!hasRazorpaySubscription && employeeCount < 1)
            TsPanel(
              color: Ts.of(context).warningLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add your first employee before setting up billing.',
                      style: tx(14, weight: FontWeight.w600, color: Ts.of(context).warning)),
                  const SizedBox(height: 4),
                  const Muted('Subscriptions are billed per active employee, so there must be at least one before checkout can start.'),
                  const SizedBox(height: 8),
                  TsButton.secondary(
                    label: 'Go to Employees',
                    icon: LucideIcons.users,
                    onPressed: () => context.push('/employees'),
                  ),
                ],
              ),
            ),
          for (final plan in plans)
            _PlanCard(
              plan: plan,
              employeeCount: employeeCount,
              isCurrent: hasRazorpaySubscription && subscription?.sn('planId') == plan.sn('id'),
              currentCycle: subscription?.sn('billingCycle'),
              canSubscribe: employeeCount >= 1,
              pendingKey: _pendingKey,
              onChoose: (cycle) => hasRazorpaySubscription
                  ? _switchPlan(plan.s('id'), cycle, reload)
                  : _subscribe(plan.s('id'), cycle, plan.s('name'), reload),
            ),
          if (hasRazorpaySubscription && subscription?.sn('status') != 'CANCELED')
            MobileCard(
              children: [
                const MobileCardHeader(title: 'Cancel Subscription'),
                const Muted(
                  "Cancels at the end of your current billing period - you keep access until then, and it won't renew afterward.",
                ),
                const SizedBox(height: 10),
                TsButton.danger(
                  label: 'Cancel Subscription',
                  onPressed: () => _cancel(subscription?.sn('currentPeriodEnd'), reload),
                ),
              ],
            ),
          SectionTitle('Invoice History'),
          if (invoices.isEmpty)
            const EmptyState('No invoices yet.', icon: LucideIcons.receipt)
          else
            for (final invoice in invoices) _InvoiceCard(invoice: invoice),
        ];
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.subscription, required this.employeeCount});
  final Json? subscription;
  final int employeeCount;

  @override
  Widget build(BuildContext context) {
    if (subscription == null) {
      return MobileCard(children: const [Muted('No billing record was found for your organization.')]);
    }
    final status = subscription!.s('status');
    final trialEndsAt = subscription!.sn('trialEndsAt');
    final pastDueSince = subscription!.sn('pastDueSince');
    final daysUntilGraceEnds = subscription!.iN('daysUntilGraceEnds');
    final tone = status == 'ACTIVE'
        ? BadgeTone.green
        : status == 'PAST_DUE'
            ? BadgeTone.red
            : status == 'CANCELED'
                ? BadgeTone.slate
                : BadgeTone.amber;

    return MobileCard(
      children: [
        MobileCardHeader(
          title: subscription!.s('planName'),
          subtitle: subscription!.s('billingCycle') == 'MONTHLY' ? 'Billed monthly' : 'Billed annually',
          action: TsBadge(_statusLabel[status] ?? status, tone: tone),
        ),
        Muted('Billed for $employeeCount active employee${employeeCount == 1 ? '' : 's'}.'),
        if (status == 'TRIALING' && trialEndsAt != null) ...[
          const SizedBox(height: 10),
          StatusMessage.warning('Your free trial ends ${fmtDateMedium(trialEndsAt)}. Subscribe below to keep access.'),
        ],
        if (status == 'PAST_DUE') ...[
          const SizedBox(height: 10),
          StatusMessage(
            pastDueSince == null
                ? 'Your last payment failed. Update your payment method to avoid losing access.'
                : daysUntilGraceEnds == null || daysUntilGraceEnds > 0
                    ? 'Your last payment failed. You have ${daysUntilGraceEnds ?? '?'} day(s) left before access is restricted.'
                    : 'Your last payment failed. Access will be restricted today unless the payment is fixed.',
            kind: StatusKind.error,
            boxed: true,
          ),
        ],
        if (status == 'CANCELED') ...[
          const SizedBox(height: 10),
          const Muted('This subscription has been canceled. Subscribe again below to restore billing.'),
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.employeeCount,
    required this.isCurrent,
    required this.currentCycle,
    required this.canSubscribe,
    required this.pendingKey,
    required this.onChoose,
  });
  final Json plan;
  final int employeeCount;
  final bool isCurrent;
  final String? currentCycle;
  final bool canSubscribe;
  final String? pendingKey;
  final void Function(String cycle) onChoose;

  @override
  Widget build(BuildContext context) {
    final monthly = plan.mN('monthly');
    final annual = plan.mN('annual');
    final planId = plan.s('id');
    return MobileCard(
      children: [
        MobileCardHeader(title: plan.s('name')),
        if (monthly != null)
          MobileCardRow(label: 'Monthly, per employee (incl. GST)', value: monthly.s('perEmployeeLabel'), first: true),
        if (annual != null)
          MobileCardRow(label: 'Annual, per employee (incl. GST)', value: annual.s('perEmployeeLabel')),
        const SizedBox(height: 10),
        if (monthly != null)
          TsButton.secondary(
            label: isCurrent && currentCycle == 'MONTHLY'
                ? 'Current plan (monthly)'
                : 'Monthly - ${monthly.s('totalLabel')}/mo for $employeeCount',
            pending: pendingKey == '$planId:MONTHLY',
            onPressed: (!canSubscribe || (isCurrent && currentCycle == 'MONTHLY')) ? null : () => onChoose('MONTHLY'),
          ),
        if (annual != null) ...[
          const SizedBox(height: 8),
          TsButton(
            label: isCurrent && currentCycle == 'ANNUAL'
                ? 'Current plan (annual)'
                : 'Annual - ${annual.s('totalLabel')}/yr for $employeeCount',
            pending: pendingKey == '$planId:ANNUAL',
            onPressed: (!canSubscribe || (isCurrent && currentCycle == 'ANNUAL')) ? null : () => onChoose('ANNUAL'),
          ),
        ],
      ],
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  const _InvoiceCard({required this.invoice});
  final Json invoice;

  @override
  Widget build(BuildContext context) {
    return MobileCard(
      children: [
        MobileCardHeader(
          title: '${fmtDateMedium(invoice.s('periodStart'))} - ${fmtDateMedium(invoice.s('periodEnd'))}',
          action: TsBadge(invoice.s('status'), tone: invoice.s('status') == 'PAID' ? BadgeTone.green : BadgeTone.amber),
        ),
        MobileCardRows(rows: [
          MobileCardRow(label: 'Seats', value: '${invoice.i('quantity')}', first: true),
          MobileCardRow(label: 'Subtotal', value: invoice.s('subtotalLabel')),
          MobileCardRow(label: 'GST', value: invoice.s('gstAmountLabel')),
          MobileCardRow(label: 'Total', value: invoice.s('totalLabel')),
        ]),
        if (invoice.b('hasPdf')) ...[
          const SizedBox(height: 10),
          TsButton.secondary(
            label: 'View PDF',
            icon: LucideIcons.download,
            onPressed: () => _openInvoicePdf(context, invoice.s('id')),
          ),
        ],
      ],
    );
  }

  Future<void> _openInvoicePdf(BuildContext context, String id) async {
    try {
      await api.openFile('/api/subscription-invoices/$id/pdf?download=1');
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.message, error: true);
    }
  }
}
