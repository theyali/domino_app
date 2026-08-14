import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/restaurant.dart';

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
    return ListTile(
      leading: const Icon(Icons.restaurant),
      title: Text(restaurant.name),
      subtitle: Text(
        context.tr(
          'players_online',
          arguments: {'count': restaurant.players},
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
