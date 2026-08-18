import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/game_room.dart';
import '../theme/play_palette.dart';

class GameRoomCard extends StatelessWidget {
  final GameRoom room;
  final VoidCallback? onTap;

  const GameRoomCard({
    super.key,
    required this.room,
    this.onTap,
  });

  int get _backgroundIndex {
    final mixed = room.id * 1103515245 + 12345;
    return (mixed.abs() % 5) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final canJoin = !room.isFull && room.status == 'waiting';
    final isAz = context.appLanguage.code == 'az';
    final modeLabel = room.isPhone
        ? '${isAz ? 'Telefon' : 'Телефон'} · ${room.targetScore}'
        : '101';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canJoin ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: canJoin ? 1 : 0.58,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: PlayPalette.blue,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/ui/long_$_backgroundIndex.webp',
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: PlayPalette.blue),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(
                        room.isPhone
                            ? Icons.add_circle_outline_rounded
                            : room.isLocked
                                ? Icons.lock_rounded
                                : Icons.table_restaurant_rounded,
                        color: PlayPalette.blue,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  room.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              if (room.isLocked)
                                Container(
                                  width: 29,
                                  height: 29,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: PlayPalette.navy,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.tr(
                              'creator',
                              arguments: {'name': room.ownerName},
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xD9FFFFFF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              _SmallChip(
                                icon: Icons.rule_rounded,
                                label: modeLabel,
                              ),
                              _SmallChip(
                                icon: Icons.group_rounded,
                                label:
                                    '${room.currentPlayers} / ${room.maxPlayers}',
                              ),
                              _SmallChip(
                                label: context.tr(room.isFull ? 'full' : 'join'),
                                highlighted: canJoin,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (canJoin) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: PlayPalette.blue,
                          size: 23,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool highlighted;

  const _SmallChip({
    this.icon,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? PlayPalette.navy : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 15,
              color: highlighted ? Colors.white : PlayPalette.ink,
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: highlighted ? Colors.white : PlayPalette.ink,
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
