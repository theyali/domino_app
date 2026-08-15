import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CartoonPageBackground extends StatelessWidget {
  final Widget child;

  /// Kept for backward compatibility with older call sites.
  /// The new wooden background is intentionally rendered at full opacity.
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                'assets/ui/background_noise.avif',
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.expand(),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
