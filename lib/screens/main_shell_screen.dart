import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../localization/statistics_strings.dart';
import '../models/user_account.dart';
import 'inventory_screen.dart';
import 'profile_screen.dart';
import 'restaurants_screen.dart';
import 'statistics_screen.dart';

class MainShellScreen extends StatefulWidget {
  final UserAccount user;
  final Future<void> Function() onLogout;

  const MainShellScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _index = 0;
  late UserAccount _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  @override
  void didUpdateWidget(covariant MainShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _user = widget.user;
    }
  }

  void _handleUserUpdated(UserAccount user) {
    setState(() {
      _user = user;
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsStrings = StatisticsStrings.of(context);
    final screens = [
      const RestaurantsScreen(),
      const StatisticsScreen(),
      const InventoryScreen(),
      ProfileScreen(
        user: _user,
        onUserUpdated: _handleUserUpdated,
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
            icon: const Icon(Icons.sports_esports_outlined),
            selectedIcon: const Icon(Icons.sports_esports_rounded),
            label: statsStrings.play,
          ),
          NavigationDestination(
            icon: const Icon(Icons.leaderboard_outlined),
            selectedIcon: const Icon(Icons.leaderboard_rounded),
            label: statsStrings.title,
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
