import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../logic/cycle_forecast.dart';
import '../../theme.dart';

/// Her cycle as an orbit of day beads around a moon that follows it: new
/// when her period starts, full around ovulation, waning towards the next.
class CycleDial extends StatefulWidget {
  const CycleDial({super.key, required this.dial});

  final DialData dial;

  @override
  State<CycleDial> createState() => _CycleDialState();
}

class _CycleDialState extends State<CycleDial>
    with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 1200);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _duration,
  );

  /// Shared by every sweep; a new curve per sweep would each leave a
  /// listener on the controller.
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOutCubic,
  );
  late Animation<double> _marker = _sweep(0, _target);
  bool _started = false;

  double get _target => (widget.dial.todayIndex ?? 0).toDouble();

  Animation<double> _sweep(double from, double to) =>
      Tween(begin: from, end: to).animate(_curve);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _duration;
    if (!_started) {
      _started = true;
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(CycleDial oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dial == oldWidget.dial) return;
    final from = _marker.value;
    // A new cycle carries on forward past the top rather than rewinding.
    final length = widget.dial.length;
    _marker = _sweep(
      _target < from - length / 2 ? from - length : from,
      _target,
    );
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _curve.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dial = widget.dial;
    return Semantics(
      label: _describe(dial),
      child: AspectRatio(
        aspectRatio: 1,
        // Keeps the 1.2 s sweep from repainting the rest of the page.
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _marker,
            builder: (context, _) => CustomPaint(
              painter: _DialPainter(
                dial: dial,
                marker: _marker.value,
                colors: CycleColors.of(context),
                background: Theme.of(context).colorScheme.surface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _describe(DialData dial) {
    final today = dial.todayIndex;
    if (today == null) return '周期图，还没有记录';
    if (today >= dial.length) return '周期图，已到预计来月经的时间';
    return '周期图，一个周期约 ${dial.length} 天，今天是第 ${today + 1} 天';
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({
    required this.dial,
    required this.marker,
    required this.colors,
    required this.background,
  });

  final DialData dial;

  /// Today's position in beads, animated. Briefly negative while a new
  /// cycle comes round past the top.
  final double marker;

  final CycleColors colors;

  /// The page colour, used to cut today's marker out from the beads.
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final orbit = radius * 0.86;
    final bead = radius * 0.028;
    final hasToday = dial.todayIndex != null;

    Offset pointAt(double index) {
      final angle = -math.pi / 2 + 2 * math.pi * index / dial.length;
      return center + Offset(math.cos(angle), math.sin(angle)) * orbit;
    }

    canvas.drawCircle(
      center,
      orbit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colors.track.withValues(alpha: colors.track.a * 0.5),
    );

    for (var i = 0; i < dial.length; i++) {
      final (color, scale) = switch (dial.kindAt(i)) {
        DayKind.period || DayKind.predictedPeriod => (colors.period, 1.5),
        DayKind.ovulation => (colors.ovulation, 1.6),
        DayKind.fertile => (colors.ovulation.withValues(alpha: 0.55), 1.15),
        DayKind.none => (colors.track, 1.0),
      };
      // Days still ahead are drawn faintly.
      final ahead = !hasToday || i > marker;
      canvas.drawCircle(
        pointAt(i.toDouble()),
        bead * scale,
        Paint()..color = ahead ? color.withValues(alpha: color.a * 0.4) : color,
      );
    }

    _paintMoon(
      canvas,
      center,
      radius * 0.4,
      phase: hasToday ? (marker / dial.length) % 1.0 : 0.2,
    );

    if (hasToday) {
      final point = pointAt(marker);
      canvas
        ..drawCircle(
          point,
          bead * 3.6,
          Paint()..color = colors.today.withValues(alpha: 0.25),
        )
        ..drawCircle(point, bead * 2.2, Paint()..color = background)
        ..drawCircle(point, bead * 1.7, Paint()..color = colors.today);
    }
  }

  /// The dark "seas" of the real moon, as (x, y, radius) in moon radii, so
  /// the disc reads as a moon rather than a sun.
  static const _maria = [
    (-0.34, -0.26, 0.27),
    (0.16, -0.40, 0.17),
    (0.36, -0.04, 0.20),
    (-0.10, 0.26, 0.15),
    (0.14, 0.52, 0.09),
  ];

  void _paintMoon(
    Canvas canvas,
    Offset center,
    double r, {
    required double phase,
  }) {
    final lit = (1 - math.cos(2 * math.pi * phase)) / 2;
    if (lit > 0.02) {
      final glow = Rect.fromCircle(center: center, radius: r * 1.45);
      canvas.drawCircle(
        center,
        r * 1.45,
        Paint()
          ..shader = RadialGradient(
            colors: [
              colors.moon.withValues(alpha: 0.4 * lit),
              colors.moon.withValues(alpha: 0),
            ],
            stops: const [0.6, 1],
          ).createShader(glow),
      );
    }

    // During her period the dark side of the moon turns rouge.
    final shade = dial.inPeriod
        ? colors.period.withValues(alpha: 0.22)
        : colors.moonShadow;
    canvas.drawCircle(center, r, Paint()..color = shade);

    if (lit > 0.004) {
      final litPath = moonLitPath(center, r, phase);
      final maria = Paint()
        ..color = Color.lerp(
          colors.moon,
          const Color(0xFF5E4A2A),
          0.5,
        )!.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.05);
      canvas
        ..drawPath(litPath, Paint()..color = colors.moon)
        ..save()
        ..clipPath(litPath);
      for (final (x, y, size) in _maria) {
        canvas.drawCircle(center + Offset(x, y) * r, size * r, maria);
      }
      canvas.restore();
    }

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = dial.inPeriod
            ? colors.period.withValues(alpha: 0.45)
            : colors.track,
    );
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.marker != marker ||
      old.dial != dial ||
      old.colors != colors ||
      old.background != background;
}

/// Outline of the sunlit part of a moon of radius [r] at [phase], where 0 is
/// new and 0.5 full. It is lit on the right while waxing, on the left while
/// waning, bounded by the limb on one side and the terminator (a half
/// ellipse) on the other.
Path moonLitPath(Offset center, double r, double phase) {
  final angle = 2 * math.pi * phase;
  final waxing = phase < 0.5;
  final crescent = math.cos(angle) > 0;
  final halfWidth = math.max((r * math.cos(angle)).abs(), 0.01);
  return Path()
    ..moveTo(center.dx, center.dy - r)
    ..arcTo(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      waxing ? math.pi : -math.pi,
      false,
    )
    ..arcTo(
      Rect.fromCenter(center: center, width: 2 * halfWidth, height: 2 * r),
      math.pi / 2,
      waxing == crescent ? -math.pi : math.pi,
      false,
    )
    ..close();
}
