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
///
/// MAX SEATS / PENDING PLAN CHANGE - added alongside the web app's own
/// billing-panel.tsx rewrite:
///   - The seat count is now an admin-typed "Max Seats" value, not the live
///     active-employee count (lib/billing/seats.ts) - this screen computes
///     GST-inclusive pricing on-device (billing_pricing.dart, a hand-synced
///     Dart port of lib/billing/gst.ts + lib/billing/money.ts) as the admin
///     edits the Max Seats field, exactly like the web client does.
///   - A plan/cycle switch against a UPI-funded mandate can't be updated
///     in place (Razorpay rejects it outright) - changeSubscriptionPlan
///     instead stages a brand-new Razorpay Subscription and returns the
///     same checkoutSubscriptionId/checkoutKeyId shape the first-time
///     Subscribe flow uses, which this screen now detects and opens
///     Checkout for, same as web's "Plan Change In Progress" card
///     (resumePendingPlanChange/cancelPendingPlanChange).
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

  // Max Seats - lazily defaulted once from the loaded data (seatsUsed, or
  // the live subscription's maxSeats while managing an existing one), then
  // left entirely under the admin's control so it survives this screen's
  // own setState() calls (pending/error changes) without resetting their
  // typing. A fresh instance of this screen (e.g. re-navigating to it)
  // starts over, which is correct - there is no "pick up where you left
  // off" expectation for an unsubmitted seat count.
  int? _seats;
  TextEditingController? _seatsController;

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
    _seatsController?.dispose();
    super.dispose();
  }

  void _ensureSeats(int defaultSeats) {
    if (_seats != null) return;
    _seats = defaultSeats;
    _seatsController = TextEditingController(text: '$defaultSeats');
  }

  void _onSeatsChanged(String value, int minSeats) {
    final parsed = int.tryParse(value);
    setState(() => _seats = (parsed == null || parsed < minSeats) ? minSeats : parsed);
  }

  void _onPaymentSuccess(PaymentSuccessResponse response) {
    if (!mounted) return;
    setState(() {
      _confirming = true;
      _pendingKey = null;
    });
    if (kDebugMode) {
      debugPrint('[billing] checkout success, native subscription id: ${response.data?['razorpay_subscription_id']}');
    }
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
      _error = response.code == Razorpay.PAYMENT_CANCELLED ? null : (response.message ?? 'Payment failed. Try again.');
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

  /// Opens Razorpay Checkout on an already-created/staged subscription -
  /// shared by first-time subscribe, resume-abandoned-checkout, and the
  /// UPI-fallback re-authentication path (web's useCheckout hook).
  void _openCheckout({
    required String subscriptionId,
    required String keyId,
    required String description,
    required Future<void> Function() reload,
  }) {
    _reload = reload;
    _razorpay.open({
      'key': keyId,
      // See this file's header comment: subscription_id (not order_id or
      // amount) for subscription-mode checkout - Razorpay determines the
      // mandate-setup amount server-side from the Subscription itself.
      'subscription_id': subscriptionId,
      'name': 'TeamSavy',
      'description': description,
      'prefill': {'name': session.me?.name ?? '', 'email': session.me?.email ?? ''},
      'theme': {'color': '#6d28d9'},
    });
  }

  Future<void> _subscribe(String planId, String cycle, String planName, int seats, Future<void> Function() reload) async {
    final cycleLabel = cycle == 'MONTHLY' ? 'monthly' : 'annually';
    final confirmed = await confirmDialog(
      context,
      title: 'Subscribe?',
      message: "Subscribe to $planName for $seats seat(s), billed $cycleLabel? You'll be taken to Razorpay to set up "
          'automatic payments.',
      confirmLabel: 'Subscribe',
    );
    if (!confirmed) return;
    setState(() {
      _pendingKey = '$planId:$cycle';
      _error = null;
    });
    final r = await api.action(
      'billing.initiateSubscriptionCheckout',
      fields: {'planId': planId, 'billingCycle': cycle, 'maxSeats': '$seats'},
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
    _openCheckout(
      subscriptionId: subscriptionId,
      keyId: keyId,
      description: '$planName - ${cycle == 'MONTHLY' ? 'Monthly' : 'Annual'}',
      reload: reload,
    );
  }

  Future<void> _switchPlan(String planId, String cycle, String planName, int seats, Future<void> Function() reload) async {
    final cycleLabel = cycle == 'MONTHLY' ? 'monthly' : 'annually';
    final confirmed = await confirmDialog(
      context,
      title: 'Switch plan?',
      message: 'Switch to $planName for $seats seat(s), billed $cycleLabel? This takes effect immediately - you\'ll '
          'be charged (or credited) a prorated amount for the rest of this billing period. If your payment method '
          "doesn't support automatic updates, you'll instead be asked to re-authorize payment via Razorpay before the "
          'switch completes.',
      confirmLabel: 'Switch Plan',
    );
    if (!confirmed) return;
    setState(() {
      _pendingKey = '$planId:$cycle';
      _error = null;
    });
    final r = await api.action(
      'billing.changeSubscriptionPlan',
      fields: {'planId': planId, 'billingCycle': cycle, 'maxSeats': '$seats'},
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
    setState(() => _pendingKey = null);
    if (subscriptionId != null && keyId != null) {
      // UPI-mandate fallback - a brand-new subscription was staged and
      // needs authorizing, same as a first-time subscribe.
      _openCheckout(
        subscriptionId: subscriptionId,
        keyId: keyId,
        description: '$planName - ${cycle == 'MONTHLY' ? 'Monthly' : 'Annual'}',
        reload: reload,
      );
      return;
    }
    await reload();
    if (mounted) toast(context, 'Plan updated.');
  }

  Future<void> _resumeCheckout(Json subscription, Future<void> Function() reload) async {
    setState(() {
      _pendingKey = 'resume-checkout';
      _error = null;
    });
    final r = await api.action(
      'billing.initiateSubscriptionCheckout',
      fields: {
        'planId': subscription.s('planId'),
        'billingCycle': subscription.s('billingCycle'),
        'maxSeats': '${subscription.iN('maxSeats') ?? 1}',
      },
    );
    if (!mounted) return;
    setState(() => _pendingKey = null);
    if (!r.ok) {
      setState(() => _error = r.error);
      return;
    }
    final subscriptionId = r.data?.sn('checkoutSubscriptionId');
    final keyId = r.data?.sn('checkoutKeyId');
    if (subscriptionId == null || keyId == null) {
      setState(() => _error = "Couldn't resume checkout. Try again.");
      return;
    }
    final cycle = subscription.s('billingCycle');
    _openCheckout(
      subscriptionId: subscriptionId,
      keyId: keyId,
      description: '${subscription.s('planName')} - ${cycle == 'MONTHLY' ? 'Monthly' : 'Annual'}',
      reload: reload,
    );
  }

  Future<void> _resumePendingPlanChange(Json subscription, Future<void> Function() reload) async {
    setState(() {
      _pendingKey = 'resume-pending';
      _error = null;
    });
    final r = await api.action('billing.resumePendingPlanChange', fields: const {});
    if (!mounted) return;
    setState(() => _pendingKey = null);
    if (!r.ok) {
      setState(() => _error = r.error);
      return;
    }
    final subscriptionId = r.data?.sn('checkoutSubscriptionId');
    final keyId = r.data?.sn('checkoutKeyId');
    if (subscriptionId == null || keyId == null) {
      setState(() => _error = "Couldn't resume checkout. Try again.");
      return;
    }
    final cycle = subscription.sn('pendingBillingCycle');
    _openCheckout(
      subscriptionId: subscriptionId,
      keyId: keyId,
      description: '${subscription.s('pendingPlanName')} - ${cycle == 'MONTHLY' ? 'Monthly' : 'Annual'}',
      reload: reload,
    );
  }

  Future<void> _cancelPendingPlanChange(Json subscription, Future<void> Function() reload) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Cancel this change?',
      message: 'Cancel switching to ${subscription.s('pendingPlanName')}? Your current plan '
          '(${subscription.s('planName')}) will stay exactly as it is.',
      confirmLabel: 'Cancel This Change',
      danger: true,
    );
    if (!confirmed) return;
    setState(() {
      _pendingKey = 'cancel-pending';
      _error = null;
    });
    final r = await api.action('billing.cancelPendingPlanChange', fields: const {});
    if (!mounted) return;
    setState(() => _pendingKey = null);
    if (!r.ok) {
      setState(() => _error = r.error);
      return;
    }
    await reload();
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
    setState(() {
      _pendingKey = 'cancel';
      _error = null;
    });
    final r = await api.action('billing.cancelSubscription', fields: const {});
    if (!mounted) return;
    setState(() => _pendingKey = null);
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
        final seatsUsed = data.i('seatsUsed');
        final invoices = data.l('invoices');
        final hasRazorpaySubscription = subscription?.b('hasRazorpaySubscription') ?? false;
        final isAuthenticated = subscription?.b('isAuthenticated') ?? false;
        final pendingPlanName = subscription?.sn('pendingPlanName');
        final minSeats = seatsUsed < 1 ? 1 : seatsUsed;
        final managingExisting = hasRazorpaySubscription && isAuthenticated;
        final defaultSeats = managingExisting ? (subscription?.iN('maxSeats') ?? minSeats) : minSeats;
        _ensureSeats(defaultSeats < minSeats ? minSeats : defaultSeats);
        final seats = (_seats! < minSeats) ? minSeats : _seats!;
        final canSubscribe = seatsUsed >= 1;

        Widget planSection({required String heading}) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(heading),
              if (!canSubscribe)
                TsPanel(
                  color: Ts.of(context).warningLight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add your first employee before setting up billing.',
                          style: tx(14, weight: FontWeight.w600, color: Ts.of(context).warning)),
                      const SizedBox(height: 4),
                      const Muted('Subscriptions are billed per seat, so there must be at least one before checkout can start.'),
                    ],
                  ),
                )
              else
                _SeatsInput(
                  controller: _seatsController!,
                  minSeats: minSeats,
                  onChanged: (v) => _onSeatsChanged(v, minSeats),
                ),
              const SizedBox(height: 4),
              for (final plan in plans)
                _PlanCard(
                  plan: plan,
                  seats: seats,
                  isCurrent: managingExisting && subscription?.sn('planId') == plan.sn('id'),
                  currentCycle: subscription?.sn('billingCycle'),
                  currentMaxSeats: subscription?.iN('maxSeats'),
                  canSubscribe: canSubscribe,
                  managingExisting: managingExisting,
                  pendingKey: _pendingKey,
                  onChoose: (cycle) => managingExisting
                      ? _switchPlan(plan.s('id'), cycle, plan.s('name'), seats, reload)
                      : _subscribe(plan.s('id'), cycle, plan.s('name'), seats, reload),
                ),
            ],
          );
        }

        return [
          const PageHeader(title: 'Billing', description: 'Your subscription, plan, and invoice history.'),
          _StatusCard(subscription: subscription, seatsUsed: seatsUsed),
          if (_confirming)
            const StatusMessage(
              'Payment received - activating your subscription. This usually takes a few seconds.',
              kind: StatusKind.info,
              boxed: true,
            ),
          if (_error != null) StatusMessage.error(_error),
          if (!hasRazorpaySubscription)
            planSection(heading: 'Choose a Plan')
          else if (!isAuthenticated) ...[
            _ResumeCheckoutCard(
              subscription: subscription!,
              pending: _pendingKey == 'resume-checkout',
              onResume: () => _resumeCheckout(subscription, reload),
            ),
            planSection(heading: 'Or Choose a Different Plan'),
          ] else ...[
            if (pendingPlanName != null)
              _PendingPlanChangeCard(
                subscription: subscription!,
                resumePending: _pendingKey == 'resume-pending',
                cancelPending: _pendingKey == 'cancel-pending',
                onResume: () => _resumePendingPlanChange(subscription, reload),
                onCancel: () => _cancelPendingPlanChange(subscription, reload),
              ),
            planSection(heading: 'Change Plan'),
            if (subscription?.sn('status') != 'CANCELED')
              MobileCard(
                children: [
                  const MobileCardHeader(title: 'Cancel Subscription'),
                  const Muted(
                    "Cancels at the end of your current billing period - you keep access until then, and it won't renew afterward.",
                  ),
                  const SizedBox(height: 10),
                  TsButton.danger(
                    label: 'Cancel Subscription',
                    pending: _pendingKey == 'cancel',
                    onPressed: () => _cancel(subscription?.sn('currentPeriodEnd'), reload),
                  ),
                ],
              ),
          ],
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

class _SeatsInput extends StatelessWidget {
  const _SeatsInput({required this.controller, required this.minSeats, required this.onChanged});
  final TextEditingController controller;
  final int minSeats;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TsInput(
      controller: controller,
      label: 'Max Seats',
      keyboardType: TextInputType.number,
      inputFormatters: TsInput.digitsOnly,
      onChanged: onChanged,
      hint: 'You currently have $minSeats active seat${minSeats == 1 ? '' : 's'} in use (employees + admin/HR '
          'logins) - set this higher to leave room to grow.',
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.subscription, required this.seatsUsed});
  final Json? subscription;
  final int seatsUsed;

  @override
  Widget build(BuildContext context) {
    if (subscription == null) {
      return MobileCard(children: const [Muted('No billing record was found for your organization.')]);
    }
    final status = subscription!.s('status');
    final trialEndsAt = subscription!.sn('trialEndsAt');
    final currentPeriodEnd = subscription!.sn('currentPeriodEnd');
    final maxSeats = subscription!.iN('maxSeats') ?? seatsUsed;
    final tone = status == 'ACTIVE'
        ? BadgeTone.green
        : status == 'PAST_DUE'
            ? BadgeTone.red
            : status == 'CANCELED'
                ? BadgeTone.slate
                : BadgeTone.amber;

    final periodEndDate = currentPeriodEnd == null ? null : DateTime.tryParse(currentPeriodEnd);
    final periodStillOpen = periodEndDate != null && periodEndDate.isAfter(DateTime.now());

    return MobileCard(
      children: [
        MobileCardHeader(
          title: subscription!.s('planName'),
          subtitle: subscription!.s('billingCycle') == 'MONTHLY' ? 'Billed monthly' : 'Billed annually',
          action: TsBadge(_statusLabel[status] ?? status, tone: tone),
        ),
        Muted('Using $seatsUsed of $maxSeats seat${maxSeats == 1 ? '' : 's'} - every active employee and every '
            'admin/HR login counts as one seat.'),
        if (status == 'TRIALING' && trialEndsAt != null) ...[
          const SizedBox(height: 10),
          StatusMessage.warning('Your free trial ends ${fmtDateMedium(trialEndsAt)}. Subscribe below to keep access.'),
        ],
        if (status == 'PAST_DUE') ...[
          const SizedBox(height: 10),
          const StatusMessage(
            'Your last payment failed - access is restricted immediately. Razorpay will keep retrying the charge '
            'automatically; access is restored the moment a retry succeeds.',
            kind: StatusKind.error,
            boxed: true,
          ),
        ],
        if (status == 'CANCELED') ...[
          const SizedBox(height: 10),
          Muted(periodStillOpen
              ? 'This subscription has been canceled. You keep access through ${fmtDateMedium(currentPeriodEnd)} '
                  '(the period you already paid for), then access is restricted unless you subscribe again.'
              : 'This subscription has been canceled. Access is restricted. Subscribe again below to restore it.'),
        ],
      ],
    );
  }
}

class _ResumeCheckoutCard extends StatelessWidget {
  const _ResumeCheckoutCard({required this.subscription, required this.pending, required this.onResume});
  final Json subscription;
  final bool pending;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return MobileCard(
      children: [
        const MobileCardHeader(title: 'Finish setting up payment'),
        Muted("You started checkout for ${subscription.s('planName')} but it wasn't completed - the payment window "
            'may have been closed before setup finished. No charge was made. Resume to try again.'),
        const SizedBox(height: 10),
        TsButton(label: 'Resume Checkout', pending: pending, onPressed: onResume),
      ],
    );
  }
}

class _PendingPlanChangeCard extends StatelessWidget {
  const _PendingPlanChangeCard({
    required this.subscription,
    required this.resumePending,
    required this.cancelPending,
    required this.onResume,
    required this.onCancel,
  });
  final Json subscription;
  final bool resumePending;
  final bool cancelPending;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return MobileCard(
      children: [
        const MobileCardHeader(title: 'Plan Change In Progress'),
        Muted("You started switching to ${subscription.s('pendingPlanName')} but payment setup wasn't completed - "
            "your current plan, ${subscription.s('planName')}, is still active and billing normally. No charge has "
            'been made for the new plan yet.'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: TsButton(label: 'Resume Checkout', pending: resumePending, onPressed: onResume)),
            const SizedBox(width: 10),
            Expanded(child: TsButton.secondary(label: 'Cancel This Change', pending: cancelPending, onPressed: onCancel)),
          ],
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.seats,
    required this.isCurrent,
    required this.currentCycle,
    required this.currentMaxSeats,
    required this.canSubscribe,
    required this.managingExisting,
    required this.pendingKey,
    required this.onChoose,
  });
  final Json plan;
  final int seats;
  final bool isCurrent;
  final String? currentCycle;
  final int? currentMaxSeats;
  final bool canSubscribe;
  final bool managingExisting;
  final String? pendingKey;
  final void Function(String cycle) onChoose;

  @override
  Widget build(BuildContext context) {
    final planId = plan.s('id');
    final gstType = plan.s('gstType');
    final monthlyRate = plan.iN('monthlyRatePaise');
    final annualRate = plan.iN('annualRatePaise');
    final safeSeats = seats < 1 ? 1 : seats;

    String? monthlyPerSeat;
    String? monthlyTotal;
    if (monthlyRate != null) {
      monthlyPerSeat = formatPaiseAsRupees(computeGst(monthlyRate, gstType).totalAmount);
      monthlyTotal = formatPaiseAsRupees(computeGst(monthlyRate * safeSeats, gstType).totalAmount);
    }
    String? annualPerSeat;
    String? annualTotal;
    if (annualRate != null) {
      annualPerSeat = formatPaiseAsRupees(computeGst(annualRate, gstType).totalAmount);
      annualTotal = formatPaiseAsRupees(computeGst(annualChargePerEmployeePaise(annualRate) * safeSeats, gstType).totalAmount);
    }

    String labelFor(String cycle, bool sameAsCurrentCycle) {
      if (!managingExisting) {
        return cycle == 'MONTHLY' ? 'Subscribe monthly' : 'Subscribe annually';
      }
      if (sameAsCurrentCycle && seats == currentMaxSeats) {
        return cycle == 'MONTHLY' ? 'Current plan (monthly)' : 'Current plan (annual)';
      }
      if (sameAsCurrentCycle) return 'Update Seats';
      return cycle == 'MONTHLY' ? 'Switch to monthly' : 'Switch to annual';
    }

    bool disabledFor(bool sameAsCurrentCycle) {
      if (!canSubscribe) return true;
      return managingExisting && sameAsCurrentCycle && seats == currentMaxSeats;
    }

    return MobileCard(
      children: [
        MobileCardHeader(title: plan.s('name')),
        if (monthlyPerSeat != null)
          MobileCardRow(label: 'Monthly, per seat (incl. GST)', value: monthlyPerSeat, first: true),
        if (annualPerSeat != null) MobileCardRow(label: 'Annual, per seat/mo (incl. GST)', value: annualPerSeat),
        const SizedBox(height: 10),
        if (monthlyTotal != null)
          TsButton.secondary(
            label: '${labelFor('MONTHLY', isCurrent && currentCycle == 'MONTHLY')} ($monthlyTotal/mo for $safeSeats)',
            pending: pendingKey == '$planId:MONTHLY',
            onPressed: disabledFor(isCurrent && currentCycle == 'MONTHLY') ? null : () => onChoose('MONTHLY'),
          ),
        if (annualTotal != null) ...[
          const SizedBox(height: 8),
          TsButton(
            label: '${labelFor('ANNUAL', isCurrent && currentCycle == 'ANNUAL')} ($annualTotal/yr for $safeSeats)',
            pending: pendingKey == '$planId:ANNUAL',
            onPressed: disabledFor(isCurrent && currentCycle == 'ANNUAL') ? null : () => onChoose('ANNUAL'),
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
