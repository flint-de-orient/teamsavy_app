import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/tokens.dart';

enum TsButtonVariant { primary, secondary, danger, ghost }

/// components/ui/Button.tsx: a full pill (`rounded-full`), min height 44,
/// `px-5 py-2.5`, 14px semibold tight text. Primary is the ink->violet
/// gradient with the tinted button shadow; while [pending] the label swaps
/// to [pendingLabel] and the button disables, exactly like the web's
/// useActionState pattern.
class TsButton extends StatefulWidget {
  const TsButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = TsButtonVariant.primary,
    this.pending = false,
    this.pendingLabel,
    this.icon,
    this.expand = false,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final TsButtonVariant variant;
  final bool pending;
  final String? pendingLabel;
  final IconData? icon;
  final bool expand;

  /// Smaller pill for inline row actions (min height 36).
  final bool compact;

  const TsButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.pending = false,
    this.pendingLabel,
    this.icon,
    this.expand = false,
    this.compact = false,
  }) : variant = TsButtonVariant.secondary;

  const TsButton.danger({
    super.key,
    required this.label,
    this.onPressed,
    this.pending = false,
    this.pendingLabel,
    this.icon,
    this.expand = false,
    this.compact = false,
  }) : variant = TsButtonVariant.danger;

  const TsButton.ghost({
    super.key,
    required this.label,
    this.onPressed,
    this.pending = false,
    this.pendingLabel,
    this.icon,
    this.expand = false,
    this.compact = false,
  }) : variant = TsButtonVariant.ghost;

  @override
  State<TsButton> createState() => _TsButtonState();
}

class _TsButtonState extends State<TsButton> {
  bool _down = false;

  bool get _enabled => widget.onPressed != null && !widget.pending;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final v = widget.variant;

    Color fg;
    BoxDecoration deco;
    switch (v) {
      case TsButtonVariant.primary:
        fg = p.primaryForeground;
        deco = BoxDecoration(
          gradient: p.gradientPrimary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: _enabled ? (_down ? p.shadowButtonHover : p.shadowButton) : null,
        );
      case TsButtonVariant.secondary:
        fg = p.foreground;
        deco = BoxDecoration(
          color: _down ? Color.alphaBlend(p.primaryLight.withValues(alpha: 0.6), p.surface) : p.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _down ? p.primary.withValues(alpha: 0.4) : p.border),
          boxShadow: p.shadowXs,
        );
      case TsButtonVariant.danger:
        fg = _down ? Colors.white : p.danger;
        deco = BoxDecoration(
          color: _down ? p.danger : p.dangerLight,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.danger.withValues(alpha: 0.25)),
        );
      case TsButtonVariant.ghost:
        fg = _down ? p.foreground : p.muted;
        deco = BoxDecoration(
          color: _down ? p.surfaceHover : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        );
    }

    final label = widget.pending ? (widget.pendingLabel ?? widget.label) : widget.label;
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.pending)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg)),
          )
        else if (widget.icon != null)
          Padding(padding: const EdgeInsets.only(right: 8), child: Icon(widget.icon, size: 16, color: fg)),
        Flexible(
          child: Text(
            label,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: tx(widget.compact ? 13 : 14, weight: FontWeight.w600, color: fg, tracking: kTight),
          ),
        ),
      ],
    );

    final disabledOpacity = v == TsButtonVariant.primary || v == TsButtonVariant.secondary ? 0.6 : 0.5;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: _enabled ? () => setState(() => _down = false) : null,
        onTapUp: _enabled ? (_) => setState(() => _down = false) : null,
        onTap: _enabled ? widget.onPressed : null,
        child: AnimatedScale(
          scale: _down ? 0.98 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedOpacity(
            opacity: widget.onPressed == null || widget.pending ? disabledOpacity : 1,
            duration: const Duration(milliseconds: 150),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              constraints: BoxConstraints(minHeight: widget.compact ? 36 : 44),
              padding: EdgeInsets.symmetric(horizontal: widget.compact ? 14 : 20, vertical: widget.compact ? 7 : 10),
              decoration: deco,
              alignment: widget.expand ? Alignment.center : null,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// A text link styled like the web's `text-sm font-medium text-primary`
/// links ("View all", "Request a fix", "Override").
class TsLink extends StatelessWidget {
  const TsLink(this.label, {super.key, this.onTap, this.size = 14, this.color, this.weight = FontWeight.w500});
  final String label;
  final VoidCallback? onTap;
  final double size;
  final Color? color;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(label, style: tx(size, weight: weight, color: color ?? p.primary)),
      ),
    );
  }
}

/// Square-ish icon button from the Topbar (`h-9 w-9 rounded-lg`).
class TsIconButton extends StatelessWidget {
  const TsIconButton({super.key, required this.icon, this.onTap, this.bordered = false, this.tooltip, this.size = 36});
  final IconData icon;
  final VoidCallback? onTap;
  final bool bordered;
  final String? tooltip;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final button = Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Ts.rLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Ts.rLg),
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration:
              bordered
                  ? BoxDecoration(borderRadius: BorderRadius.circular(Ts.rLg), border: Border.all(color: p.border))
                  : null,
          child: Icon(icon, size: bordered ? 16 : 20, color: p.muted),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
