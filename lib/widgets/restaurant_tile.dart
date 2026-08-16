import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
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
            color: PlayPalette.blue,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: const Color(0x33FFFFFF),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x52000000),
                blurRadius: 18,
                offset: Offset(0, 9),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                Positioned(
                  top: -38,
                  right: -32,
                  child: Container(
                    width: 115,
                    height: 115,
                    decoration: const BoxDecoration(
                      color: Color(0x12FFFFFF),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RestaurantLogo(restaurant: restaurant),
                          const Spacer(),
                          Container(
                            width: 31,
                            height: 31,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_rounded,
                              color: PlayPalette.blue,
                              size: 19,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _RestaurantStatBadge(
                              icon: Icons.table_restaurant_rounded,
                              value: '${restaurant.waitingRooms}',
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: _RestaurantStatBadge(
                              icon: Icons.groups_rounded,
                              value: '${restaurant.players}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
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
                          Expanded(
                            child: Text(
                              context.tr(
                                'players_online',
                                arguments: {'count': restaurant.players},
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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

class _RestaurantStatBadge extends StatelessWidget {
  final IconData icon;
  final String value;

  const _RestaurantStatBadge({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 31,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: PlayPalette.ink),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: PlayPalette.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
      width: 68,
      height: 68,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
        size: 30,
      ),
    );
  }
}
