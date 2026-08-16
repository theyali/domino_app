import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import '../theme/play_palette.dart';

class RestaurantTile extends StatefulWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const RestaurantTile({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  State<RestaurantTile> createState() => _RestaurantTileState();
}

class _RestaurantTileState extends State<RestaurantTile> {
  bool _pressed = false;

  int get _blockIndex {
    final mixed = widget.restaurant.id * 1103515245 + 12345;
    return (mixed.abs() % 4) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.965 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: PlayPalette.navySoft,
            borderRadius: BorderRadius.circular(25),
            boxShadow: const [
              BoxShadow(
                color: Color(0x52000000),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _RestaurantBlockBackground(blockIndex: _blockIndex),
                      Positioned(
                        left: 13,
                        top: 13,
                        child: _RestaurantLogo(restaurant: restaurant),
                      ),
                      Positioned(
                        right: 13,
                        top: 13,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: PlayPalette.blue,
                            size: 21,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 58,
                  width: double.infinity,
                  color: PlayPalette.navySoft,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          restaurant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.25,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF323234),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: PlayPalette.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${restaurant.players}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantBlockBackground extends StatelessWidget {
  final int blockIndex;

  const _RestaurantBlockBackground({required this.blockIndex});

  @override
  Widget build(BuildContext context) {
    final webpPath = 'assets/ui/block_$blockIndex.webp';
    final pngPath = 'assets/ui/block_$blockIndex.png';

    return ColoredBox(
      color: PlayPalette.blue,
      child: Image.asset(
        webpPath,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) {
          return Image.asset(
            pngPath,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
          );
        },
      ),
    );
  }
}

class _RestaurantLogo extends StatelessWidget {
  final Restaurant restaurant;

  const _RestaurantLogo({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final imageUrl = restaurant.imageUrl;

    return Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: imageUrl?.isNotEmpty == true
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) =>
                    const _LogoFallback(),
              )
            : const _LogoFallback(),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: PlayPalette.ice,
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_rounded,
        color: PlayPalette.blue,
        size: 32,
      ),
    );
  }
}
