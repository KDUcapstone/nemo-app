import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:frontend/app/theme/app_colors.dart';

class SkyBackground extends StatelessWidget {
  const SkyBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkyBackgroundAnimated();
  }
}

class SkyBackgroundAnimated extends StatefulWidget {
  const SkyBackgroundAnimated({super.key});

  @override
  State<SkyBackgroundAnimated> createState() => _SkyBackgroundAnimatedState();
}

class _SkyBackgroundAnimatedState extends State<SkyBackgroundAnimated>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;
          final dx1 = 6 * math.sin(t);
          final dy1 = 4 * math.cos(t);
          final dx2 = 8 * math.cos(t * 0.8);
          final dy2 = 5 * math.sin(t * 0.8);
          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.skyLight, AppColors.skyMid],
                  ),
                ),
              ),
              Positioned(
                top: -40 + dy1,
                right: -20 + dx1,
                child: Opacity(
                  opacity: 0.35,
                  child: Blob(size: 160, color: AppColors.accent),
                ),
              ),
              Positioned(
                bottom: -50 + dy2,
                left: -20 + dx2,
                child: Opacity(
                  opacity: 0.25,
                  child: Blob(size: 200, color: AppColors.skyDeep),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class Blob extends StatelessWidget {
  final double size;
  final Color color;
  const Blob({super.key, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: color),
        ),
      ),
    );
  }
}
