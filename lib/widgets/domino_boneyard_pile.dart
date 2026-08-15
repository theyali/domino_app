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
  State<DominoBoneyardPile> createState() => _DominoBoneyardPileState();
}

class _DominoBoneyardPileState extends State<DominoBoneyardPile>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _drawController;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _scale = Tween<double>(
      begin: 0.99,
      end: 1.035,
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
    final active = widget.enabled;

    return Tooltip(
      message: '$boneyardLabel: ${widget.count}',
      child: Padding(
        // Оставляем угловой шуруп на своём месте и уводим базар левее.
        padding: const EdgeInsets.only(right: 64, bottom: 12),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: active ? widget.onTap : null,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _pulseController,
              _drawController,
            ]),
            builder: (context, child) {
              final pulseScale = active ? _scale.value : 1.0;

              final drawProgress = _drawController.value;
              final drawDecay = 1 - drawProgress;
              final shakeX = math.sin(drawProgress * math.pi * 5) *
                  drawDecay *
                  4.0;
              final shakeRotation = math.sin(drawProgress * math.pi * 4) *
                  drawDecay *
                  0.04;
              final drawScale =
                  1 - math.sin(drawProgress * math.pi) * 0.05;

              return Transform.translate(
                offset: Offset(shakeX, 0),
                child: Transform.rotate(
                  angle: shakeRotation,
                  child: Transform.scale(
                    scale: pulseScale * drawScale,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: active ? 1 : 0.55,
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          color: active
                              ? AppColors.cartoonYellow
                              : const Color(0xFF4E4740),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: active ? AppColors.lime : AppColors.ink,
                            width: active ? 3.2 : 2.7,
                          ),
                          boxShadow: [
                            const BoxShadow(
                              color: AppColors.ink,
                              blurRadius: 0,
                              offset: Offset(3, 4),
                            ),
                            if (active)
                              BoxShadow(
                                color: AppColors.lime.withValues(alpha: 0.55),
                                blurRadius: 13,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: 9,
                              top: 15,
                              child: _DominoBack(
                                angle: -0.16,
                                color: active
                                    ? AppColors.cartoonCoral
                                    : const Color(0xFF716961),
                              ),
                            ),
                            Positioned(
                              left: 20,
                              top: 10,
                              child: _DominoBack(
                                angle: -0.01,
                                color: active
                                    ? AppColors.cream
                                    : const Color(0xFF837B72),
                              ),
                            ),
                            Positioned(
                              left: 31,
                              top: 15,
                              child: _DominoBack(
                                angle: 0.16,
                                color: active
                                    ? AppColors.cartoonMint
                                    : const Color(0xFF69645F),
                              ),
                            ),
                            Positioned(
                              left: 5,
                              bottom: 5,
                              child: Container(
                                width: 21,
                                height: 21,
                                decoration: BoxDecoration(
                                  color: active
                                      ? AppColors.cartoonCoral
                                      : const Color(0xFF6E675F),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.ink,
                                    width: 1.7,
                                  ),
                                ),
                                child: Icon(
                                  Icons.touch_app_rounded,
                                  color: active
                                      ? AppColors.ink
                                      : AppColors.ink.withValues(alpha: 0.6),
                                  size: 13,
                                ),
                              ),
                            ),
                            Positioned(
                              right: -5,
                              top: -6,
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
                                    minWidth: 29,
                                    minHeight: 29,
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 5),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? AppColors.lime
                                        : const Color(0xFF8A8178),
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: AppColors.ink,
                                      width: 1.8,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: AppColors.ink,
                                        blurRadius: 0,
                                        offset: Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${widget.count}',
                                    style: const TextStyle(
                                      color: AppColors.ink,
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
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DominoBack extends StatelessWidget {
  final double angle;
  final Color color;

  const _DominoBack({
    required this.angle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 21,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: AppColors.ink,
            width: 1.7,
          ),
          boxShadow: const [
            BoxShadow(
              color: AppColors.ink,
              blurRadius: 0,
              offset: Offset(1, 3),
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 6.5,
            height: 6.5,
            decoration: BoxDecoration(
              color: AppColors.ink,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white54,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
