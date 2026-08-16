import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CartoonPageBackground extends StatelessWidget {
  final Widget child;

  /// Kept for backward compatibility with older call sites.
  /// The app background is now intentionally flat, without texture/noise.
  final double noiseOpacity;

  const CartoonPageBackground({
    super.key,
    required this.child,
    this.noiseOpacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: child,
    );
  }
}
