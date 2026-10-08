import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/tokens.dart';

enum BadgeTone { slate, amber, blue, green, red, purple }

BadgeTone badgeToneFrom(String? name) => switch (name) {
  'amber' => BadgeTone.amber,
  'blue' => BadgeTone.blue,
  'green' => BadgeTone.green,
  'red' => BadgeTone.red,
  'purple' => BadgeTone.purple,
  _ => BadgeTone.slate,
};

/// components/ui/Badge.tsx: a pastel pill with a 6px dot, 12px semibold,
/// `px-2.5 py-1`, and a 1px inset ring of the tone at 20%.
class TsBadge extends StatelessWidget {
  const TsBadge(this.label, {super.key, this.tone = BadgeTone.slate, this.dot = true});

  final String label;
  final BadgeTone tone;
  final bool dot;

  static (Color bg, Color fg, Color ring, Color dot) colors(TsPalette p, BadgeTone t) => switch (t) {
    BadgeTone.slate => (p.surfaceHover, p.muted, p.border, p.muted),
    BadgeTone.amber => (p.warningLight, p.warning, p.warning.withValues(alpha: 0.2), p.warning),
    BadgeTone.blue => (p.infoLight, p.info, p.info.withValues(alpha: 0.2), p.info),
    BadgeTone.green => (p.successLight, p.success, p.success.withValues(alpha: 0.2), p.success),
    BadgeTone.red => (p.dangerLight, p.danger, p.danger.withValues(alpha: 0.2), p.danger),
    BadgeTone.purple => (p.purpleLight, p.purple, p.purple.withValues(alpha: 0.2), p.purple),
  };

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final (bg, fg, ring, dotColor) = colors(p, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: ring)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(width: 6, height: 6, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx(12, weight: FontWeight.w600, color: fg, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }
}

/// The small "Inactive" / "Current" style pill without a dot.
class TsPill extends StatelessWidget {
  const TsPill(this.label, {super.key, this.tone = BadgeTone.slate});
  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) => TsBadge(label, tone: tone, dot: false);
}
