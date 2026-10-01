import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_theme.dart';

/// PaddlerBites' delivery mascot, the one boat illustration used everywhere:
/// the rider on maps, the current step of the order timeline, rider screens
/// and the voice-order loader. The app has no motorcycle/rider icons.
///
/// The "Golden Paddler": a clean flat 2D illustration in the brand
/// yellow/amber of a paddler in a yellow kayak rowing along a campus road
/// (it delivers food on land!). A navy jacket, yellow vest and amber cap, a
/// double-bladed paddle with amber blades, and a slate road with golden
/// centre-line dashes. Solid colours only: no gradients, outlines or 3D
/// shading, and a transparent background.
///
/// When [animate] is on, each blade pushes off the road in turn (kicking up
/// a little dust puff), the paddler leans into the stroke, the kayak hovers
/// and bobs over its shadow, and the road dashes and speed lines stream past
/// so it glides forward. Respects the system "reduce motion" setting. Small
/// touches (eye, vest straps, curb line) are drawn from 56 px up, so it
/// stays clean as a small map marker too.
class PremiumPaddlingBoatAnimation extends StatefulWidget {
  final double size;
  final bool animate;
  const PremiumPaddlingBoatAnimation({super.key, this.size = 44, this.animate = true});

  @override
  State<PremiumPaddlingBoatAnimation> createState() => _PremiumPaddlingBoatAnimationState();
}

class _PremiumPaddlingBoatAnimationState extends State<PremiumPaddlingBoatAnimation>
    with SingleTickerProviderStateMixin {
  // One full stroke cycle (left dip + right dip).
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(PremiumPaddlingBoatAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.animate && !reduceMotion) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      _controller.value = 0; // resting pose: paddle level, kayak centred
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'PaddlerBites delivery boat',
      child: SizedBox.square(
        dimension: widget.size,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(painter: PremiumPaddlingBoatPainter(_controller.value)),
          ),
        ),
      ),
    );
  }
}

/// Paints the scene at animation phase [t] (0..1, one full stroke cycle).
/// Everything is drawn in unit coordinates (the canvas is scaled to 1×1).
class PremiumPaddlingBoatPainter extends CustomPainter {
  final double t;
  PremiumPaddlingBoatPainter(this.t);

  // Flat palette: brand yellow/amber, navy, skin and slate for the road.
  static const _yellow = AppTheme.primaryColor;
  static const _amber = Color(0xFFF5A623);
  static const _deepAmber = AppTheme.secondaryColor;
  static const _cockpit = Color(0xFF5A3A12);
  static const _road = Color(0xFF5B6270);
  static const _curb = Color(0xFF8A919E);
  static const _shadow = Color(0xFF474D58);
  static const _dust = Color(0xFFD5D8DE);
  static const _speedLine = Color(0xFFB9BEC7);
  static const _navy = Color(0xFF26415E);
  static const _navyDark = Color(0xFF1A2E44);
  static const _skin = Color(0xFFF2C08A);
  static const _skinDark = Color(0xFFDDA06A);
  static const _hair = Color(0xFF2B2525);
  static const _shaft = Color(0xFF3A3531);

  /// The road: a flat band with rounded ends under the kayak.
  static const _roadTop = 0.74;
  static const _roadBottom = 0.84;
  static final _roadShape = RRect.fromLTRBR(0.03, _roadTop, 0.97, _roadBottom, const Radius.circular(0.05));

  /// Centre-line dashes repeat every [_dashPeriod].
  static const _dashPeriod = 0.15;

  double get _phase => t * 2 * math.pi;

  @override
  void paint(Canvas canvas, Size size) {
    final detail = size.shortestSide >= 56;
    final phase = _phase;

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width, size.height);

    _drawRoad(canvas, detail);
    _drawSpeedLines(canvas);

    // The kayak hovers a touch above the road: it glides and bobs, and its
    // shadow shrinks as it rises.
    final surge = math.sin(phase * 2) * 0.012;
    final bob = math.cos(phase * 2) * 0.008;
    _drawShadow(canvas, surge, bob);
    final paddle = _PaddleGeometry(phase);
    canvas.save();
    canvas.translate(0.5 + surge, 0.62 + bob);
    canvas.rotate(math.sin(phase) * 0.025);
    canvas.translate(-0.5, -0.62);
    _drawKayak(canvas, paddle, detail);
    canvas.restore();

    _drawDustPuff(canvas, paddle, surge);
    canvas.restore();
  }

  // ---------------------------------------------------------------------------
  // Road
  // ---------------------------------------------------------------------------

  /// Slate road with a light curb along the top and golden centre dashes
  /// streaming backwards, so the kayak seems to travel forward.
  void _drawRoad(Canvas canvas, bool detail) {
    canvas.drawRRect(_roadShape, Paint()..color = _road);
    canvas.save();
    canvas.clipRRect(_roadShape);
    if (detail) {
      canvas.drawRect(const Rect.fromLTRB(0, _roadTop, 1, _roadTop + 0.012), Paint()..color = _curb);
    }
    final shift = (t * 2 * _dashPeriod) % _dashPeriod; // two dashes pass per stroke cycle
    final dash = Paint()..color = _yellow;
    for (var x = -_dashPeriod - shift; x < 1; x += _dashPeriod) {
      canvas.drawRRect(
        RRect.fromLTRBR(x, 0.782, x + 0.075, 0.798, const Radius.circular(0.008)),
        dash,
      );
    }
    canvas.restore();
  }

  /// Short speed lines trailing behind the stern.
  void _drawSpeedLines(Canvas canvas) {
    final paint = Paint()
      ..strokeWidth = 0.008
      ..strokeCap = StrokeCap.round;
    const rows = [0.59, 0.63, 0.67];
    for (var k = 0; k < rows.length; k++) {
      final p = (t * 2 + k / 3) % 1.0;
      final x = 0.06 - p * 0.06;
      paint.color = _speedLine.withValues(alpha: 1 - p); // fades as it falls behind
      canvas.drawLine(Offset(x - 0.045, rows[k]), Offset(x, rows[k]), paint);
    }
  }

  /// Flat shadow on the road under the hull.
  void _drawShadow(Canvas canvas, double surge, double bob) {
    final scale = 1 + bob * 6; // smaller when the kayak bobs up
    canvas.drawOval(
      Rect.fromCenter(center: Offset(0.47 + surge, 0.754), width: 0.66 * scale, height: 0.026 * scale),
      Paint()..color = _shadow,
    );
  }

  /// A little puff of dust where the lower blade pushes off the road.
  void _drawDustPuff(Canvas canvas, _PaddleGeometry paddle, double surge) {
    final p = (_phase % math.pi) / math.pi; // 0..1 through each blade's push
    final alpha = math.sin(p * math.pi);
    if (alpha < 0.05) return;
    final tip = paddle.lowerBladeTip;
    final paint = Paint()..color = _dust.withValues(alpha: alpha);
    final x = tip.dx + surge - p * 0.03; // puffs drift back as the kayak moves on
    const puffs = [(-0.02, 0.0, 1.0), (0.0, -0.012, 1.25), (0.021, 0.002, 0.9)];
    for (final (dx, dy, size) in puffs) {
      canvas.drawCircle(Offset(x + dx, _roadTop + 0.004 + dy), (0.007 + 0.011 * p) * size, paint);
    }
  }

  // ---------------------------------------------------------------------------
  // Kayak and paddler
  // ---------------------------------------------------------------------------

  void _drawKayak(Canvas canvas, _PaddleGeometry paddle, bool detail) {
    final hull = Path()
      ..moveTo(0.07, 0.585) // stern
      ..quadraticBezierTo(0.5, 0.535, 0.94, 0.572) // deck edge to the bow
      ..cubicTo(0.86, 0.66, 0.66, 0.715, 0.46, 0.715) // bow down to the keel
      ..cubicTo(0.26, 0.715, 0.12, 0.67, 0.07, 0.585)
      ..close();
    canvas.drawPath(hull, Paint()..color = _yellow);

    // Flat amber stripe along the side.
    canvas.save();
    canvas.clipPath(hull);
    canvas.drawPath(
      Path()
        ..moveTo(0.05, 0.622)
        ..quadraticBezierTo(0.5, 0.65, 0.96, 0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.026
        ..color = _amber,
    );
    canvas.restore();

    // Cockpit opening the paddler sits in.
    const cockpit = Offset(0.49, 0.558);
    canvas.drawOval(Rect.fromCenter(center: cockpit, width: 0.15, height: 0.04), Paint()..color = _cockpit);

    _drawArm(canvas, paddle.backShoulder, paddle.backGrip, _navyDark);
    _drawTorso(canvas, paddle, detail);
    // Front half of the cockpit rim, over the paddler's waist.
    canvas.drawArc(
      Rect.fromCenter(center: cockpit, width: 0.16, height: 0.048),
      0,
      math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 0.014
        ..color = _cockpit,
    );
    _drawHead(canvas, paddle.body(const Offset(0.018, -0.215)), detail);
    _drawPaddle(canvas, paddle);
    _drawArm(canvas, paddle.frontShoulder, paddle.frontGrip, _navy);
    for (final grip in [paddle.backGrip, paddle.frontGrip]) {
      canvas.drawCircle(grip, 0.017, Paint()..color = _skin);
    }
  }

  void _drawTorso(Canvas canvas, _PaddleGeometry paddle, bool detail) {
    Path shape(List<Offset> points) {
      final path = Path()..moveTo(paddle.body(points.first).dx, paddle.body(points.first).dy);
      for (final p in points.skip(1)) {
        final w = paddle.body(p);
        path.lineTo(w.dx, w.dy);
      }
      return path..close();
    }

    // Navy jacket.
    canvas.drawPath(
      shape(const [
        Offset(-0.045, 0.0),
        Offset(-0.05, -0.12),
        Offset(-0.042, -0.155),
        Offset(-0.02, -0.17),
        Offset(0.03, -0.17),
        Offset(0.05, -0.155),
        Offset(0.055, -0.12),
        Offset(0.045, 0.0),
      ]),
      Paint()..color = _navy,
    );
    // Yellow buoyancy vest on the front.
    canvas.drawPath(
      shape(const [
        Offset(0.004, -0.01),
        Offset(0.047, -0.01),
        Offset(0.052, -0.12),
        Offset(0.042, -0.15),
        Offset(0.008, -0.152),
      ]),
      Paint()..color = _yellow,
    );
    if (detail) {
      final strap = Paint()
        ..color = _amber
        ..strokeWidth = 0.01
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(paddle.body(const Offset(0.01, -0.055)), paddle.body(const Offset(0.049, -0.06)), strap);
      canvas.drawLine(paddle.body(const Offset(0.01, -0.095)), paddle.body(const Offset(0.05, -0.1)), strap);
    }
    // Neck.
    canvas.drawLine(
      paddle.body(const Offset(0.01, -0.165)),
      paddle.body(const Offset(0.016, -0.19)),
      Paint()
        ..color = _skinDark
        ..strokeWidth = 0.022
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawHead(Canvas canvas, Offset c, bool detail) {
    const r = 0.048;
    canvas.drawCircle(c, r, Paint()..color = _skin);
    // Hair at the back of the head.
    canvas.drawPath(
      Path()
        ..moveTo(c.dx, c.dy)
        ..arcTo(Rect.fromCircle(center: c, radius: r * 1.02), math.pi * 0.55, math.pi * 0.75, false)
        ..close(),
      Paint()..color = _hair,
    );
    // Amber cap with a darker visor pointing forward.
    canvas.drawArc(
      Rect.fromCircle(center: c + const Offset(0, -0.004), radius: r * 1.06),
      math.pi,
      math.pi,
      true,
      Paint()..color = _amber,
    );
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + r * 0.5, c.dy - r * 0.2)
        ..quadraticBezierTo(c.dx + r * 1.6, c.dy - r * 0.3, c.dx + r * 1.7, c.dy - r * 0.02)
        ..quadraticBezierTo(c.dx + r * 1.2, c.dy + r * 0.06, c.dx + r * 0.5, c.dy + r * 0.02)
        ..close(),
      Paint()..color = _deepAmber,
    );
    if (detail) {
      canvas.drawCircle(c + const Offset(r * 0.55, r * 0.22), 0.0065, Paint()..color = _hair); // eye
    }
  }

  void _drawArm(Canvas canvas, Offset shoulder, Offset grip, Color sleeve) {
    // Elbow bends downwards, away from the line between shoulder and hand.
    final along = grip - shoulder;
    var normal = Offset(-along.dy, along.dx) / along.distance;
    if (normal.dy < 0) normal = -normal;
    final elbow = (shoulder + grip) / 2 + normal * 0.022;
    canvas.drawPath(
      Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(grip.dx, grip.dy),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.028
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = sleeve,
    );
  }

  void _drawPaddle(Canvas canvas, _PaddleGeometry paddle) {
    canvas.drawLine(
      paddle.leftEnd,
      paddle.rightEnd,
      Paint()
        ..color = _shaft
        ..strokeWidth = 0.014
        ..strokeCap = StrokeCap.round,
    );
    _drawBlade(canvas, paddle.rightEnd, paddle.angle);
    _drawBlade(canvas, paddle.leftEnd, paddle.angle + math.pi);
  }

  /// A spoon-shaped amber blade reaching outwards from [end] along [angle].
  void _drawBlade(Canvas canvas, Offset end, double angle) {
    canvas.save();
    canvas.translate(end.dx, end.dy);
    canvas.rotate(angle);
    canvas.drawPath(
      Path()
        ..moveTo(0, -0.01)
        ..cubicTo(0.027, -0.03, 0.09, -0.034, 0.108, -0.016)
        ..quadraticBezierTo(0.116, 0, 0.108, 0.014)
        ..cubicTo(0.09, 0.028, 0.027, 0.026, 0, 0.01)
        ..close(),
      Paint()..color = _amber,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PremiumPaddlingBoatPainter oldDelegate) => oldDelegate.t != t;
}

/// Where the paddler's body, hands and paddle are at a point in the stroke
/// (in the kayak's own coordinates, before it glides and bobs).
class _PaddleGeometry {
  _PaddleGeometry(double phase)
      : lean = 0.12 + math.sin(phase * 2) * 0.04,
        angle = math.sin(phase) * 0.6,
        slide = math.sin(phase) * 0.05 {
    dir = Offset(math.cos(angle), math.sin(angle));
    final shoulder = body(const Offset(0.005, -0.16));
    frontShoulder = body(const Offset(0.028, -0.152));
    backShoulder = body(const Offset(-0.022, -0.152));
    final pivot = shoulder + const Offset(0.02, 0.07);
    leftEnd = pivot + dir * (-0.31 + slide);
    rightEnd = pivot + dir * (0.31 + slide);
    backGrip = pivot + dir * (-0.1 + slide);
    frontGrip = pivot + dir * (0.1 + slide);
  }

  static const _hip = Offset(0.49, 0.565);

  /// Forward lean of the torso; it deepens on each stroke.
  final double lean;

  /// Shaft tilt: positive dips the right (forward) blade, negative the left.
  final double angle;

  /// The shaft slides towards the lower blade so it reaches the road.
  final double slide;

  late final Offset dir;
  late final Offset frontShoulder;
  late final Offset backShoulder;
  late final Offset leftEnd;
  late final Offset rightEnd;
  late final Offset backGrip;
  late final Offset frontGrip;

  /// A point on the torso (relative to the hip) after the lean.
  Offset body(Offset local) {
    final c = math.cos(lean);
    final s = math.sin(lean);
    return _hip + Offset(local.dx * c - local.dy * s, local.dx * s + local.dy * c);
  }

  /// Where the lower blade meets the road.
  Offset get lowerBladeTip => angle >= 0 ? rightEnd + dir * 0.105 : leftEnd - dir * 0.105;
}
