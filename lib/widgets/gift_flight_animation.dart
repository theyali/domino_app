import 'dart:math' as math;

import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
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

    _controller.forward(from: 0);
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
          final flight = Curves.easeInOutCubic.transform(raw);
          final base = Offset.lerp(_sourceLocal, _targetLocal, flight)!;
          final arc = 82 * math.sin(math.pi * flight);
          final center = Offset(base.dx, base.dy - arc);
          final scale = raw < 0.78
              ? 0.55 + 0.62 * Curves.easeOutBack.transform(raw / 0.78)
              : 1.17 - 0.17 * Curves.easeOut.transform((raw - 0.78) / 0.22);
          final rotation = math.sin(math.pi * flight) * 0.18;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: center.dx - 29,
                top: center.dy - 29,
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
        child: SizedBox(
          width: 58,
          height: 58,
          child: widget.imageUrl?.trim().isNotEmpty == true
              ? Image.network(
                  widget.imageUrl!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.card_giftcard_rounded,
                      color: Color(0xFF5B3A9E),
                      size: 46,
                    );
                  },
                )
              : const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFF5B3A9E),
                  size: 46,
                ),
        ),
      ),
    );
  }
}
