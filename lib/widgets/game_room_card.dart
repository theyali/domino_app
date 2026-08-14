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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canJoin = !room.isFull && room.status == 'waiting';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canJoin ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  room.isLocked ? Icons.lock_rounded : Icons.table_restaurant,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
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
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (room.isLocked)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.lock_outline_rounded, size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      context.tr(
                        'creator',
                        arguments: {'name': room.ownerName},
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.group_rounded,
                          size: 18,
                          color: canJoin
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${room.currentPlayers} / ${room.maxPlayers}',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: canJoin
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          context.tr(room.isFull ? 'full' : 'join'),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: canJoin
                                ? theme.colorScheme.primary
                                : theme.colorScheme.outline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: canJoin
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                      ],
                    ),
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
