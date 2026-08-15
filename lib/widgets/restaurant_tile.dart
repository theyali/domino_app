import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/restaurant.dart';
import '../theme/app_colors.dart';

class RestaurantTile extends StatelessWidget {
  final Restaurant restaurant;
  final VoidCallback onTap;

  const RestaurantTile({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Material(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                _RestaurantLogo(restaurant: restaurant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.table_restaurant_rounded,
                            size: 15,
                            color: AppColors.brassLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${restaurant.waitingRooms}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.groups_rounded,
                            size: 16,
                            color: AppColors.lime,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            context.tr(
                              'players_online',
                              arguments: {'count': restaurant.players},
                            ),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ),
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
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brassLight, AppColors.brassDark],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: imageUrl?.isNotEmpty == true
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => const _LogoFallback(),
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
      color: AppColors.badge,
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_rounded,
        color: AppColors.cream,
        size: 28,
      ),
    );
  }
}
