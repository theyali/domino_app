import 'package:flutter/material.dart';

import '../models/player.dart';
import '../services/emotion_realtime_service.dart';
import 'emotion_picker_sheet.dart';
import 'player_emotion_overlay.dart';

class PlayerAvatar extends StatelessWidget {
  final Player player;
  final VoidCallback onTap;

  final bool isActive;
  final int? turnSecondsLeft;
  final double turnProgress;
  final int dominoCount;
  final bool? isOnline;

  const PlayerAvatar({
    super.key,
    required this.player,
    required this.onTap,
    required this.dominoCount,
    this.isActive = false,
    this.turnSecondsLeft,
    this.turnProgress = 0,
    this.isOnline,
  });

  Future<void> _handleTap(BuildContext context) async {
    final isMultiplayerAvatar = isOnline != null;

    if (!player.isMe || !isMultiplayerAvatar) {
      onTap();
      return;
    }

    await EmotionPickerSheet.show(
      context,
      onSelected: (emotionAsset) {
        final sent = EmotionRealtimeService.instance.sendEmotion(emotionAsset);
        if (!sent && context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Эмоцию можно отправить после восстановления realtime.',
                ),
              ),
            );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarBorderColor =
        isActive
            ? Colors.greenAccent
            : player.isMe
                ? Colors.green
                : Colors.white;

    final nameColor =
        isActive
            ? Colors.greenAccent
            : player.isMe
                ? Colors.greenAccent
                : Colors.white;

    final avatarLetter = player.name.trim().isEmpty
        ? '?'
        : player.name.trim().substring(0, 1).toUpperCase();

    return GestureDetector(
      onTap: () => _handleTap(context),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 88,
            height: 80,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 10,
                  top: 6,
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isActive)
                          SizedBox(
                            width: 68,
                            height: 68,
                            child: CircularProgressIndicator(
                              value: turnProgress
                                  .clamp(0.0, 1.0)
                                  .toDouble(),
                              strokeWidth: 4,
                              backgroundColor:
                                  Colors.black.withValues(
                                alpha: 0.30,
                              ),
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                Colors.greenAccent,
                              ),
                            ),
                          ),

                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: isActive ? 3 : 2.5,
                              color: avatarBorderColor,
                            ),
                            boxShadow: isActive
                                ? [
                                    BoxShadow(
                                      color: Colors.greenAccent.withValues(
                                        alpha: 0.28,
                                      ),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.grey.shade300,
                            child: Text(
                              avatarLetter,
                              style: const TextStyle(
                                color: Color(0xFF5B3A9E),
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Positioned(
                  top: 0,
                  right: 0,
                  child: _RoundBadge(
                    text: '${player.score}',
                    minWidth: 27,
                    backgroundColor:
                        const Color(0xFF0B1F33),
                    borderColor: Colors.white,
                  ),
                ),

                if (isActive && turnSecondsLeft != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _RoundBadge(
                      text: '$turnSecondsLeft',
                      minWidth: 31,
                      backgroundColor:
                          const Color(0xFF123C2B),
                      borderColor:
                          Colors.greenAccent,
                    ),
                  ),

                if (isOnline != null)
                  Positioned(
                    left: 10,
                    bottom: 5,
                    child: _PresenceDot(isOnline: isOnline!),
                  ),

                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 24,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF15283A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(
                          alpha: 0.78,
                        ),
                        width: 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: 0.28,
                          ),
                          blurRadius: 5,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _MiniDominoIcon(),
                        const SizedBox(width: 4),
                        Text(
                          '$dominoCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (isOnline != null)
                  Positioned.fill(
                    child: PlayerEmotionOverlay(playerId: player.id),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 2),

          Text(
            player.isMe
                ? '${player.name} (Ты)'
                : player.name,
            style: TextStyle(
              color: nameColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  final bool isOnline;

  const _PresenceDot({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? Colors.greenAccent : Colors.blueGrey.shade300;

    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(
          color: const Color(0xFF0D1B2A),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _RoundBadge extends StatelessWidget {
  final String text;
  final double minWidth;
  final Color backgroundColor;
  final Color borderColor;

  const _RoundBadge({
    required this.text,
    required this.minWidth,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 27,
      constraints: BoxConstraints(
        minWidth: minWidth,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: 1.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniDominoIcon extends StatelessWidget {
  const _MiniDominoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2.5),
      ),
      child: Column(
        children: [
          const Expanded(
            child: SizedBox(),
          ),
          Container(
            height: 1,
            color: const Color(0xFF15283A),
          ),
          const Expanded(
            child: SizedBox(),
          ),
        ],
      ),
    );
  }
}
