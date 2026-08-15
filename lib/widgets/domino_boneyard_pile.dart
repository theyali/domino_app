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
      end: 1.025,
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

    return Tooltip(
      message: '$boneyardLabel: ${widget.count}',
      child: Padding(
        // Positioned в игровом поле привязан к правому нижнему углу.
        // Этот внутренний запас визуально сдвигает иконку влево и вверх,
        // чтобы угловой шуруп стола оставался виден.
        padding: const EdgeInsets.only(right: 12, bottom: 12),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.enabled ? widget.onTap : null,
          child: AnimatedBuilder(
            animation: Listenable.merge([
              _pulseController,
              _drawController,
            ]),
            builder: (context, child) {
              final pulseScale = widget.enabled ? _scale.value : 1.0;

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
                    child: Container(
                      width: 66,
                      height: 66,
                      decoration: BoxDecoration(
                        color: widget.enabled
                            ? AppColors.cartoonYellow
                            : const Color(0xFFD8C89E),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.ink,
                          width: 2.7,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.ink,
                            blurRadius: 0,
                            offset: Offset(3, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Positioned(
                            left: 9,
                            top: 15,
                            child: _DominoBack(
                              angle: -0.16,
                              color: AppColors.cartoonCoral,
                            ),
                          ),
                          const Positioned(
                            left: 20,
                            top: 10,
                            child: _DominoBack(
                              angle: -0.01,
                              color: AppColors.cream,
                            ),
                          ),
                          const Positioned(
                            left: 31,
                            top: 15,
                            child: _DominoBack(
                              angle: 0.16,
                              color: AppColors.cartoonMint,
                            ),
                          ),
                          Positioned(
                            left: 5,
                            bottom: 5,
                            child: Container(
                              width: 21,
                              height: 21,
                              decoration: BoxDecoration(
                                color: AppColors.cartoonCoral,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.ink,
                                  width: 1.7,
                                ),
                              ),
                              child: Icon(
                                Icons.touch_app_rounded,
                                color: widget.enabled
                                    ? AppColors.ink
                                    : AppColors.ink.withValues(alpha: 0.45),
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 5),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.lime,
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
