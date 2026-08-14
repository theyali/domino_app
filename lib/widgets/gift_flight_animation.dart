import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GiftFlightAnimation extends StatefulWidget {
  final String? imageUrl;
  final String giftName;
  final Offset sourceGlobalCenter;
  final Offset targetGlobalCenter;
  final VoidCallback onCompleted;

  const GiftFlightAnimation({
    super.key,
    required this.imageUrl,
    required this.giftName,
    required this.sourceGlobalCenter,
    required this.targetGlobalCenter,
    required this.onCompleted,
  });

  @override
  State<GiftFlightAnimation> createState() => _GiftFlightAnimationState();
}

class _GiftFlightAnimationState extends State<GiftFlightAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Offset _sourceLocal = Offset.zero;
  Offset _targetLocal = Offset.zero;
  bool _isReady = false;
  bool _landingHapticSent = false;

  static const double _giftSize = 44;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1080),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onCompleted();
        }
      });

    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  void _prepare() {
    if (!mounted) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
      return;
    }

    setState(() {
      _sourceLocal = renderObject.globalToLocal(widget.sourceGlobalCenter);
      _targetLocal = renderObject.globalToLocal(widget.targetGlobalCenter);
      _isReady = true;
    });

    HapticFeedback.selectionClick();
    _controller.forward(from: 0);
  }

  Offset _curvePoint(double t) {
    final distance = (_targetLocal - _sourceLocal).distance;
    final direction = _targetLocal.dx >= _sourceLocal.dx ? 1.0 : -1.0;
    final arcHeight = math.min(150.0, math.max(82.0, distance * 0.23));
    final sideSwing = math.min(34.0, distance * 0.055) * direction;

    final control = Offset(
      (_sourceLocal.dx + _targetLocal.dx) / 2 + sideSwing,
      math.min(_sourceLocal.dy, _targetLocal.dy) - arcHeight,
    );

    final oneMinusT = 1 - t;
    return Offset(
      oneMinusT * oneMinusT * _sourceLocal.dx +
          2 * oneMinusT * t * control.dx +
          t * t * _targetLocal.dx,
      oneMinusT * oneMinusT * _sourceLocal.dy +
          2 * oneMinusT * t * control.dy +
          t * t * _targetLocal.dy,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const SizedBox.expand();
    }

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final raw = _controller.value;
          final flightInput = (raw / 0.84).clamp(0.0, 1.0).toDouble();
          final flightT = Curves.easeInOutCubic.transform(flightInput);
          final center = _curvePoint(flightT);

          final landingT =
              ((raw - 0.80) / 0.20).clamp(0.0, 1.0).toDouble();
          if (landingT > 0.08 && !_landingHapticSent) {
            _landingHapticSent = true;
            HapticFeedback.lightImpact();
          }

          final scaleInput = (raw / 0.66).clamp(0.0, 1.0).toDouble();
          final flightScale = raw < 0.66
              ? 0.46 + 0.72 * Curves.easeOutBack.transform(scaleInput)
              : 1.18;
          final landingBounce = landingT == 0
              ? 0.0
              : math.sin(landingT * math.pi) * 0.22;
          final landingShrink =
              0.30 * Curves.easeOutCubic.transform(landingT);
          final scale = flightScale + landingBounce - landingShrink;

          final rotation =
              math.sin(flightT * math.pi * 2.4) * (1 - landingT) * 0.16;
          final opacity = raw < 0.97
              ? 1.0
              : 1 - Curves.easeIn.transform((raw - 0.97) / 0.03);

          final trail1T =
              (flightT - 0.055).clamp(0.0, 1.0).toDouble();
          final trail2T =
              (flightT - 0.11).clamp(0.0, 1.0).toDouble();
          final trail3T =
              (flightT - 0.165).clamp(0.0, 1.0).toDouble();
          final trail1 = _curvePoint(trail1T);
          final trail2 = _curvePoint(trail2T);
          final trail3 = _curvePoint(trail3T);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              if (raw > 0.76)
                _LandingBurst(
                  center: _targetLocal,
                  progress: landingT,
                ),
              if (raw > 0.06 && raw < 0.90) ...[
                _TrailSpark(
                  center: trail3,
                  size: 5,
                  opacity: 0.18 * (1 - landingT),
                ),
                _TrailSpark(
                  center: trail2,
                  size: 7,
                  opacity: 0.30 * (1 - landingT),
                ),
                _TrailSpark(
                  center: trail1,
                  size: 9,
                  opacity: 0.45 * (1 - landingT),
                ),
              ],
              Positioned(
                left: center.dx - _giftSize / 2,
                top: center.dy - _giftSize / 2,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0).toDouble(),
                  child: Transform.rotate(
                    angle: rotation,
                    child: Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: SizedBox(
          width: _giftSize,
          height: _giftSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.30),
                  blurRadius: 14,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: widget.imageUrl?.trim().isNotEmpty == true
                ? Image.network(
                    widget.imageUrl!,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.card_giftcard_rounded,
                        color: Colors.amberAccent,
                        size: 36,
                      );
                    },
                  )
                : const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.amberAccent,
                    size: 36,
                  ),
          ),
        ),
      ),
    );
  }
}

class _TrailSpark extends StatelessWidget {
  final Offset center;
  final double size;
  final double opacity;

  const _TrailSpark({
    required this.center,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    final safeOpacity = opacity.clamp(0.0, 1.0).toDouble();

    return Positioned(
      left: center.dx - size / 2,
      top: center.dy - size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: safeOpacity),
          boxShadow: [
            BoxShadow(
              color: Colors.amberAccent.withValues(
                alpha: (safeOpacity * 0.9).clamp(0.0, 1.0).toDouble(),
              ),
              blurRadius: size * 1.8,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingBurst extends StatelessWidget {
  final Offset center;
  final double progress;

  const _LandingBurst({
    required this.center,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOutCubic.transform(progress);
    final fade = (1 - progress).clamp(0.0, 1.0).toDouble();
    final radius = 20 + 34 * eased;

    return Positioned(
      left: center.dx - radius,
      top: center.dy - radius,
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: radius * 1.55,
              height: radius * 1.55,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.65 * fade),
                  width: 1.5,
                ),
              ),
            ),
            for (var i = 0; i < 6; i++)
              Transform.rotate(
                angle: (math.pi * 2 / 6) * i,
                child: Transform.translate(
                  offset: Offset(0, -radius * 0.72),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.amberAccent.withValues(alpha: 0.9 * fade),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amberAccent.withValues(alpha: 0.5 * fade),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
