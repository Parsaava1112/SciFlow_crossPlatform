import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'theme_provider.dart';

class ParticleBackground extends StatefulWidget {
  final double speedMultiplier;
  final AppTheme theme;
  const ParticleBackground({
    Key? key,
    this.speedMultiplier = 1.0,
    this.theme = AppTheme.defaultTheme,
  }) : super(key: key);

  @override
  _ParticleBackgroundState createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _particles =
        List.generate(40, (index) => _Particle(_random, widget.theme));
    _controller.addListener(() {
      setState(() {
        for (var p in _particles) {
          p.update(widget.speedMultiplier);
        }
      });
    });
  }

  @override
  void didUpdateWidget(ParticleBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.theme != widget.theme) {
      for (var p in _particles) {
        p.changeTheme(widget.theme, _random);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ParticlePainter(_particles, widget.theme),
    );
  }
}

class _Particle {
  late double x, y;
  late double speed;
  late double size;
  late double opacity;
  late Color color;
  late int shape; // 0: circle, 1: flower, 2: bubble, 3: sparkle
  late double rotation;
  late double rotationSpeed;

  _Particle(Random random, AppTheme theme) {
    _init(random, theme);
    x = random.nextDouble() * 400;
    y = random.nextDouble() * 800;
  }

  void _init(Random random, AppTheme theme) {
    switch (theme) {
      case AppTheme.nature:
        color = Color.lerp(
            Colors.green.shade300, Colors.lightGreen.shade200, random.nextDouble())!;
        shape = random.nextBool() ? 1 : 0;
        break;
      case AppTheme.ocean:
        color = Color.lerp(
            Colors.lightBlue.shade200, Colors.cyan.shade100, random.nextDouble())!;
        shape = 2;
        break;
      case AppTheme.golden:
        color = Color.lerp(
            Colors.amber.shade300, Colors.yellow.shade100, random.nextDouble())!;
        shape = 3;
        break;
      default:
        color = Colors.white.withOpacity(0.2);
        shape = 0;
    }
    speed = (0.3 + random.nextDouble() * 0.7);
    size = 4.0 + random.nextDouble() * 8;
    opacity = 0.1 + random.nextDouble() * 0.4;
    rotation = random.nextDouble() * 2 * pi;
    rotationSpeed = (random.nextDouble() - 0.5) * 0.02;
  }

  void changeTheme(AppTheme theme, Random random) {
    _init(random, theme);
  }

  void update(double multiplier) {
    y -= speed * multiplier * 0.8;
    rotation += rotationSpeed * multiplier;
    if (y < -20) {
      y = 820;
      x = Random().nextDouble() * 400;
    }
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final AppTheme theme;

  _ParticlePainter(this.particles, this.theme);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case 0:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
        case 1:
          _drawFlower(canvas, p.size, paint);
          break;
        case 2:
          canvas.drawCircle(Offset.zero, p.size * 0.6, paint);
          final shinePaint = Paint()
            ..color = Colors.white.withOpacity(p.opacity * 0.5)
            ..style = PaintingStyle.fill;
          canvas.drawCircle(
              Offset(-p.size * 0.15, -p.size * 0.15), p.size * 0.15, shinePaint);
          break;
        case 3:
          _drawSparkle(canvas, p.size, paint);
          break;
      }
      canvas.restore();
    }
  }

  void _drawFlower(Canvas canvas, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      double angle = i * (pi / 3);
      double dx = cos(angle) * size * 0.4;
      double dy = sin(angle) * size * 0.4;
      path.addOval(
          Rect.fromCircle(center: Offset(dx, dy), radius: size * 0.25));
    }
    canvas.drawPath(path, paint);
    canvas.drawCircle(
        Offset.zero, size * 0.18, Paint()..color = Colors.yellow);
  }

  void _drawSparkle(Canvas canvas, double size, Paint paint) {
    final path = Path();
    double r1 = size * 0.5;
    double r2 = size * 0.15;
    for (int i = 0; i < 5; i++) {
      double angle = i * (2 * pi / 5) - pi / 2;
      double x1 = cos(angle) * r1;
      double y1 = sin(angle) * r1;
      double x2 = cos(angle + pi / 5) * r2;
      double y2 = sin(angle + pi / 5) * r2;
      if (i == 0) path.moveTo(x1, y1);
      path.lineTo(x2, y2);
      path.lineTo(x1, y1);
    }
    path.close();
    canvas.drawPath(path, paint);
    canvas.drawPath(
        path, paint..maskFilter = MaskFilter.blur(BlurStyle.normal, 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}