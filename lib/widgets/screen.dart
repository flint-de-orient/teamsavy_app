import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/api.dart';
import '../core/json.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/tokens.dart';
import 'button.dart';
import 'layout.dart';

/// Page padding inside the shell (web `main`: `px-3 py-4 sm:px-6`).
const kPagePadding = EdgeInsets.fromLTRB(16, 16, 16, 32);

/// A scrolling page body with pull-to-refresh and the standard padding.
class PageScroll extends StatelessWidget {
  const PageScroll({super.key, required this.children, this.onRefresh, this.padding = kPagePadding, this.gap = 16});
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      padding: padding,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [Gap(gap: gap, children: children)],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(
      onRefresh: onRefresh!,
      color: Ts.of(context).accentViolet,
      backgroundColor: Ts.of(context).surface,
      child: list,
    );
  }
}

/// Loads one mobile API endpoint and renders it, with loading, error,
/// pull-to-refresh, and automatic reload after any mutation anywhere in the
/// app (via [refreshBus]).
///
/// ```dart
/// ApiScreen(
///   path: '/attendance/my',
///   builder: (context, data, reload) => [PageHeader(...), ...],
/// )
/// ```
class ApiScreen extends StatefulWidget {
  const ApiScreen({
    super.key,
    required this.path,
    this.query,
    required this.builder,
    this.header,
    this.gap = 16,
    this.padding = kPagePadding,
  });

  final String path;
  final Map<String, Object?>? query;

  /// Builds the page's children from the response.
  final List<Widget> Function(BuildContext context, Json data, Future<void> Function() reload) builder;

  /// Shown above the loading/error states so the page title appears
  /// immediately (usually the PageHeader).
  final Widget? header;
  final double gap;
  final EdgeInsets padding;

  @override
  State<ApiScreen> createState() => _ApiScreenState();
}

class _ApiScreenState extends State<ApiScreen> {
  Json? _data;
  ApiException? _error;
  bool _loading = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    _load();
    refreshBus.addListener(_onBus);
  }

  @override
  void didUpdateWidget(covariant ApiScreen old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path || !_sameQuery(old.query, widget.query)) {
      _load(showSpinner: true);
    }
  }

  bool _sameQuery(Map<String, Object?>? a, Map<String, Object?>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (final k in a.keys) {
      if (a[k]?.toString() != b[k]?.toString()) return false;
    }
    return true;
  }

  @override
  void dispose() {
    refreshBus.removeListener(_onBus);
    super.dispose();
  }

  void _onBus() {
    if (mounted) _load();
  }

  Future<void> _load({bool showSpinner = false}) async {
    final seq = ++_seq;
    if (showSpinner && mounted) setState(() => _loading = true);
    try {
      final data = await api.getJson(widget.path, query: widget.query);
      if (!mounted || seq != _seq) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _seq) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data != null && (_error == null || _error!.code == 'network')) {
      return PageScroll(
        onRefresh: _load,
        padding: widget.padding,
        gap: widget.gap,
        children: [
          if (_error != null) StatusMessage(_error!.message, kind: StatusKind.warning, boxed: true),
          ...widget.builder(context, data, _load),
        ],
      );
    }
    return PageScroll(
      onRefresh: _load,
      padding: widget.padding,
      children: [
        if (widget.header != null) widget.header!,
        if (_loading && _error == null)
          const LoadingBlock()
        else if (_error != null)
          ErrorBlock(error: _error!, onRetry: () => _load(showSpinner: true)),
      ],
    );
  }
}

/// Shimmering placeholder cards while a page loads.
class LoadingBlock extends StatefulWidget {
  const LoadingBlock({super.key, this.count = 3});
  final int count;

  @override
  State<LoadingBlock> createState() => _LoadingBlockState();
}

class _LoadingBlockState extends State<LoadingBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final color = Color.lerp(p.surfaceHover, p.surface, _c.value)!;
        Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(color: p.surfaceHover, borderRadius: BorderRadius.circular(999)),
        );
        return Gap(
          gap: 12,
          children: [
            for (var i = 0; i < widget.count; i++)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(Ts.r3xl),
                  border: Border.all(color: p.glassBorder),
                  boxShadow: p.shadowCard,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(140, 14),
                    const SizedBox(height: 14),
                    bar(double.infinity, 10),
                    const SizedBox(height: 10),
                    bar(200, 10),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Error state with a retry button. 403s read as "not available".
class ErrorBlock extends StatelessWidget {
  const ErrorBlock({super.key, required this.error, required this.onRetry});
  final ApiException error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final forbidden = error.status == 403;
    final notFound = error.status == 404;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: p.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(Ts.r3xl),
        border: Border.all(color: p.glassBorder),
        boxShadow: p.shadowCard,
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: forbidden ? p.warningLight : p.dangerLight,
              borderRadius: BorderRadius.circular(Ts.r2xl),
            ),
            child: Icon(
              forbidden ? LucideIcons.lock : (notFound ? LucideIcons.searchX : LucideIcons.wifiOff),
              color: forbidden ? p.warning : p.danger,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            forbidden ? 'Not available' : (notFound ? 'Not found' : "Couldn't load this page"),
            style: tx(16, weight: FontWeight.w700, color: p.foreground, tracking: kTight),
          ),
          const SizedBox(height: 6),
          Text(error.message, textAlign: TextAlign.center, style: tx(14, color: p.muted, height: 1.5)),
          if (!forbidden && !notFound) ...[
            const SizedBox(height: 16),
            TsButton.secondary(label: 'Try Again', icon: LucideIcons.refreshCw, onPressed: onRetry),
          ],
          if (forbidden || notFound) ...[
            const SizedBox(height: 16),
            TsButton.secondary(
              label: 'Go Home',
              icon: LucideIcons.house,
              onPressed: () => context.go(session.me?.homePath ?? '/leave'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions

/// Snackbar toast.
void toast(BuildContext context, String message, {bool error = false}) {
  final p = Ts.of(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? LucideIcons.circleAlert : LucideIcons.circleCheck,
              size: 18,
              color: error ? p.danger : p.success,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// `window.confirm` equivalent.
Future<bool> confirmDialog(
  BuildContext context, {
  required String message,
  String title = 'Are you sure?',
  String confirmLabel = 'Continue',
  bool danger = false,
}) async {
  final p = Ts.of(context);
  final ok = await showDialog<bool>(
    context: context,
    builder:
        (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TsButton.ghost(label: 'Cancel', compact: true, onPressed: () => Navigator.pop(ctx, false)),
            danger
                ? TsButton.danger(label: confirmLabel, compact: true, onPressed: () => Navigator.pop(ctx, true))
                : TsButton(label: confirmLabel, compact: true, onPressed: () => Navigator.pop(ctx, true)),
          ],
          backgroundColor: p.surface,
        ),
  );
  return ok ?? false;
}

/// After a successful action the web app redirect()s somewhere. In the
/// app: if that's the page underneath, pop back to it; if it's this page,
/// stay; otherwise replace this page with the target.
void followRedirect(BuildContext context, String target) {
  final router = GoRouter.of(context);
  final current = router.state.uri;
  final targetUri = Uri.parse(target);
  if (targetUri.path == current.path) return;
  final stack = locationStack(router);
  if (stack.length >= 2 && Uri.parse(stack[stack.length - 2]).path == targetUri.path) {
    router.pop();
    return;
  }
  if (router.canPop()) {
    router.pushReplacement(target);
  } else {
    router.go(target);
  }
}

/// The URIs of every page currently on the navigation stack, bottom first.
List<String> locationStack(GoRouter router) {
  final out = <String>[];
  void walk(RouteMatchList list) {
    if (out.isEmpty || out.last != list.uri.toString()) out.add(list.uri.toString());
    void visit(List<RouteMatchBase> matches) {
      for (final m in matches) {
        if (m is ImperativeRouteMatch) {
          walk(m.matches);
        } else if (m is ShellRouteMatch) {
          visit(m.matches);
        }
      }
    }

    visit(list.matches);
  }

  walk(router.routerDelegate.currentConfiguration);
  return out;
}

/// Runs an action with the standard outcome handling: bumps the refresh
/// bus on success, follows the web's redirect unless [followRedirects] is
/// false, and toasts [successToast] (or the action's own message).
Future<ActionResult> runAction(
  BuildContext context,
  Future<ActionResult> Function() run, {
  String? successToast,
  bool followRedirects = true,
  bool toastErrors = false,
}) async {
  final result = await run();
  if (!context.mounted) return result;
  if (result.ok) {
    refreshBus.bump();
    final msg = successToast ?? result.message;
    if (msg != null) toast(context, msg);
    if (followRedirects && result.redirect != null) followRedirect(context, result.redirect!);
  } else if (toastErrors) {
    toast(context, result.error!, error: true);
  }
  return result;
}

/// A self-contained button for one-shot actions (Approve, Mark Reviewed,
/// Deactivate...): shows its own pending label and any error beneath it.
class ActionButton extends StatefulWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.run,
    this.pendingLabel,
    this.variant = TsButtonVariant.primary,
    this.confirm,
    this.confirmTitle,
    this.confirmLabel,
    this.successToast,
    this.onDone,
    this.expand = false,
    this.compact = false,
    this.icon,
    this.followRedirects = true,
  });

  final String label;
  final String? pendingLabel;
  final Future<ActionResult> Function() run;
  final TsButtonVariant variant;

  /// If set, asks this first (the web's window.confirm text).
  final String? confirm;
  final String? confirmTitle;
  final String? confirmLabel;
  final String? successToast;
  final void Function(ActionResult result)? onDone;
  final bool expand;
  final bool compact;
  final IconData? icon;
  final bool followRedirects;

  @override
  State<ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<ActionButton> {
  bool _pending = false;
  String? _error;

  Future<void> _go() async {
    if (widget.confirm != null) {
      final ok = await confirmDialog(
        context,
        message: widget.confirm!,
        title: widget.confirmTitle ?? 'Are you sure?',
        confirmLabel: widget.confirmLabel ?? widget.label,
        danger: widget.variant == TsButtonVariant.danger,
      );
      if (!ok || !mounted) return;
    }
    setState(() {
      _pending = true;
      _error = null;
    });
    final r = await runAction(
      context,
      widget.run,
      successToast: widget.successToast,
      followRedirects: widget.followRedirects,
    );
    if (!mounted) return;
    setState(() {
      _pending = false;
      _error = r.error;
    });
    widget.onDone?.call(r);
  }

  @override
  Widget build(BuildContext context) {
    final button = TsButton(
      label: widget.label,
      pendingLabel: widget.pendingLabel,
      pending: _pending,
      variant: widget.variant,
      onPressed: _go,
      expand: widget.expand,
      compact: widget.compact,
      icon: widget.icon,
    );
    if (_error == null) return button;
    return Column(
      crossAxisAlignment: widget.expand ? CrossAxisAlignment.stretch : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [button, const SizedBox(height: 6), Text(_error!, style: tx(12, color: Ts.of(context).danger))],
    );
  }
}
