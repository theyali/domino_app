import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GameAvatarFrame extends StatelessWidget {
  final double size;
  final Widget child;
  final double innerPadding;

  const GameAvatarFrame({
    super.key,
    required this.size,
    required this.child,
    this.innerPadding = 8,
  });

  @override
  Widget build(BuildContext context) {
    final ringThickness = innerPadding
        .clamp(
          math.max(4.0, size * 0.07),
          math.max(5.0, size * 0.11),
        )
        .toDouble();
    final shadowOffset = math.max(2.0, size * 0.035).toDouble();
    final borderWidth = math.max(2.0, size * 0.025).toDouble();
    final innerBorderWidth = math.max(1.5, size * 0.016).toDouble();

    return SizedBox(
      width: size,
      height: size + shadowOffset,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: shadowOffset,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(ringThickness),
            decoration: BoxDecoration(
              color: AppColors.cartoonYellow,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.ink,
                width: borderWidth,
              ),
            ),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.cream,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.ink,
                  width: innerBorderWidth,
                ),
              ),
              child: ClipOval(
                child: SizedBox.expand(child: child),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
