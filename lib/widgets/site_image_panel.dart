import 'package:flutter/material.dart';

/// Универсальная карточка нового UI: фоновая иллюстрация block_/long_,
/// затемняющий слой и контент поверх него.
class SiteImagePanel extends StatelessWidget {
  final String assetPath;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color overlayColor;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;

  const SiteImagePanel({
    super.key,
    required this.assetPath,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 24,
    this.overlayColor = const Color(0x8F121212),
    this.backgroundColor = const Color(0xFF262628),
    this.borderColor = const Color(0x2AFFFFFF),
    this.borderWidth = 1,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: boxShadow ??
            const [
              BoxShadow(
                color: Color(0x4A000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => ColoredBox(
                color: backgroundColor,
              ),
            ),
          ),
          Positioned.fill(
            child: ColoredBox(color: overlayColor),
          ),
          Padding(
            padding: padding,
            child: child,
          ),
        ],
      ),
    );
  }
}
