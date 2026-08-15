import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class CartoonPageBackground extends StatelessWidget {
  final Widget child;
  final double noiseOpacity;

  const CartoonPageBackground({
    super.key,
    required this.child,
    this.noiseOpacity = 0.045,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Stack(
        fit: StackFit.expand,
        children: [
          IgnorePointer(
            child: Opacity(
              opacity: noiseOpacity,
              child: Image.asset(
                'assets/ui/background_noise.avif',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.low,
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
