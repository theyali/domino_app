import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/restaurant.dart';
import '../theme/app_colors.dart';

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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.985 : 1,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF183047), Color(0xFF0B1826)],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: AppColors.brass.withValues(alpha: 0.48),
                width: 1.35,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 15,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -38,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brass.withValues(alpha: 0.055),
                      ),
                    ),
                  ),
                  Padding(
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
                                  color: AppColors.cream,
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
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
                                    accent: AppColors.brassLight,
                                  ),
                                  _RestaurantStatBadge(
                                    icon: Icons.groups_rounded,
                                    value: '${restaurant.players}',
                                    accent: AppColors.lime,
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
                                  color: Colors.white54,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: AppColors.brass.withValues(alpha: 0.28),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_forward_rounded,
                            color: AppColors.brassLight,
                            size: 22,
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
      ),
    );
  }
}

class _RestaurantStatBadge extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color accent;

  const _RestaurantStatBadge({
    required this.icon,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.19),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: accent),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
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
      width: 74,
      height: 74,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brassLight, AppColors.brass, AppColors.brassDark],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 9,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.badgeLight, AppColors.badge],
        ),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_rounded,
        color: AppColors.cream,
        size: 32,
      ),
    );
  }
}
