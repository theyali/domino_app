import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/restaurant.dart';

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
  static const List<Color> _cardColors = [
    Color(0xFF62C7F3),
    Color(0xFFFFD95A),
    Color(0xFF86D86F),
    Color(0xFFFF816F),
    Color(0xFFC69AF4),
  ];

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final restaurant = widget.restaurant;
    final cardColor = _cardColors[(restaurant.id - 1) % _cardColors.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.975 : 1,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.black,
                width: 2.8,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 0,
                  offset: Offset(4, 5),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
            child: Row(
              children: [
                _RestaurantLogo(restaurant: restaurant),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 18.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          shadows: [
                            Shadow(
                              color: Colors.white38,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          _RestaurantStatBadge(
                            icon: Icons.table_restaurant_rounded,
                            value: '${restaurant.waitingRooms}',
                          ),
                          _RestaurantStatBadge(
                            icon: Icons.groups_rounded,
                            value: '${restaurant.players}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        context.tr(
                          'players_online',
                          arguments: {'count': restaurant.players},
                        ),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Image.asset(
                    'assets/ui/right-arrow.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.black,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.black),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 12,
              fontWeight: FontWeight.w900,
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
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: Colors.black,
          width: 2.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 0,
            offset: Offset(3, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
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
      color: const Color(0xFFFFF0C7),
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_rounded,
        color: Colors.black,
        size: 32,
      ),
    );
  }
}
