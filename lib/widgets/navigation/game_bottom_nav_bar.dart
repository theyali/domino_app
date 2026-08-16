import 'package:flutter/material.dart';

import '../../services/sound_effects_service.dart';
import '../../theme/play_palette.dart';

class GameBottomNavItemData {
  final IconData? icon;
  final String? assetPath;
  final String label;
  final int badgeCount;

  const GameBottomNavItemData({
    this.icon,
    this.assetPath,
    required this.label,
    this.badgeCount = 0,
  }) : assert(icon != null || assetPath != null);
}

class GameBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final List<GameBottomNavItemData> items;
  final ValueChanged<int> onSelected;

  const GameBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: const BoxDecoration(
        color: PlayPalette.navy,
        borderRadius: BorderRadius.all(Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 20,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(8, 9, 8, 7),
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _GameBottomNavItem(
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

class _GameBottomNavItem extends StatelessWidget {
  final GameBottomNavItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _GameBottomNavItem({
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
        onTap: () {
          SoundEffectsService.button(alternate: true);
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          padding: const EdgeInsets.fromLTRB(3, 6, 3, 4),
          decoration: BoxDecoration(
            color: selected ? PlayPalette.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected ? PlayPalette.blue : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x44000000),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: selected ? 40 : 36,
                    height: selected ? 36 : 33,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: PlayPalette.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: data.assetPath != null
                        ? Image.asset(
                            data.assetPath!,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          )
                        : Icon(
                            data.icon,
                            size: 21,
                            color: PlayPalette.ink,
                          ),
                  ),
                  if (data.badgeCount > 0)
                    Positioned(
                      top: -8,
                      right: -10,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: PlayPalette.coral,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: PlayPalette.white,
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          data.badgeCount > 99 ? '99+' : '${data.badgeCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : PlayPalette.muted,
                  fontSize: 9.2,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0.05,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
