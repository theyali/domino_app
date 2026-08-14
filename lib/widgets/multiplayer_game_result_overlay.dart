import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/multiplayer_game_state.dart';
import '../theme/app_colors.dart';

class MultiplayerGameResultOverlay extends StatelessWidget {
  final MultiplayerGameState gameState;
  final bool isStartingNextRound;
  final bool isLeaving;
  final VoidCallback onNextRound;
  final VoidCallback onExit;

  const MultiplayerGameResultOverlay({
    super.key,
    required this.gameState,
    required this.isStartingNextRound,
    required this.isLeaving,
    required this.onNextRound,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final result = gameState.roundResult;
    if (result == null) {
      return const SizedBox.shrink();
    }

    final isMatchFinished = gameState.isMatchFinished;
    final reasonTitle = _reasonTitle(context, result.reason, isMatchFinished);
    final reasonSubtitle = _reasonSubtitle(context, result);

    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF102333),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.lime.withValues(alpha: 0.28),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.lime.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      isMatchFinished
                          ? Icons.emoji_events_rounded
                          : result.reason == 'fish'
                              ? Icons.water_rounded
                              : Icons.flag_rounded,
                      color: Colors.amberAccent,
                      size: 46,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      reasonTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reasonSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final player in gameState.players)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _PlayerResultRow(
                          player: player,
                          result: result,
                        ),
                      ),
                    const SizedBox(height: 14),
                    if (gameState.isRoundFinished) ...[
                      if (gameState.myPlayer.isOwner)
                        SizedBox(
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: isStartingNextRound || isLeaving
                                ? null
                                : onNextRound,
                            icon: isStartingNextRound
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.refresh_rounded),
                            label: Text(
                              context.tr(
                                isStartingNextRound
                                    ? 'next_round_loading'
                                    : 'next_round',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            context.tr('wait_owner_next_round'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: isLeaving ? null : onExit,
                        icon: isLeaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.logout_rounded),
                        label: Text(
                          context.tr(isLeaving ? 'leaving' : 'exit_game'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _reasonTitle(
    BuildContext context,
    String reason,
    bool isMatchFinished,
  ) {
    if (reason == 'player_left') {
      return context.tr('match_finished_title');
    }
    if (isMatchFinished) {
      return context.tr('game_101_finished');
    }
    if (reason == 'fish') {
      return context.tr('fish');
    }
    return context.tr('round_finished_title');
  }

  String _reasonSubtitle(BuildContext context, MultiplayerRoundResult result) {
    if (result.reason == 'player_left') {
      final player = _playerById(result.leftPlayerId);
      return player == null
          ? context.tr('one_player_left')
          : context.tr(
              'player_left_match',
              arguments: {'player': player.name},
            );
    }

    if (gameState.isMatchFinished) {
      final loserNames = result.matchLoserPlayerIds
          .map(_playerById)
          .whereType<MultiplayerPlayerState>()
          .map((player) => player.name)
          .join(', ');
      return loserNames.isEmpty
          ? context.tr('match_finished')
          : context.tr(
              'score_101',
              arguments: {'players': loserNames},
            );
    }

    final winners = result.winnerPlayerIds
        .map(_playerById)
        .whereType<MultiplayerPlayerState>()
        .map((player) => player.name)
        .join(', ');

    if (result.reason == 'fish') {
      return winners.isEmpty
          ? context.tr('all_players_blocked')
          : context.tr(
              'minimum_hand_points',
              arguments: {'players': winners},
            );
    }

    return winners.isEmpty
        ? context.tr('last_domino_played')
        : context.tr(
            'round_winner',
            arguments: {'players': winners},
          );
  }

  MultiplayerPlayerState? _playerById(int? playerId) {
    if (playerId == null) return null;
    for (final player in gameState.players) {
      if (player.id == playerId) return player;
    }
    return null;
  }
}

class _PlayerResultRow extends StatelessWidget {
  final MultiplayerPlayerState player;
  final MultiplayerRoundResult result;

  const _PlayerResultRow({
    required this.player,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final handPoints = result.handPoints[player.id] ?? 0;
    final added = result.addedPenalties[player.id] ?? 0;
    final total = result.totalScores[player.id] ?? player.score;
    final isRoundWinner = result.winnerPlayerIds.contains(player.id);
    final isMatchLoser = result.matchLoserPlayerIds.contains(player.id);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMatchLoser
              ? Colors.redAccent.withValues(alpha: 0.65)
              : isRoundWinner
                  ? AppColors.lime.withValues(alpha: 0.65)
                  : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: Colors.white12,
            child: Text(
              player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (!player.isActive) ...[
                      const SizedBox(width: 6),
                      Text(
                        context.tr('left_game'),
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  context.tr(
                    'hand_points_penalty',
                    arguments: {
                      'hand': handPoints,
                      'penalty': added,
                    },
                  ),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$total',
            style: TextStyle(
              color: isMatchLoser ? Colors.redAccent : Colors.amberAccent,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
