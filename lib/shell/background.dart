import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/tokens.dart';

/// AppShell.tsx's page backdrop: the lavender base with three soft colour
/// washes - blue from the bottom-left, peach from the top-right, lavender
/// from the bottom-right - exactly the CSS radial-gradients:
/// `circle at 0% 100%, wash-blue 0, transparent 46%` etc.
class WashBackground extends StatelessWidget {
  const WashBackground({super.key, this.child});
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth.isFinite ? c.maxWidth : 400.0;
        final h = c.maxHeight.isFinite ? c.maxHeight : 800.0;
        // CSS `circle` = farthest-corner: from a corner, the full diagonal.
        // Flutter's radius is a fraction of the shortest side.
        final diag = math.sqrt(w * w + h * h);
        final shortest = math.min(w, h);
        RadialGradient wash(Alignment at, Color color, double stop) => RadialGradient(
          center: at,
          radius: diag / shortest,
          colors: [color, color.withValues(alpha: 0)],
          stops: [0, stop],
        );
        return DecoratedBox(
          decoration: BoxDecoration(color: p.background),
          child: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(decoration: BoxDecoration(gradient: wash(Alignment.bottomLeft, p.washBlue, 0.46))),
              DecoratedBox(decoration: BoxDecoration(gradient: wash(Alignment.topRight, p.washPeach, 0.40))),
              DecoratedBox(decoration: BoxDecoration(gradient: wash(Alignment.bottomRight, p.washLavender, 0.42))),
              if (child != null) child!,
            ],
          ),
        );
      },
    );
  }
}
