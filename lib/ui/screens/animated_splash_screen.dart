// lib/ui/screens/animated_splash_screen.dart

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'home_shell_screen.dart';

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _mainController;
  late final AnimationController _orbitalController;
  late final AnimationController _shimmerController;

  // Animations
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _progressAnimation;

  final List<_CosmicParticle> _particles = [];
  final math.Random _random = math.Random();

  int _statusIndex = 0;
  final List<String> _statusMessages = [
    'INITIALIZING SANDBOX ENGINE...',
    'MOUNTING ISOLATED MULTI-USER STORAGE...',
    'ALLOCATING 25 WORKER PROCESS SLOTS...',
    'INJECTING SIGNATURE BYPASS VAULT...',
    'SYSTEM READY - LAUNCHING APP TO CLONE',
  ];

  @override
  void initState() {
    super.initState();

    // 1. Main timeline controller (3.0 seconds)
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // 2. Orbital rings continuous rotation
    _orbitalController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    // 3. Holographic sheen sweep controller
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Setup choreographed timeline
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _logoOpacity = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeIn),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _progressAnimation = Tween<double>(begin: 0.05, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.05, 0.95, curve: Curves.easeInOutCubic),
      ),
    );

    // Initialize floating starfield particles
    for (int i = 0; i < 45; i++) {
      _particles.add(
        _CosmicParticle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          radius: _random.nextDouble() * 2.2 + 0.8,
          speed: _random.nextDouble() * 0.0004 + 0.0002,
          opacity: _random.nextDouble() * 0.6 + 0.2,
          pulseSpeed: _random.nextDouble() * 2 + 1,
        ),
      );
    }

    // Status message cycling
    _mainController.addListener(() {
      final double p = _progressAnimation.value;
      final int nextIndex = (p * (_statusMessages.length - 1)).round();
      if (nextIndex != _statusIndex && nextIndex < _statusMessages.length) {
        setState(() {
          _statusIndex = nextIndex;
        });
      }
    });

    _mainController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });

    _mainController.forward();
  }

  void _navigateToHome() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeShellScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _orbitalController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF070B1E),
      body: Stack(
        children: [
          // 1. Procedural animated cosmic starfield & aurora mesh
          Positioned.fill(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([_orbitalController, _mainController]),
                builder: (context, _) {
                  return CustomPaint(
                    painter: _CosmicBackgroundPainter(
                      particles: _particles,
                      time: _orbitalController.value * 2 * math.pi,
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Ambient glowing orbs
          Positioned(
            top: size.height * 0.18,
            left: size.width * 0.1,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF00D2FF).withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: size.height * 0.22,
            right: size.width * 0.08,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B5CF6).withValues(alpha: 0.20),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3. Skip Button in top corner
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 16),
                child: TextButton(
                  onPressed: _navigateToHome,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                  ),
                  child: const Text(
                    'SKIP  ➔',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 4. Center Stage: Holographic Logo & Orbital Energy Rings
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Rotating Cybernetic Orbital Energy Rings
                      AnimatedBuilder(
                        animation: _orbitalController,
                        builder: (context, child) {
                          return CustomPaint(
                            size: const Size(240, 240),
                            painter: _CyberOrbitalRingsPainter(
                              progress: _orbitalController.value,
                              pulse: math.sin(_orbitalController.value * 2 * math.pi),
                            ),
                          );
                        },
                      ),

                      // Animated Elastic Logo Card
                      AnimatedBuilder(
                        animation: _mainController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScale.value,
                            child: Opacity(
                              opacity: _logoOpacity.value.clamp(0.0, 1.0),
                              child: child,
                            ),
                          );
                        },
                        child: Hero(
                          tag: 'app_logo_hero',
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                                  blurRadius: 36,
                                  spreadRadius: 4,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                                  blurRadius: 50,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Stack(
                                children: [
                                  // Base logo image
                                  Image.asset(
                                    'assets/images/app_logo.png',
                                    fit: BoxFit.cover,
                                    width: 120,
                                    height: 120,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: const Color(0xFF0A0E2A),
                                        child: const Center(
                                          child: Icon(
                                            Icons.layers_rounded,
                                            size: 56,
                                            color: Color(0xFF38BDF8),
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  // Holographic Sheen Sweep
                                  AnimatedBuilder(
                                    animation: _shimmerController,
                                    builder: (context, _) {
                                      final double offset = _shimmerController.value * 3 - 1;
                                      return Positioned.fill(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              begin: Alignment(offset - 1, -1),
                                              end: Alignment(offset, 1),
                                              colors: [
                                                Colors.transparent,
                                                Colors.white.withValues(alpha: 0.25),
                                                Colors.transparent,
                                              ],
                                              stops: const [0.0, 0.5, 1.0],
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // 5. Typography Entrance: "App to Clone"
                AnimatedBuilder(
                  animation: _mainController,
                  builder: (context, child) {
                    return SlideTransition(
                      position: _textSlide,
                      child: Opacity(
                        opacity: _textOpacity.value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) {
                          return const LinearGradient(
                            colors: [
                              Color(0xFF38BDF8), // Cyan
                              Color(0xFF818CF8), // Indigo
                              Color(0xFFC084FC), // Purple
                            ],
                          ).createShader(bounds);
                        },
                        child: const Text(
                          'App to Clone',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'MULTI-INSTANCE VIRTUALIZATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.0,
                            color: Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 6. Bottom Cyber Progress Bar & Status Feed
          Positioned(
            left: 36,
            right: 36,
            bottom: 48,
            child: AnimatedBuilder(
              animation: _mainController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textOpacity.value.clamp(0.0, 1.0),
                  child: child,
                );
              },
              child: Column(
                children: [
                  // Stage Status Text + Percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            _statusMessages[_statusIndex],
                            key: ValueKey<int>(_statusIndex),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'monospace',
                              letterSpacing: 0.8,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: _progressAnimation,
                        builder: (context, _) {
                          final pct = (_progressAnimation.value * 100).toInt();
                          return Text(
                            '[ ${pct.toString().padLeft(3, '0')}% ]',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                              color: Color(0xFF38BDF8),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Glowing Cyber Progress Track
                  Container(
                    height: 4,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: AnimatedBuilder(
                      animation: _progressAnimation,
                      builder: (context, _) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            return Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                width: constraints.maxWidth * _progressAnimation.value,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(4),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF00D2FF),
                                      Color(0xFF6366F1),
                                      Color(0xFFA855F7),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF00D2FF).withValues(alpha: 0.8),
                                      blurRadius: 8,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Sandbox Isolation Matrix :worker_01 ~ :worker_25',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF475569),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------- Procedural Cosmic Background Painter -----------------
class _CosmicParticle {
  double x;
  double y;
  final double radius;
  final double speed;
  final double opacity;
  final double pulseSpeed;

  _CosmicParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
    required this.pulseSpeed,
  });
}

class _CosmicBackgroundPainter extends CustomPainter {
  final List<_CosmicParticle> particles;
  final double time;

  _CosmicBackgroundPainter({required this.particles, required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      // Drift upwards
      p.y -= p.speed;
      if (p.y < 0) {
        p.y = 1.0;
        p.x = (p.x + 0.15) % 1.0;
      }

      final double px = p.x * size.width;
      final double py = p.y * size.height;
      final double dynamicOpacity =
          (p.opacity * (0.6 + 0.4 * math.sin(time * p.pulseSpeed))).clamp(0.05, 1.0);

      paint.color = const Color(0xFF38BDF8).withValues(alpha: dynamicOpacity);
      canvas.drawCircle(Offset(px, py), p.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CosmicBackgroundPainter oldDelegate) => true;
}

// ----------------- Procedural Cyber Orbital Rings Painter -----------------
class _CyberOrbitalRingsPainter extends CustomPainter {
  final double progress;
  final double pulse;

  _CyberOrbitalRingsPainter({required this.progress, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Outer Pulsing Radar Ring
    final radarRadius = 88.0 + (pulse * 6.0);
    final radarPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0xFF00D2FF).withValues(alpha: (0.20 + pulse * 0.1).clamp(0.05, 0.4));
    canvas.drawCircle(center, radarRadius, radarPaint);

    // Concentric Segmented Ring 1 (Clockwise)
    final ring1Radius = 78.0;
    final angle1 = progress * 2 * math.pi;
    final ring1Paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..shader = SweepGradient(
        colors: const [
          Colors.transparent,
          Color(0xFF38BDF8),
          Color(0xFF818CF8),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 0.7, 1.0],
        transform: GradientRotation(angle1),
      ).createShader(Rect.fromCircle(center: center, radius: ring1Radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ring1Radius),
      angle1,
      math.pi * 1.3,
      false,
      ring1Paint,
    );

    // Concentric Segmented Ring 2 (Counter-Clockwise)
    final ring2Radius = 98.0;
    final angle2 = -progress * 2 * math.pi * 0.75;
    final ring2Paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = SweepGradient(
        colors: const [
          Colors.transparent,
          Color(0xFFA855F7),
          Color(0xFF38BDF8),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
        transform: GradientRotation(angle2),
      ).createShader(Rect.fromCircle(center: center, radius: ring2Radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: ring2Radius),
      angle2,
      math.pi * 1.1,
      false,
      ring2Paint,
    );

    // Four Cyber Axis Ticks
    final tickPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.5)
      ..strokeWidth = 1.5;

    for (int i = 0; i < 4; i++) {
      final tickAngle = angle1 + (i * math.pi / 2);
      final p1 = center + Offset(math.cos(tickAngle) * 72, math.sin(tickAngle) * 72);
      final p2 = center + Offset(math.cos(tickAngle) * 82, math.sin(tickAngle) * 82);
      canvas.drawLine(p1, p2, tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberOrbitalRingsPainter oldDelegate) => true;
}
