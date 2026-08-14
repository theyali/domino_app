import 'dart:math' as math;

import 'package:flutter/material.dart';

class DominoPlacementTarget extends StatefulWidget {
  final double width;
  final double height;
  final VoidCallback onTap;

  const DominoPlacementTarget({
    super.key,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  State<DominoPlacementTarget> createState() =>
      _DominoPlacementTargetState();
}

class _DominoPlacementTargetState extends State<DominoPlacementTarget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat(reverse: true);

    _opacity = Tween<double>(
      begin: 0.78,
      end: 1,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _scale = Tween<double>(
      begin: 0.98,
      end: 1.035,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Поставить костяшку сюда',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: FadeTransition(
          opacity: _opacity,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.16),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _DashedDominoTargetPainter(),
                child: Center(
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.32),
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 15,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedDominoTargetPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.98)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(
      1.5,
      1.5,
      size.width - 3,
      size.height - 3,
    );

    final rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(7),
    );

    canvas.drawRRect(
      rrect,
      fillPaint,
    );

    final path = Path()..addRRect(rrect);

    const dashLength = 6.0;
    const gapLength = 3.5;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;

      while (distance < metric.length) {
        final end = math.min(
          distance + dashLength,
          metric.length,
        );

        canvas.drawPath(
          metric.extractPath(
            distance,
            end,
          ),
          strokePaint,
        );

        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(
    covariant _DashedDominoTargetPainter oldDelegate,
  ) {
    return false;
  }
}
