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
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          Padding(
            padding: EdgeInsets.all(innerPadding),
            child: ClipOval(child: child),
          ),
          IgnorePointer(
            child: Image.asset(
              'assets/ui/avatar_frame.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}
