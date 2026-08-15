import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../localization/statistics_strings.dart';
import '../models/user_account.dart';
import '../widgets/cartoon_page_background.dart';
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
        accent: const Color(0xFF66C7F0),
      ),
      _NavItemData(
        icon: Icons.bar_chart_rounded,
        label: statsStrings.title,
        accent: const Color(0xFFFFD85A),
      ),
      _NavItemData(
        icon: Icons.card_giftcard_rounded,
        label: context.tr('inventory'),
        accent: const Color(0xFF82D66E),
      ),
      _NavItemData(
        icon: Icons.person_rounded,
        label: context.tr('profile'),
        accent: const Color(0xFFFF806F),
      ),
    ];

    return CartoonPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: _index,
          children: screens,
        ),
        bottomNavigationBar: _CartoonGameDock(
          selectedIndex: _index,
          items: items,
          onSelected: _selectTab,
        ),
      ),
    );
  }
}

class _CartoonGameDock extends StatelessWidget {
  static const _dockColor = Color(0xFFF5CE79);
  static const _ink = Color(0xFF17120D);
  static const _cream = Color(0xFFFFF3CC);

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
      decoration: const BoxDecoration(
        color: _dockColor,
        border: Border(
          top: BorderSide(color: _ink, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 0,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(8, 7, 8, 5),
        child: SizedBox(
          height: 78,
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
  static const _ink = Color(0xFF17120D);
  static const _cream = Color(0xFFFFF3CC);

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
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 3),
          decoration: BoxDecoration(
            color: selected ? data.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? _ink : Colors.transparent,
              width: selected ? 2.6 : 0,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: _ink,
                      blurRadius: 0,
                      offset: Offset(3, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: selected ? 44 : 39,
                height: selected ? 38 : 34,
                decoration: BoxDecoration(
                  color: selected ? _cream : Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: _ink,
                    width: 2.4,
                  ),
                  boxShadow: selected
                      ? const [
                          BoxShadow(
                            color: _ink,
                            blurRadius: 0,
                            offset: Offset(2, 2),
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  data.icon,
                  size: 22,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _ink,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
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
  final Color accent;

  const _NavItemData({
    required this.icon,
    required this.label,
    required this.accent,
  });
}
