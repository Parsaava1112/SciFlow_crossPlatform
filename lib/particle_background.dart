import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  final double speedMultiplier; // ۱.۰ عادی، ۲.۰ تند
  const ParticleBackground({Key? key, this.speedMultiplier = 1.0}) : super(key: key);

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 50; i++) {
      _particles.add(Particle(_random));
    }
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        setState(() {
          for (var p in _particles) {
            p.move(widget.speedMultiplier);
          }
        });
      });
    _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant ParticleBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    // فقط برای تغییر سرعت لازم نیست کاری کنیم چون در move از widget جدید می‌خونه
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ParticlePainter(_particles),
      size: Size.infinite,
    );
  }
}

class Particle {
  double x, y, dx, dy, size;
  Color color;

  Particle(Random rand)
      : x = rand.nextDouble() * 400,
        y = rand.nextDouble() * 800,
        dx = (rand.nextDouble() - 0.5) * 0.5,
        dy = (rand.nextDouble() - 0.5) * 0.5,
        size = rand.nextDouble() * 3 + 1,
        color = Color.fromARGB(
          rand.nextInt(100) + 55,
          rand.nextInt(255),
          rand.nextInt(255),
          rand.nextInt(255),
        );

  void move(double speedMult) {
    x += dx * speedMult;
    y += dy * speedMult;
    if (x < 0 || x > 400) dx *= -1;
    if (y < 0 || y > 800) dy *= -1;
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var p in particles) {
      paint.color = p.color;
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}