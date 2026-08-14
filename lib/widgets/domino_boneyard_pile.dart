import 'dart:math' as math;

import 'package:flutter/material.dart';

class DominoBoneyardPile extends StatefulWidget {
  final int count;
  final bool enabled;
  final VoidCallback onTap;

  const DominoBoneyardPile({
    super.key,
    required this.count,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<DominoBoneyardPile> createState() =>
      _DominoBoneyardPileState();
}

class _DominoBoneyardPileState extends State<DominoBoneyardPile>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _drawController;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 760),
    )..repeat(reverse: true);

    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _scale = Tween<double>(
      begin: 0.98,
      end: 1.035,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _glow = Tween<double>(
      begin: 0.18,
      end: 0.42,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant DominoBoneyardPile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.count < oldWidget.count) {
      _drawController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _drawController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _pulseController,
          _drawController,
        ]),
        builder: (context, child) {
          final pulseScale = widget.enabled ? _scale.value : 1.0;
          final glow = widget.enabled ? _glow.value : 0.10;

          final drawProgress = _drawController.value;
          final drawDecay = 1 - drawProgress;
          final shakeX = math.sin(drawProgress * math.pi * 5) *
              drawDecay *
              4.5;
          final shakeRotation = math.sin(drawProgress * math.pi * 4) *
              drawDecay *
              0.045;
          final drawScale = 1 -
              math.sin(drawProgress * math.pi) * 0.055;

          return Transform.translate(
            offset: Offset(shakeX, 0),
            child: Transform.rotate(
              angle: shakeRotation,
              child: Transform.scale(
                scale: pulseScale * drawScale,
                child: Container(
                  width: 72,
                  padding: const EdgeInsets.fromLTRB(
                    8,
                    8,
                    8,
                    7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.enabled
                          ? Colors.greenAccent.withValues(alpha: 0.92)
                          : Colors.white24,
                      width: widget.enabled ? 1.7 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.enabled
                            ? Colors.greenAccent.withValues(alpha: glow)
                            : Colors.black26,
                        blurRadius: widget.enabled ? 14 : 5,
                        spreadRadius: widget.enabled ? 1 : 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 42,
                        height: 46,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: const [
                            Positioned(
                              left: 4,
                              top: 0,
                              child: _DominoBack(angle: -0.10),
                            ),
                            Positioned(
                              left: 11,
                              top: 2,
                              child: _DominoBack(angle: 0.05),
                            ),
                            Positioned(
                              left: 18,
                              top: 4,
                              child: _DominoBack(angle: 0.12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: FadeTransition(
                              opacity: animation,
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          'Базар ${widget.count}',
                          key: ValueKey(widget.count),
                          style: TextStyle(
                            color: widget.enabled
                                ? Colors.greenAccent
                                : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DominoBack extends StatelessWidget {
  final double angle;

  const _DominoBack({
    required this.angle,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 22,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF66717D),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: Colors.white70,
            width: 1.4,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 3,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: const Color(0xFF33404D),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
