import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/app_colors.dart';

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
      duration: const Duration(milliseconds: 820),
    )..repeat(reverse: true);

    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _scale = Tween<double>(
      begin: 0.985,
      end: 1.035,
    ).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _glow = Tween<double>(
      begin: 0.16,
      end: 0.34,
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
    final boneyardLabel = context.appLanguage.code == 'az' ? 'Bazar' : 'Базар';

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
          final glow = widget.enabled ? _glow.value : 0.08;

          final drawProgress = _drawController.value;
          final drawDecay = 1 - drawProgress;
          final shakeX = math.sin(drawProgress * math.pi * 5) *
              drawDecay *
              4.2;
          final shakeRotation = math.sin(drawProgress * math.pi * 4) *
              drawDecay *
              0.042;
          final drawScale =
              1 - math.sin(drawProgress * math.pi) * 0.05;

          return Transform.translate(
            offset: Offset(shakeX, 0),
            child: Transform.rotate(
              angle: shakeRotation,
              child: Transform.scale(
                scale: pulseScale * drawScale,
                child: Container(
                  width: 82,
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.panelTop,
                        AppColors.panelBottom,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: widget.enabled
                          ? AppColors.lime
                          : Colors.white.withValues(alpha: 0.24),
                      width: widget.enabled ? 2.2 : 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.42),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                      if (widget.enabled)
                        BoxShadow(
                          color: AppColors.lime.withValues(alpha: glow),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 54,
                        height: 50,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Positioned(
                              left: 4,
                              top: 5,
                              child: _DominoBack(angle: -0.13),
                            ),
                            const Positioned(
                              left: 13,
                              top: 3,
                              child: _DominoBack(angle: 0.02),
                            ),
                            const Positioned(
                              left: 22,
                              top: 5,
                              child: _DominoBack(angle: 0.13),
                            ),
                            Positioned(
                              right: -3,
                              top: -5,
                              child: AnimatedSwitcher(
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
                                child: Container(
                                  key: ValueKey(widget.count),
                                  constraints: const BoxConstraints(
                                    minWidth: 25,
                                    minHeight: 25,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.lime,
                                    borderRadius: BorderRadius.circular(13),
                                    border: Border.all(
                                      color: Colors.black87,
                                      width: 1.5,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black38,
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${widget.count}',
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        boneyardLabel,
                        style: TextStyle(
                          color: widget.enabled
                              ? AppColors.lime
                              : Colors.white70,
                          fontSize: 11.5,
                          letterSpacing: 0.2,
                          fontWeight: FontWeight.w900,
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
        width: 24,
        height: 40,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF9AA8B6),
              Color(0xFF566574),
            ],
          ),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: AppColors.cream,
            width: 1.8,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 4,
              offset: Offset(1, 3),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: AppColors.badge,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
