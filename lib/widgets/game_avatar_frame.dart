import 'package:flutter/material.dart';

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
    // The PNG frame has a relatively thin transparent opening. Some screens
    // previously passed large paddings (for example 15px on a 126px avatar),
    // which made the actual photo look noticeably smaller than the circle.
    // Cap the inset proportionally so the photo always fills the visible hole.
    final maxFrameInset = size * 0.06;
    final effectiveInset = innerPadding.clamp(0.0, maxFrameInset).toDouble();

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(effectiveInset),
              child: ClipOval(
                child: SizedBox.expand(
                  child: child,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                'assets/ui/avatar_frame.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
