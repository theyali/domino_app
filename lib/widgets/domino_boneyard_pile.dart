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
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.panelTop,
                          AppColors.panelBottom,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(21),
                      border: Border.all(
                        color: AppColors.brass.withValues(
                          alpha: widget.enabled ? 0.78 : 0.38,
                        ),
                        width: widget.enabled ? 1.6 : 1.1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 11,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Positioned(
                          left: 10,
                          top: 14,
                          child: _DominoBack(angle: -0.16),
                        ),
                        const Positioned(
                          left: 20,
                          top: 10,
                          child: _DominoBack(angle: -0.01),
                        ),
                        const Positioned(
                          left: 30,
                          top: 14,
                          child: _DominoBack(angle: 0.16),
                        ),
                        Positioned(
                          left: 5,
                          bottom: 5,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.badge,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.brass.withValues(alpha: 0.62),
                                width: 1.1,
                              ),
                            ),
                            child: Icon(
                              Icons.touch_app_rounded,
                              color: widget.enabled
                                  ? AppColors.lime
                                  : Colors.white54,
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
                                minWidth: 27,
                                minHeight: 27,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.lime,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.ink,
                                  width: 1.6,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
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
                ),
              ),
            );
          },
        ),
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
        width: 21,
        height: 36,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFB7C4D0),
              Color(0xFF5D6E7D),
            ],
          ),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: AppColors.cream,
            width: 1.7,
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
            width: 6.5,
            height: 6.5,
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
