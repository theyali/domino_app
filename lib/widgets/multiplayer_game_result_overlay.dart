import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../localization/game_action_strings.dart';
import '../models/multiplayer_game_state.dart';
import '../theme/app_colors.dart';

enum _ResultPresentationPhase {
  waitingForLastDomino,
  outcome,
  menu,
}

class MultiplayerGameResultOverlay extends StatefulWidget {
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
  State<MultiplayerGameResultOverlay> createState() =>
      _MultiplayerGameResultOverlayState();
}

class _MultiplayerGameResultOverlayState
    extends State<MultiplayerGameResultOverlay> {
  static const Duration _lastDominoWait = Duration(milliseconds: 920);
  static const Duration _outcomeDuration = Duration(milliseconds: 820);

  Timer? _phaseTimer;
  late _ResultPresentationPhase _phase;

  MultiplayerGameState get gameState => widget.gameState;

  @override
  void initState() {
    super.initState();
    _startPresentation();
  }

  @override
  void didUpdateWidget(covariant MultiplayerGameResultOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldResult = oldWidget.gameState.roundResult;
    final newResult = widget.gameState.roundResult;
    final resultChanged = oldWidget.gameState.roundNumber !=
            widget.gameState.roundNumber ||
        oldResult?.reason != newResult?.reason ||
        oldWidget.gameState.version != widget.gameState.version;

    if (resultChanged && _phase == _ResultPresentationPhase.menu) {
      _startPresentation();
    }
  }

  @override
  void dispose() {
    _phaseTimer?.cancel();
    super.dispose();
  }

  void _startPresentation() {
    _phaseTimer?.cancel();

    final result = gameState.roundResult;
    if (result == null || result.reason != 'domino') {
      _phase = _ResultPresentationPhase.menu;
      return;
    }

    _phase = _ResultPresentationPhase.waitingForLastDomino;
    _phaseTimer = Timer(_lastDominoWait, _showOutcome);
  }

  void _showOutcome() {
    if (!mounted) return;

    final result = gameState.roundResult;
    if (result == null) {
      setState(() {
        _phase = _ResultPresentationPhase.menu;
      });
      return;
    }

    final isWinner = result.winnerPlayerIds.contains(gameState.myPlayerId);
    if (isWinner) {
      unawaited(HapticFeedback.mediumImpact());
    } else {
      unawaited(HapticFeedback.lightImpact());
    }

    setState(() {
      _phase = _ResultPresentationPhase.outcome;
    });

    _phaseTimer = Timer(_outcomeDuration, () {
      if (!mounted) return;
      setState(() {
        _phase = _ResultPresentationPhase.menu;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = gameState.roundResult;
    if (result == null) {
      return const SizedBox.shrink();
    }

    if (_phase == _ResultPresentationPhase.waitingForLastDomino) {
      return const IgnorePointer(
        child: SizedBox.expand(),
      );
    }

    if (_phase == _ResultPresentationPhase.outcome) {
      final isWinner = result.winnerPlayerIds.contains(gameState.myPlayerId);
      final winner = _firstRoundWinner(result);

      return _RoundOutcomeFlash(
        isWinner: isWinner,
        winnerName: winner?.name,
      );
    }

    return _buildResultMenu(context, result);
  }

  Widget _buildResultMenu(
    BuildContext context,
    MultiplayerRoundResult result,
  ) {
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
                            onPressed: widget.isStartingNextRound ||
                                    widget.isLeaving
                                ? null
                                : widget.onNextRound,
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
                            icon: widget.isStartingNextRound
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
                                widget.isStartingNextRound
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
                        onPressed: widget.isLeaving ? null : widget.onExit,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.28),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        icon: widget.isLeaving
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
                          context.tr(
                            widget.isLeaving ? 'leaving' : 'exit_game',
                          ),
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

  MultiplayerPlayerState? _firstRoundWinner(MultiplayerRoundResult result) {
    if (result.winnerPlayerIds.isEmpty) return null;
    return _playerById(result.winnerPlayerIds.first);
  }

  MultiplayerPlayerState? _playerById(int? playerId) {
    if (playerId == null) return null;
    for (final player in gameState.players) {
      if (player.id == playerId) return player;
    }
    return null;
  }
}

class _RoundOutcomeFlash extends StatelessWidget {
  final bool isWinner;
  final String? winnerName;

  const _RoundOutcomeFlash({
    required this.isWinner,
    required this.winnerName,
  });

  @override
  Widget build(BuildContext context) {
    final isAzerbaijani = context.appLanguage.code == 'az';
    final title = isWinner
        ? (isAzerbaijani ? 'Əla! Raund sənindir!' : 'Отлично! Раунд твой!')
        : (isAzerbaijani ? 'Raund uduzuldu' : 'Раунд проигран');
    final subtitle = isWinner
        ? (isAzerbaijani
            ? 'Son daşı birinci siz qoydunuz.'
            : 'Ты первым выложил последнюю костяшку.')
        : winnerName == null
            ? (isAzerbaijani
                ? 'Rəqib raundu birinci bitirdi.'
                : 'Соперник первым закончил раунд.')
            : (isAzerbaijani
                ? '$winnerName raundu birinci bitirdi.'
                : '$winnerName первым закончил раунд.');
    final accent = isWinner ? AppColors.lime : const Color(0xFFFF655B);
    final icon = isWinner
        ? Icons.emoji_events_rounded
        : Icons.sentiment_dissatisfied_rounded;

    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.68, end: 1),
            duration: const Duration(milliseconds: 430),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (isWinner)
                  const Positioned.fill(
                    child: _OutcomeBurst(),
                  ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 330),
                  margin: const EdgeInsets.symmetric(horizontal: 28),
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.panelTop,
                        AppColors.panelBottom,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.85),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.16),
                        blurRadius: 26,
                        spreadRadius: 2,
                      ),
                      const BoxShadow(
                        color: Colors.black54,
                        blurRadius: 18,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent,
                          border: Border.all(
                            color: AppColors.ink,
                            width: 2.2,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: Colors.black,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OutcomeBurst extends StatelessWidget {
  const _OutcomeBurst();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder: (context, progress, child) {
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            for (var index = 0; index < 12; index++)
              Transform.translate(
                offset: Offset(
                  math.cos((math.pi * 2 / 12) * index) * 116 * progress,
                  math.sin((math.pi * 2 / 12) * index) * 88 * progress,
                ),
                child: Opacity(
                  opacity: (1 - progress * 0.55).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: progress * (index.isEven ? 1.2 : -1.2),
                    child: Icon(
                      index.isEven ? Icons.star_rounded : Icons.circle,
                      size: index.isEven ? 17 : 10,
                      color: index % 3 == 0
                          ? AppColors.brass
                          : AppColors.lime,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
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
          _ResultAvatar(
            player: player,
            highlighted: isRoundWinner,
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

class _ResultAvatar extends StatelessWidget {
  final MultiplayerPlayerState player;
  final bool highlighted;

  const _ResultAvatar({
    required this.player,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = player.avatarUrl;
    final letter = player.name.isEmpty ? '?' : player.name[0].toUpperCase();

    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted ? AppColors.lime : AppColors.cream,
        border: Border.all(
          color: AppColors.ink,
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => _ResultAvatarLetter(
                  letter: letter,
                ),
              )
            : _ResultAvatarLetter(letter: letter),
      ),
    );
  }
}

class _ResultAvatarLetter extends StatelessWidget {
  final String letter;

  const _ResultAvatarLetter({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE7ECF0),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
