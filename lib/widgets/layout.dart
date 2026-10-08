import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/theme.dart';
import '../core/tokens.dart';
import 'badge.dart';
import 'card.dart';

/// components/ui/PageHeader.tsx at phone width: a 28px medium display
/// title (leading 1.05, tracking -0.02em), a 14px muted description, then
/// the action buttons wrapped underneath.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.description, this.actions = const [], this.eyebrow});
  final String title;
  final String? description;
  final List<Widget> actions;

  /// Optional small line above the title (e.g. a back-link label).
  final Widget? eyebrow;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: eyebrow!),
          Text(title, style: tx(28, weight: FontWeight.w500, color: p.foreground, height: 1.05, tracking: -0.02)),
          if (description != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(description!, style: tx(14, color: p.muted, height: 1.625)),
            ),
          if (actions.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 16), child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
        ],
      ),
    );
  }
}

/// An `<h2>` section title inside a page ("Daily Status", "Recent Punches").
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.description, this.action, this.top = 8});
  final String title;
  final String? description;
  final Widget? action;
  final double top;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: tx(18, weight: FontWeight.w700, color: p.foreground, tracking: kTight)),
                if (description != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(description!, style: tx(14, color: p.muted, height: 1.5)),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// Vertical stack with uniform gaps (Tailwind `flex flex-col gap-N`).
class Gap extends StatelessWidget {
  const Gap({super.key, required this.children, this.gap = 16, this.crossAxisAlignment = CrossAxisAlignment.stretch});
  final List<Widget> children;
  final double gap;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (final c in children) {
      if (items.isNotEmpty) items.add(SizedBox(height: gap));
      items.add(c);
    }
    return Column(crossAxisAlignment: crossAxisAlignment, mainAxisSize: MainAxisSize.min, children: items);
  }
}

/// The form `Section` fieldset: `rounded-lg border p-5` with a 14px
/// semibold legend sitting on the top border.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.title, required this.children, this.gap = 16});
  final String title;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(
            color: p.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(Ts.r2xl),
            border: Border.all(color: p.border),
          ),
          child: Gap(gap: gap, children: children),
        ),
        Positioned(
          left: 14,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            color: p.background,
            child: Text(title, style: tx(14, weight: FontWeight.w600, color: p.foreground)),
          ),
        ),
      ],
    );
  }
}

/// A detail page's `Row`: muted label above the value (phone layout of the
/// web's 1/3 + 2/3 `<dl>` grid), bottom border between rows, `py-2`.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, this.value, this.child, this.last = false});
  final String label;
  final String? value;
  final Widget? child;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: p.border))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: tx(14, color: p.muted)),
          const SizedBox(height: 2),
          child ?? Text(value == null || value!.isEmpty ? '—' : value!, style: tx(14, color: p.foreground)),
        ],
      ),
    );
  }
}

/// A list of [DetailRow]s; marks the last one so it has no border.
class DetailList extends StatelessWidget {
  const DetailList({super.key, required this.rows});
  final List<DetailRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          i == rows.length - 1
              ? DetailRow(label: rows[i].label, value: rows[i].value, last: true, child: rows[i].child)
              : rows[i],
      ],
    );
  }
}

/// components/ui/MobileCard.tsx - one glass card per list row.
class MobileCard extends StatelessWidget {
  const MobileCard({super.key, required this.children, this.onTap});
  final List<Widget> children;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TsCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// MobileCardHeader: bold truncated title, optional badge/action at right.
class MobileCardHeader extends StatelessWidget {
  const MobileCardHeader({super.key, required this.title, this.action, this.subtitle});
  final String title;
  final Widget? action;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx(16, weight: FontWeight.w700, color: p.foreground, tracking: kTight),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: tx(12, color: p.muted)),
                  ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 12), action!],
        ],
      ),
    );
  }
}

/// MobileCardRow: muted label left, semibold value right, divider above
/// every row but the first.
class MobileCardRow extends StatelessWidget {
  const MobileCardRow({super.key, required this.label, this.value, this.child, this.first = false});
  final String label;
  final String? value;
  final Widget? child;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Container(
      padding: EdgeInsets.only(top: first ? 0 : 8, bottom: 8),
      decoration: BoxDecoration(border: first ? null : Border(top: BorderSide(color: p.border))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: tx(14, color: p.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child:
                  child ??
                  Text(
                    value == null || value!.isEmpty ? '—' : value!,
                    textAlign: TextAlign.right,
                    style: tx(14, weight: FontWeight.w600, color: p.foreground),
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rows for a MobileCard; the first row gets no top divider.
class MobileCardRows extends StatelessWidget {
  const MobileCardRows({super.key, required this.rows});
  final List<MobileCardRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++)
          MobileCardRow(label: rows[i].label, value: rows[i].value, first: i == 0, child: rows[i].child),
      ],
    );
  }
}

/// Footer area of a MobileCard (`border-t pt-3 mt-1`).
class MobileCardFooter extends StatelessWidget {
  const MobileCardFooter({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: p.border))),
      child: child,
    );
  }
}

/// MobileEmptyState: dashed `rounded-2xl` box with centered muted text.
class EmptyState extends StatelessWidget {
  const EmptyState(this.message, {super.key, this.icon});
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return CustomPaint(
      painter: _DashedBorderPainter(color: p.border, radius: Ts.r2xl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(Ts.r2xl),
        ),
        child: Column(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 22, color: p.muted.withValues(alpha: 0.7)),
              const SizedBox(height: 8),
            ],
            Text(message, textAlign: TextAlign.center, style: tx(14, color: p.muted)),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) => old.color != color;
}

enum StatusKind { error, success, warning, info, muted }

/// Inline action feedback: red `text-danger` error / green success line,
/// or the amber warning box (`bg-warning-light`).
class StatusMessage extends StatelessWidget {
  const StatusMessage(this.text, {super.key, this.kind = StatusKind.error, this.boxed = false});
  final String? text;
  final StatusKind kind;
  final bool boxed;

  factory StatusMessage.error(String? text) => StatusMessage(text, kind: StatusKind.error);
  factory StatusMessage.success(String? text) => StatusMessage(text, kind: StatusKind.success);
  factory StatusMessage.warning(String? text) => StatusMessage(text, kind: StatusKind.warning, boxed: true);

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) return const SizedBox.shrink();
    final p = Ts.of(context);
    final color = switch (kind) {
      StatusKind.error => p.danger,
      StatusKind.success => p.success,
      StatusKind.warning => p.warning,
      StatusKind.info => p.info,
      StatusKind.muted => p.muted,
    };
    if (!boxed) {
      return Text(text!, style: tx(14, color: color));
    }
    final bg = switch (kind) {
      StatusKind.error => p.dangerLight,
      StatusKind.success => p.successLight,
      StatusKind.warning => p.warningLight,
      StatusKind.info => p.infoLight,
      StatusKind.muted => p.surfaceHover,
    };
    final icon = switch (kind) {
      StatusKind.error => LucideIcons.circleAlert,
      StatusKind.success => LucideIcons.circleCheck,
      StatusKind.warning => LucideIcons.triangleAlert,
      _ => LucideIcons.info,
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Ts.r2xl),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text!, style: tx(14, color: p.dark ? color : p.foreground, height: 1.5))),
        ],
      ),
    );
  }
}

/// Muted paragraph (`text-sm text-muted`).
class Muted extends StatelessWidget {
  const Muted(this.text, {super.key, this.size = 14, this.align});
  final String text;
  final double size;
  final TextAlign? align;
  @override
  Widget build(BuildContext context) =>
      Text(text, textAlign: align, style: tx(size, color: Ts.of(context).muted, height: 1.5));
}

/// Text-link tabs (the web's `?tab=` / `?show=` links): the active one is
/// primary + bold. Rendered as a horizontally scrolling pill bar.
class LinkTabs<T> extends StatelessWidget {
  const LinkTabs({super.key, required this.value, required this.tabs, required this.onChanged});
  final T value;
  final List<(T, String)> tabs;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: p.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.glassBorder),
          boxShadow: p.shadowXs,
        ),
        child: Row(
          children: [
            for (final (v, label) in tabs)
              GestureDetector(
                onTap: () => onChanged(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: v == value ? p.gradientPrimary : null,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: v == value ? p.shadowButton : null,
                  ),
                  child: Text(
                    label,
                    style: tx(
                      13,
                      weight: v == value ? FontWeight.w700 : FontWeight.w500,
                      color: v == value ? p.primaryForeground : p.muted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Numbered page buttons (the web's 30-per-page pagination).
class Pagination extends StatelessWidget {
  const Pagination({super.key, required this.page, required this.pageCount, required this.onChanged});
  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    final p = Ts.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (var i = 1; i <= pageCount; i++)
          GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              constraints: const BoxConstraints(minWidth: 36),
              height: 36,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                gradient: i == page ? p.gradientPrimary : null,
                color: i == page ? null : p.surface,
                borderRadius: BorderRadius.circular(999),
                border: i == page ? null : Border.all(color: p.border),
              ),
              child: Text(
                '$i',
                style: tx(14, weight: FontWeight.w600, color: i == page ? p.primaryForeground : p.foreground),
              ),
            ),
          ),
      ],
    );
  }
}

/// A coloured status dot + label (sidebar-section style marker).
class DotLabel extends StatelessWidget {
  const DotLabel(this.label, {super.key, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: tx(12, color: p.muted)),
      ],
    );
  }
}

/// A wrap of badges with consistent spacing (flag badges on day rows).
class BadgeWrap extends StatelessWidget {
  const BadgeWrap(this.badges, {super.key});
  final List<TsBadge> badges;
  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: badges);
  }
}
