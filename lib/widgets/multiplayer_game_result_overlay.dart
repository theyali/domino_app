import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../localization/game_action_strings.dart';
import '../models/multiplayer_game_state.dart';

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
    if (oldWidget.gameState.roundNumber != widget.gameState.roundNumber ||
        oldResult?.reason != newResult?.reason) {
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
      return const IgnorePointer(child: SizedBox.expand());
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
    final surrendered = result.reason == 'surrender';
    final playerLeft = result.reason == 'player_left';
    final isMyMatchWin = isMatchFinished &&
        result.matchWinnerPlayerIds.contains(gameState.myPlayerId);
    final isMyMatchLoss = isMatchFinished &&
        result.matchLoserPlayerIds.contains(gameState.myPlayerId);

    final reasonTitle = _reasonTitle(context, result.reason, isMatchFinished);
    final reasonSubtitle = _reasonSubtitle(context, result);

    final accent = surrendered || playerLeft || isMyMatchLoss
        ? _ResultPalette.coral
        : isMyMatchWin
            ? _ResultPalette.lime
            : _ResultPalette.yellow;

    final icon = surrendered
        ? Icons.outlined_flag_rounded
        : playerLeft
            ? Icons.logout_rounded
            : isMatchFinished
                ? Icons.emoji_events_rounded
                : result.reason == 'fish'
                    ? Icons.water_rounded
                    : Icons.flag_rounded;

    return Material(
      color: Colors.black.withValues(alpha: 0.62),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 26),
                    padding: const EdgeInsets.fromLTRB(18, 52, 18, 18),
                    decoration: BoxDecoration(
                      color: _ResultPalette.cream,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: _ResultPalette.ink,
                        width: 3,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: _ResultPalette.ink,
                          blurRadius: 0,
                          offset: Offset(6, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          reasonTitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _ResultPalette.ink,
                            fontSize: 28,
                            height: 1.05,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          reasonSubtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _ResultPalette.inkSoft,
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (gameState.isPhone) ...[
                          const SizedBox(height: 10),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: _ResultPalette.skyBlue,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _ResultPalette.ink,
                                  width: 2.2,
                                ),
                              ),
                              child: Text(
                                context.appLanguage.code == 'az'
                                    ? 'Telefon · hədəf ${gameState.targetScore}'
                                    : 'Телефон · цель ${gameState.targetScore}',
                                style: const TextStyle(
                                  color: _ResultPalette.ink,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        for (final player in gameState.players)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PlayerResultRow(
                              player: player,
                              result: result,
                              isPhone: gameState.isPhone,
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (gameState.isRoundFinished) ...[
                          if (gameState.myPlayer.isOwner)
                            _CartoonActionButton(
                              backgroundColor: _ResultPalette.lime,
                              foregroundColor: _ResultPalette.ink,
                              onPressed: widget.isStartingNextRound ||
                                      widget.isLeaving
                                  ? null
                                  : widget.onNextRound,
                              icon: widget.isStartingNextRound
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.6,
                                        color: _ResultPalette.ink,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded, size: 24),
                              label: context.tr(
                                widget.isStartingNextRound
                                    ? 'next_round_loading'
                                    : 'next_round',
                              ),
                            )
                          else
                            _WaitingOwnerCard(
                              text: context.tr('wait_owner_next_round'),
                            ),
                          const SizedBox(height: 12),
                        ],
                        _CartoonActionButton(
                          backgroundColor: _ResultPalette.skyBlue,
                          foregroundColor: _ResultPalette.ink,
                          onPressed: widget.isLeaving ? null : widget.onExit,
                          icon: widget.isLeaving
                              ? const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: _ResultPalette.ink,
                                  ),
                                )
                              : const Icon(Icons.logout_rounded, size: 23),
                          label: context.tr(
                            widget.isLeaving ? 'leaving' : 'exit_game',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Transform.rotate(
                        angle: surrendered || playerLeft ? -0.06 : 0.05,
                        child: Container(
                          width: 82,
                          height: 82,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _ResultPalette.ink,
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: _ResultPalette.ink,
                                blurRadius: 0,
                                offset: Offset(4, 5),
                              ),
                            ],
                          ),
                          child: Icon(
                            icon,
                            color: _ResultPalette.ink,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
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
    if (isMatchFinished && gameState.isPhone) {
      return context.appLanguage.code == 'az'
          ? 'Telefon oyunu bitdi'
          : '«Телефон» завершён';
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

    if (gameState.isMatchFinished && gameState.isPhone) {
      final winnerNames = result.matchWinnerPlayerIds
          .map(_playerById)
          .whereType<MultiplayerPlayerState>()
          .map((player) => player.name)
          .join(', ');
      if (winnerNames.isEmpty) {
        return context.appLanguage.code == 'az'
            ? 'Hədəf xalına çatıldı.'
            : 'Достигнуто целевое количество очков.';
      }
      return context.appLanguage.code == 'az'
          ? '$winnerNames ${gameState.targetScore} xal hədəfinə çatdı.'
          : '$winnerNames достиг цели ${gameState.targetScore} очков.';
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

    final accent = isWinner ? _ResultPalette.lime : _ResultPalette.coral;
    final secondaryAccent =
        isWinner ? _ResultPalette.yellow : _ResultPalette.skyBlue;

    return Material(
      color: Colors.black.withValues(alpha: 0.42),
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.72, end: 1.0),
            duration: const Duration(milliseconds: 430),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              final safeOpacity = value > 1.0 ? 1.0 : value;
              return Transform.scale(
                scale: value,
                child: Opacity(opacity: safeOpacity, child: child),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                if (isWinner)
                  const Positioned.fill(child: _OutcomeBurst()),
                Container(
                  constraints: const BoxConstraints(maxWidth: 350),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.fromLTRB(22, 58, 22, 24),
                  decoration: BoxDecoration(
                    color: _ResultPalette.cream,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _ResultPalette.ink,
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: _ResultPalette.ink,
                        blurRadius: 0,
                        offset: Offset(6, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _ResultPalette.ink,
                          fontSize: 27,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: secondaryAccent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _ResultPalette.ink,
                            width: 2.2,
                          ),
                        ),
                        child: Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _ResultPalette.ink,
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: -36,
                  child: Transform.rotate(
                    angle: isWinner ? 0.06 : -0.06,
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        color: accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _ResultPalette.ink,
                          width: 3,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: _ResultPalette.ink,
                            blurRadius: 0,
                            offset: Offset(4, 5),
                          ),
                        ],
                      ),
                      child: Icon(
                        isWinner
                            ? Icons.emoji_events_rounded
                            : Icons.sentiment_dissatisfied_rounded,
                        color: _ResultPalette.ink,
                        size: 43,
                      ),
                    ),
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
      tween: Tween(begin: 0.0, end: 1.0),
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
                  math.cos((math.pi * 2 / 12) * index) * 118 * progress,
                  math.sin((math.pi * 2 / 12) * index) * 94 * progress,
                ),
                child: Opacity(
                  opacity: 1.0 - progress * 0.5,
                  child: Transform.rotate(
                    angle: progress * (index.isEven ? 1.2 : -1.2),
                    child: Icon(
                      index.isEven ? Icons.star_rounded : Icons.circle,
                      size: index.isEven ? 20 : 11,
                      color: index % 3 == 0
                          ? _ResultPalette.yellow
                          : _ResultPalette.lime,
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
  final bool isPhone;

  const _PlayerResultRow({
    required this.player,
    required this.result,
    required this.isPhone,
  });

  @override
  Widget build(BuildContext context) {
    final handPoints = result.handPoints[player.id] ?? 0;
    final added = isPhone
        ? (result.addedPoints[player.id] ?? 0)
        : (result.addedPenalties[player.id] ?? 0);
    final total = result.totalScores[player.id] ?? player.score;
    final isRoundWinner = result.winnerPlayerIds.contains(player.id);
    final isMatchLoser = result.matchLoserPlayerIds.contains(player.id);

    final background = isMatchLoser
        ? _ResultPalette.coralSoft
        : isRoundWinner
            ? _ResultPalette.mint
            : Colors.white;

    final scoreColor = isMatchLoser
        ? _ResultPalette.coral
        : isRoundWinner
            ? _ResultPalette.lime
            : _ResultPalette.yellow;

    final detailText = isPhone
        ? (context.appLanguage.code == 'az'
            ? 'Əldə: $handPoints · Qazanıldı: +$added'
            : 'На руках: $handPoints · Получено: +$added')
        : context.tr(
            'hand_points_penalty',
            arguments: {
              'hand': handPoints,
              'penalty': added,
            },
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: _ResultPalette.ink,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: _ResultPalette.ink,
            blurRadius: 0,
            offset: Offset(3, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _ResultAvatar(
            player: player,
            highlighted: isRoundWinner,
          ),
          const SizedBox(width: 11),
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
                          color: _ResultPalette.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (!player.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _ResultPalette.ink,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          context.tr('left_game'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  detailText,
                  style: const TextStyle(
                    color: _ResultPalette.inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 46, minHeight: 42),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scoreColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _ResultPalette.ink,
                width: 2.2,
              ),
            ),
            child: Text(
              '$total',
              style: const TextStyle(
                color: _ResultPalette.ink,
                fontSize: 20,
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
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlighted ? _ResultPalette.lime : _ResultPalette.cream,
        border: Border.all(
          color: _ResultPalette.ink,
          width: 2.3,
        ),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) =>
                    _ResultAvatarLetter(letter: letter),
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
      color: const Color(0xFFF4F7F8),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: _ResultPalette.ink,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _WaitingOwnerCard extends StatelessWidget {
  final String text;

  const _WaitingOwnerCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _ResultPalette.yellow,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: _ResultPalette.ink,
          width: 2.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: _ResultPalette.ink,
            blurRadius: 0,
            offset: Offset(3, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.hourglass_bottom_rounded,
            color: _ResultPalette.ink,
            size: 21,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _ResultPalette.ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartoonActionButton extends StatelessWidget {
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;
  final Widget icon;
  final String label;

  const _CartoonActionButton({
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Opacity(
      opacity: enabled ? 1 : 0.52,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _ResultPalette.ink,
            width: 2.8,
          ),
          boxShadow: const [
            BoxShadow(
              color: _ResultPalette.ink,
              blurRadius: 0,
              offset: Offset(4, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(15),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconTheme(
                    data: IconThemeData(color: foregroundColor),
                    child: icon,
                  ),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _ResultPalette {
  static const cream = Color(0xFFFFF4D7);
  static const ink = Color(0xFF18212A);
  static const inkSoft = Color(0xFF5D6470);

  static const lime = Color(0xFF76F400);
  static const yellow = Color(0xFFFFCF4A);
  static const skyBlue = Color(0xFF79C9F2);
  static const mint = Color(0xFFB9EEA0);
  static const coral = Color(0xFFFF6B61);
  static const coralSoft = Color(0xFFFFD0CA);
}
