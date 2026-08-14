import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../localization/game_action_strings.dart';
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
    final surrendered = result.reason == 'surrender';

    return Material(
      color: Colors.black.withValues(alpha: 0.74),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.panelTop,
                      AppColors.panelBottom,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppColors.brass.withValues(alpha: 0.76),
                    width: 1.8,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black87,
                      blurRadius: 34,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: surrendered
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF31485B),
                                    AppColors.badge,
                                  ],
                                )
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.limeSoft,
                                    AppColors.lime,
                                    AppColors.limeDark,
                                  ],
                                ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: surrendered
                                ? AppColors.brass
                                : AppColors.ink,
                            width: 2.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Icon(
                          surrendered
                              ? Icons.outlined_flag_rounded
                              : isMatchFinished
                                  ? Icons.emoji_events_rounded
                                  : result.reason == 'fish'
                                      ? Icons.water_rounded
                                      : Icons.flag_rounded,
                          color: surrendered ? AppColors.cream : Colors.black,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      reasonTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      reasonSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
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
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: isStartingNextRound || isLeaving
                                ? null
                                : onNextRound,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.lime,
                              foregroundColor: Colors.black,
                              elevation: 7,
                              shadowColor: Colors.black54,
                              side: const BorderSide(
                                color: AppColors.ink,
                                width: 2,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: isStartingNextRound
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
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
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.badge.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.brass.withValues(alpha: 0.28),
                            ),
                          ),
                          child: Text(
                            context.tr('wait_owner_next_round'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                    SizedBox(
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed: isLeaving ? null : onExit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        icon: isLeaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
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
    if (reason == 'surrender') {
      return GameActionStrings.of(context).surrenderResultTitle;
    }
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
    if (result.reason == 'surrender') {
      final surrenderedId = result.matchLoserPlayerIds.isEmpty
          ? null
          : result.matchLoserPlayerIds.first;
      final player = _playerById(surrenderedId);
      final strings = GameActionStrings.of(context);
      return player == null
          ? strings.surrenderResultTitle
          : strings.surrenderedPlayer(player.name);
    }

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

    final borderColor = isMatchLoser
        ? Colors.redAccent.withValues(alpha: 0.72)
        : isRoundWinner
            ? AppColors.lime.withValues(alpha: 0.74)
            : Colors.white.withValues(alpha: 0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.badgeLight.withValues(alpha: 0.82),
            AppColors.badge.withValues(alpha: 0.92),
          ],
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: borderColor,
          width: isRoundWinner || isMatchLoser ? 1.6 : 1,
        ),
        boxShadow: [
          if (isRoundWinner)
            BoxShadow(
              color: AppColors.lime.withValues(alpha: 0.08),
              blurRadius: 12,
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: isRoundWinner
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.limeSoft,
                        AppColors.lime,
                      ],
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFEDF1F5),
                        Color(0xFFAAB5C0),
                      ],
                    ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.ink,
                width: 1.5,
              ),
            ),
            child: Text(
              player.name.isEmpty ? '?' : player.name[0].toUpperCase(),
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w900,
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
                        style: TextStyle(
                          color: isRoundWinner
                              ? AppColors.limeSoft
                              : Colors.white,
                          fontWeight: FontWeight.w900,
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
          Container(
            constraints: const BoxConstraints(minWidth: 42),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isMatchLoser
                  ? Colors.redAccent.withValues(alpha: 0.14)
                  : AppColors.lime.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Text(
              '$total',
              style: TextStyle(
                color: isMatchLoser ? Colors.redAccent : AppColors.lime,
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
