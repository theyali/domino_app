import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/user_account.dart';
import 'inventory_screen.dart';
import 'profile_screen.dart';
import 'restaurants_screen.dart';

class MainShellScreen extends StatefulWidget {
  final UserAccount user;
  final ValueChanged<UserAccount> onUserUpdated;
  final Future<void> Function() onLogout;

  const MainShellScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      const RestaurantsScreen(),
      const InventoryScreen(),
      ProfileScreen(
        user: widget.user,
        onUserUpdated: widget.onUserUpdated,
        onLogout: widget.onLogout,
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) {
          setState(() {
            _index = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant_rounded),
            label: context.tr('restaurants'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.card_giftcard_outlined),
            selectedIcon: const Icon(Icons.card_giftcard_rounded),
            label: context.tr('inventory'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: context.tr('profile'),
          ),
        ],
      ),
    );
  }
}
