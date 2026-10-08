import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/tokens.dart';

enum CardTone { primary, success, info, purple, warning }

/// components/ui/Card.tsx: a large glassy card - `rounded-3xl`, white/70
/// hairline, surface at 80% with a backdrop blur, `shadow-card`, `p-5`.
/// With a [tone] the whole card becomes that pastel and the icon badge goes
/// solid (stat/metric cards).
class TsCard extends StatelessWidget {
  const TsCard({
    super.key,
    this.title,
    this.description,
    this.icon,
    this.tone,
    this.action,
    this.padding = const EdgeInsets.all(20),
    this.child,
    this.onTap,
  });

  final String? title;
  final String? description;
  final IconData? icon;
  final CardTone? tone;
  final Widget? action;
  final EdgeInsets padding;
  final Widget? child;
  final VoidCallback? onTap;

  static Color toneBg(TsPalette p, CardTone t) => switch (t) {
    CardTone.primary => p.primaryLight,
    CardTone.success => p.successLight,
    CardTone.info => p.infoLight,
    CardTone.purple => p.purpleLight,
    CardTone.warning => p.warningLight,
  };

  static Color toneSolid(TsPalette p, CardTone t) => switch (t) {
    CardTone.primary => p.primary,
    CardTone.success => p.success,
    CardTone.info => p.info,
    CardTone.purple => p.purple,
    CardTone.warning => p.warning,
  };

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final hasHeader = title != null || action != null;

    Widget? iconBox;
    if (icon != null) {
      final t = tone;
      iconBox = Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Ts.rXl),
          gradient: t == CardTone.primary ? p.gradientPrimary : null,
          color: t == null ? p.primaryLight : (t == CardTone.primary ? null : toneSolid(p, t)),
          boxShadow: t == CardTone.primary ? p.shadowButton : null,
        ),
        child: Icon(
          icon,
          size: 16,
          color: t == null ? p.primary : (t == CardTone.primary ? p.primaryForeground : Colors.white),
        ),
      );
    }

    final body = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasHeader)
            Padding(
              padding: EdgeInsets.only(bottom: child == null ? 0 : 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (iconBox != null) ...[iconBox, const SizedBox(width: 12)],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (title != null)
                          Padding(
                            padding: EdgeInsets.only(top: iconBox != null ? 2 : 0),
                            child: Text(
                              title!,
                              style: tx(14, weight: FontWeight.w700, color: p.foreground, tracking: kTight),
                            ),
                          ),
                        if (description != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(description!, style: tx(12, color: p.muted)),
                          ),
                      ],
                    ),
                  ),
                  if (action != null) ...[const SizedBox(width: 12), action!],
                ],
              ),
            ),
          if (child != null) child!,
        ],
      ),
    );

    final radius = BorderRadius.circular(Ts.r3xl);
    final t = tone;
    Widget card;
    if (t != null) {
      card = Container(
        decoration: BoxDecoration(color: toneBg(p, t), borderRadius: radius, boxShadow: p.shadowCard),
        child: body,
      );
    } else {
      card = Container(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: p.shadowCard),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              decoration: BoxDecoration(
                color: p.glassFill,
                borderRadius: radius,
                border: Border.all(color: p.glassBorder),
              ),
              child: body,
            ),
          ),
        ),
      );
    }
    if (onTap == null) return card;
    return _Pressable(onTap: onTap!, radius: radius, child: card);
  }
}

/// The dashboard's StatCard: a toned Card whose body is one big number.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.tone,
    required this.icon,
    this.onTap,
  });
  final String label;
  final String value;
  final CardTone tone;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return TsCard(
      tone: tone,
      title: label,
      icon: icon,
      onTap: onTap,
      child: Text(value, style: tx(24, weight: FontWeight.w800, color: p.foreground, tracking: kTight)),
    );
  }
}

/// Plain bordered box (`rounded-2xl border border-border bg-surface p-4`)
/// used for list rows, inline editors and sub-panels.
class TsPanel extends StatelessWidget {
  const TsPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.radius = Ts.r2xl,
    this.onTap,
    this.borderColor,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? p.border),
        boxShadow: p.shadowXs,
      ),
      child: child,
    );
    if (onTap == null) return box;
    return _Pressable(onTap: onTap!, radius: BorderRadius.circular(radius), child: box);
  }
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.radius, required this.child});
  final VoidCallback onTap;
  final BorderRadius radius;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(scale: _down ? 0.99 : 1, duration: const Duration(milliseconds: 120), child: widget.child),
    );
  }
}

/// Wraps any widget in the press-to-scale feedback cards use.
class Pressable extends StatelessWidget {
  const Pressable({super.key, required this.onTap, required this.child, this.radius = Ts.r3xl});
  final VoidCallback onTap;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => _Pressable(onTap: onTap, radius: BorderRadius.circular(radius), child: child);
}
