import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../localization/statistics_strings.dart';
import '../models/user_account.dart';
import '../theme/app_colors.dart';
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
  int _statisticsRefreshToken = 0;
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

  void _selectTab(int index) {
    if (_index == index && index != 1) return;

    setState(() {
      _index = index;
      if (index == 1) {
        _statisticsRefreshToken += 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsStrings = StatisticsStrings.of(context);
    final screens = [
      const RestaurantsScreen(),
      StatisticsScreen(key: ValueKey(_statisticsRefreshToken)),
      const InventoryScreen(),
      ProfileScreen(
        user: _user,
        onUserUpdated: _handleUserUpdated,
        onLogout: widget.onLogout,
      ),
    ];

    final items = [
      _NavItemData(
        icon: Icons.sports_esports_rounded,
        label: statsStrings.play,
      ),
      _NavItemData(
        icon: Icons.bar_chart_rounded,
        label: statsStrings.title,
      ),
      _NavItemData(
        icon: Icons.card_giftcard_rounded,
        label: context.tr('inventory'),
      ),
      _NavItemData(
        icon: Icons.person_rounded,
        label: context.tr('profile'),
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _index,
        children: screens,
      ),
      bottomNavigationBar: _CartoonGameDock(
        selectedIndex: _index,
        items: items,
        onSelected: _selectTab,
      ),
    );
  }
}

class _CartoonGameDock extends StatelessWidget {
  final int selectedIndex;
  final List<_NavItemData> items;
  final ValueChanged<int> onSelected;

  const _CartoonGameDock({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1A2A),
        border: Border(
          top: BorderSide(
            color: AppColors.brass.withValues(alpha: 0.34),
            width: 1.2,
          ),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, -7),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(8, 7, 8, 5),
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _CartoonNavItem(
                    data: items[index],
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartoonNavItem extends StatelessWidget {
  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _CartoonNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.fromLTRB(4, 5, 4, 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? AppColors.lime.withValues(alpha: 0.10)
                : Colors.transparent,
            border: Border.all(
              color: selected
                  ? AppColors.lime.withValues(alpha: 0.38)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 43 : 38,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: selected
                      ? AppColors.lime
                      : const Color(0xFF13263A),
                  border: Border.all(
                    color: selected
                        ? AppColors.limeDark
                        : AppColors.brass.withValues(alpha: 0.18),
                    width: 1.1,
                  ),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: Colors.black38,
                            blurRadius: 6,
                            offset: Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  data.icon,
                  size: 22,
                  color: selected ? AppColors.ink : Colors.white54,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? AppColors.lime : Colors.white54,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  const _NavItemData({required this.icon, required this.label});
}
