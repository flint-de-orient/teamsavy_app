import 'dart:math' as math;

import '../../widgets/ts.dart';

/// STATUS_TONE / STATUS_LABEL / TYPE_LABEL, identical in every tasks and
/// KPI page on the web.
const taskStatusTone = <String, BadgeTone>{
  'ASSIGNED': BadgeTone.blue,
  'SUBMITTED': BadgeTone.amber,
  'SENT_BACK': BadgeTone.red,
  'VERIFIED': BadgeTone.green,
  'CANCELLED': BadgeTone.slate,
};

const taskStatusLabel = <String, String>{
  'ASSIGNED': 'Assigned',
  'SUBMITTED': 'Submitted',
  'SENT_BACK': 'Sent Back',
  'VERIFIED': 'Verified',
  'CANCELLED': 'Cancelled',
};

const taskTypeLabel = <String, String>{'AD_HOC': 'Ad-hoc', 'GOAL': 'Goal'};

String typeLabelOf(String type) => taskTypeLabel[type] ?? type;

class TaskStatusBadge extends StatelessWidget {
  const TaskStatusBadge(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) =>
      TsBadge(taskStatusLabel[status] ?? status, tone: taskStatusTone[status] ?? BadgeTone.slate);
}

/// The web's "← Previous" / "Next →" month links, as secondary buttons.
List<Widget> monthNavButtons({required VoidCallback onPrevious, required VoidCallback onNext}) => [
      TsButton.secondary(label: '← Previous', onPressed: onPrevious),
      TsButton.secondary(label: 'Next →', onPressed: onNext),
    ];

/// A KPI score drawn as a gradient ring that sweeps in from 12 o'clock.
/// [score] is 0..100 (null draws just the track); [label] is the web's
/// scoreLabel text shown in the middle.
class ScoreRing extends StatelessWidget {
  const ScoreRing({super.key, required this.score, required this.label, this.caption, this.size = 128, this.stroke = 12});
  final double? score;
  final String label;
  final String? caption;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final target = ((score ?? 0).clamp(0, 100)) / 100;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: value,
            stroke: stroke,
            track: p.dark ? p.surface : Colors.white.withValues(alpha: 0.8),
            colors: p.gradientPrimary.colors,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: tx(score == null ? 28 : 24, weight: FontWeight.w800, color: p.foreground, tracking: kTight)),
                if (caption != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(caption!, style: tx(11, weight: FontWeight.w500, color: p.muted)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.stroke, required this.track, required this.colors});
  final double progress;
  final double stroke;
  final Color track;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (progress <= 0.001) return;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: colors,
          endAngle: sweep,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.track != track || old.colors != colors || old.stroke != stroke;
}

/// A slim gradient progress bar for a 0..100 score (empty when null).
class ScoreBar extends StatelessWidget {
  const ScoreBar({super.key, required this.score, this.height = 6});
  final double? score;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final target = ((score ?? 0).clamp(0, 100)) / 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: p.surfaceHover,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target.toDouble()),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => FractionallySizedBox(
            widthFactor: value,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: p.gradientPrimary, borderRadius: BorderRadius.circular(999)),
            ),
          ),
        ),
      ),
    );
  }
}

/// This month's tasks split by status: a stacked bar plus a legend, using
/// the same status colours as the badges.
class TaskStatusBreakdown extends StatelessWidget {
  const TaskStatusBreakdown({super.key, required this.statuses});
  final List<String> statuses;

  @override
  Widget build(BuildContext context) {
    final p = Ts.of(context);
    final counts = <String, int>{};
    for (final s in statuses) {
      counts[s] = (counts[s] ?? 0) + 1;
    }
    final order = taskStatusLabel.keys.where(counts.containsKey).toList();
    Color colorOf(String s) => TsBadge.colors(p, taskStatusTone[s] ?? BadgeTone.slate).$2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                for (var i = 0; i < order.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(flex: counts[order[i]]!, child: ColoredBox(color: colorOf(order[i]))),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final s in order)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: colorOf(s), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(taskStatusLabel[s] ?? s, style: tx(12, color: p.muted)),
                  const SizedBox(width: 4),
                  Text('${counts[s]}', style: tx(12, weight: FontWeight.w700, color: p.foreground)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
