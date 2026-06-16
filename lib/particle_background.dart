import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({Key? key}) : super(key: key);

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> with TickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // ایجاد ۵۰ ذره تصادفی
    for (int i = 0; i < 50; i++) {
      _particles.add(Particle(
        x: _random.nextDouble() * 400,
        y: _random.nextDouble() * 800,
        radius: _random.nextDouble() * 2 + 1,
        speedX: (_random.nextDouble() - 0.5) * 0.5,
        speedY: (_random.nextDouble() - 0.5) * 0.5,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        for (var p in _particles) {
          p.update();
        }
        return CustomPaint(
          painter: ParticlePainter(_particles),
          size: MediaQuery.of(context).size,
        );
      },
    );
  }
}

class Particle {
  double x, y, radius, speedX, speedY;
  Particle({required this.x, required this.y, required this.radius, required this.speedX, required this.speedY});

  void update() {
    x += speedX;
    y += speedY;
    if (x < 0 || x > 400) speedX *= -1;
    if (y < 0 || y > 800) speedY *= -1;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.3);
    for (var p in particles) {
      canvas.drawCircle(Offset(p.x, p.y), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}