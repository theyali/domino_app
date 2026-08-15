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
    // avatar_frame.png has a fixed circular opening. The previous implementation
    // let every screen use a different inset and then capped it too aggressively,
    // so the photo could extend underneath the coloured artwork.
    //
    // Keep one proportional safe area for every avatar size. About 9% on each
    // side leaves the image visually full while keeping it inside the inner edge
    // of the illustrated frame on profile, statistics and future usages.
    final frameSafeInset = size * 0.09;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(frameSafeInset),
              child: ClipOval(
                clipBehavior: Clip.antiAlias,
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: size,
                      height: size,
                      child: child,
                    ),
                  ),
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
