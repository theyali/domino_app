import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/game_room.dart';

class GameRoomCard extends StatelessWidget {
  final GameRoom room;
  final VoidCallback? onTap;

  const GameRoomCard({
    super.key,
    required this.room,
    this.onTap,
  });

  Color get _cardColor {
    const colors = [
      Color(0xFF79CDF1),
      Color(0xFFFFD65C),
      Color(0xFF8CDD79),
      Color(0xFFFF8A79),
      Color(0xFFC7A7FF),
    ];
    return colors[room.id % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final canJoin = !room.isFull && room.status == 'waiting';
    final isAz = context.appLanguage.code == 'az';
    final modeLabel = room.isPhone
        ? '${isAz ? 'Telefon' : 'Телефон'} · ${room.targetScore}'
        : '101';

    return GestureDetector(
      onTap: canJoin ? onTap : null,
      child: Opacity(
        opacity: canJoin ? 1 : 0.72,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _RoomCardPalette.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: _RoomCardPalette.ink,
                blurRadius: 0,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: _RoomCardPalette.ink, width: 2.8),
                ),
                child: Icon(
                  room.isPhone
                      ? Icons.add_circle_outline_rounded
                      : room.isLocked
                          ? Icons.lock_rounded
                          : Icons.table_restaurant,
                  color: _RoomCardPalette.ink,
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
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
                              color: _RoomCardPalette.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (room.isLocked)
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _RoomCardPalette.ink,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              color: _RoomCardPalette.ink,
                              size: 15,
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
                        color: _RoomCardPalette.inkSoft,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      children: [
                        _SmallChip(
                          icon: Icons.rule_rounded,
                          label: modeLabel,
                          color: room.isPhone
                              ? const Color(0xFF79CDF1)
                              : const Color(0xFFFFE8A3),
                        ),
                        _SmallChip(
                          icon: Icons.group_rounded,
                          label: '${room.currentPlayers} / ${room.maxPlayers}',
                          color: Colors.white,
                        ),
                        _SmallChip(
                          label: context.tr(room.isFull ? 'full' : 'join'),
                          color: room.isFull
                              ? const Color(0xFFFF8A79)
                              : const Color(0xFF7CFC00),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canJoin) ...[
                const SizedBox(width: 10),
                Image.asset(
                  'assets/ui/right-arrow.png',
                  width: 43,
                  height: 43,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ],
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
  final Color color;

  const _SmallChip({
    this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _RoomCardPalette.ink, width: 2.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: _RoomCardPalette.ink),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              color: _RoomCardPalette.ink,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomCardPalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF4A4037);
}
