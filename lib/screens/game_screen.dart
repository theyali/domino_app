import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/domino_game.dart';
import '../models/domino.dart';
import '../models/player.dart';
import '../models/restaurant.dart';
import '../widgets/domino_boneyard_draw_animation.dart';
import '../widgets/domino_boneyard_pile.dart';
import '../widgets/domino_placement_target.dart';
import '../widgets/domino_play_animation.dart';
import '../widgets/domino_tile.dart';
import '../widgets/game_settings_bottom_sheet.dart';
import '../widgets/gift_bottom_sheet.dart';
import '../widgets/player_avatar.dart';

enum _ChainDirection { right, left, up, down }

enum _RoundDialogAction { nextRound, newMatch }

class _ChainPlacement {
  final int tableIndex;
  final Domino domino;
  final Offset center;
  final _ChainDirection direction;

  const _ChainPlacement({
    required this.tableIndex,
    required this.domino,
    required this.center,
    required this.direction,
  });

  bool get pathIsHorizontal =>
      direction == _ChainDirection.right ||
      direction == _ChainDirection.left;

  bool get isDouble =>
      domino.left == domino.right;

  bool get displayHorizontal {
    if (
      direction == _ChainDirection.up ||
      direction == _ChainDirection.down
    ) {
      return false;
    }

    if (isDouble) {
      return false;
    }

    return true;
  }

  Domino get displayDomino {
    if (
      direction == _ChainDirection.left ||
      direction == _ChainDirection.up
    ) {
      return Domino(
        left: domino.right,
        right: domino.left,
      );
    }

    return domino;
  }
}

class _TrackStepGeometry {
  final Offset center;

  // Центр открытого квадрата после этой костяшки.
  // Именно от него строится следующая костяшка.
  final Offset nextConnection;

  final bool horizontal;

  const _TrackStepGeometry({
    required this.center,
    required this.nextConnection,
    required this.horizontal,
  });
}

class _FixedTrackLayout {
  final List<_ChainPlacement> placements;

  final Offset leftEnd;
  final Offset rightEnd;

  final _ChainDirection leftTargetDirection;

  final _ChainDirection leftPreviousDirection;
  final _ChainDirection rightPreviousDirection;

  final _ChainDirection rightRowDirection;
  final bool rightNeedsTurn;
  final int rightRowUsedSquares;

  final double dominoShortSide;
  final double width;
  final double height;

  const _FixedTrackLayout({
    required this.placements,
    required this.leftEnd,
    required this.rightEnd,
    required this.leftTargetDirection,
    required this.leftPreviousDirection,
    required this.rightPreviousDirection,
    required this.rightRowDirection,
    required this.rightNeedsTurn,
    required this.rightRowUsedSquares,
    required this.dominoShortSide,
    required this.width,
    required this.height,
  });
}

class _TrackLayoutDraft {
  final List<_ChainPlacement> placements;
  final Offset leftEnd;
  final Offset rightEnd;
  final _ChainDirection previousDirection;
  final _ChainDirection rowDirection;
  final bool needsTurn;
  final int rowUsedSquares;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _TrackLayoutDraft({
    required this.placements,
    required this.leftEnd,
    required this.rightEnd,
    required this.previousDirection,
    required this.rowDirection,
    required this.needsTurn,
    required this.rowUsedSquares,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  double get contentWidth => maxX - minX;
  double get contentHeight => maxY - minY;
}

class _BoneyardDrawFlight {
  final int id;
  final Domino domino;
  final Offset sourceGlobalCenter;
  final Offset targetGlobalCenter;

  const _BoneyardDrawFlight({
    required this.id,
    required this.domino,
    required this.sourceGlobalCenter,
    required this.targetGlobalCenter,
  });
}

class GameScreen extends StatefulWidget {
  final Restaurant restaurant;

  const GameScreen({
    super.key,
    required this.restaurant,
  });

  @override
  State<GameScreen> createState() =>
      _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  static const double _trackGap = 0;

  // Фиксированная трасса:
  // один горизонтальный ряд = максимум 11 квадратов.
  //
  // Обычная костяшка = 2 квадрата.
  // Дубль = 1 квадрат по направлению цепочки.
  static const int _horizontalTrackSquares = 11;

  static const double _tableSafeMargin = 18.0;
  static const double _boneyardSafeBottomMargin = 92.0;

  double _preferredTableDominoShortSideForBoard(Size boardSize) {
    final count = tableDominoes.length;

    final preferredByCount =
        count <= 7
            ? 32.0
            : count <= 13
                ? 30.0
                : count <= 19
                    ? 29.0
                    : count <= 24
                        ? 28.0
                        : 27.0;

    final availableWidth = math.max(
      1.0,
      boardSize.width - (_tableSafeMargin * 2),
    );

    // Одна горизонталь = максимум 11 квадратов.
    // Длинная сторона теперь ровно 2 * shortSide, поэтому
    // физическая ширина полностью совпадает с бюджетом квадратов.
    final maxByWidth =
        availableWidth / _horizontalTrackSquares;

    return math.max(
      1.0,
      math.min(preferredByCount, maxByWidth),
    );
  }

  double get _tableDominoShortSide {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // game area: внешние margin 8+8, внутренний padding 10+10.
    final estimatedBoardWidth = math.max(
      1.0,
      screenWidth - 36.0,
    );

    return _preferredTableDominoShortSideForBoard(
      Size(estimatedBoardWidth, double.infinity),
    );
  }

  double _tableDominoLongSideFor(double shortSide) {
    // 2 квадрата должны занимать ровно 2 * shortSide.
    // Разделительная линия рисуется внутри DominoTile и не должна
    // добавлять ещё +2px к геометрии змейки.
    return shortSide * 2;
  }

  double get _tableDominoLongSide {
    return _tableDominoLongSideFor(_tableDominoShortSide);
  }

  double _tableDominoDotSizeFor(double side) {
    if (side >= 32) {
      return 5.0;
    }

    if (side >= 30) {
      return 4.8;
    }

    if (side >= 29) {
      return 4.7;
    }

    if (side >= 28) {
      return 4.6;
    }

    if (side >= 24) {
      return 4.4;
    }

    return math.max(2.8, side * 0.16);
  }

  double get _tableDominoDotSize {
    return _tableDominoDotSizeFor(_tableDominoShortSide);
  }

  static const int _turnDurationSeconds = 20;

  static const int _meIndex = 3;

  int? selectedDominoIndex;

  late final DominoGame _game;

  Timer? _turnTimer;
  Timer? _computerTurnTimer;

  int _turnSecondsLeft =
      _turnDurationSeconds;

  late List<GlobalKey>
      _handDominoKeys;

  final GlobalKey _boneyardKey =
      GlobalKey();

  final GlobalKey _handAreaKey =
      GlobalKey();

  late final List<GlobalKey>
      _playerAvatarKeys;

  late final AnimationController
      _tableImpactController;

  int _playAnimationId = 0;
  int? _animatedTableIndex;
  Offset? _animationSourceGlobalCenter;

  int _boneyardDrawAnimationId = 0;
  _BoneyardDrawFlight? _boneyardDrawFlight;
  int? _hiddenDrawnHandIndex;
  int? _pendingSelectedDrawIndex;
  bool _pendingSkipAfterBoneyardDraw = false;

  bool _soundEnabled = true;
  bool _roundDialogOpen = false;

  List<Player> get players =>
      _game.players;

  List<Domino> get playerHand =>
      _game.handFor(_meIndex);

  List<Domino> get tableDominoes =>
      _game.tableDominoes;

  int get _currentPlayerIndex =>
      _game.currentPlayerIndex;

  int? get _leftOpenValue =>
      _game.leftOpenValue;

  int? get _rightOpenValue =>
      _game.rightOpenValue;

  @override
  void initState() {
    super.initState();

    _game = DominoGame(
      players: const [
        Player(
          id: 1,
          name: 'Alex',
        ),
        Player(
          id: 2,
          name: 'John',
        ),
        Player(
          id: 3,
          name: 'Annie',
        ),
        Player(
          id: 4,
          name: 'Ali',
          isMe: true,
        ),
      ],
      rules: const Domino101Rules(
        handSize: 5,
        losingScore: 101,
        minimumPenaltyToRecord: 13,
        doubleBlankPenaltyWhenAlone: 25,
      ),
      turnOrder: const [
        3, // Ali — снизу
        1, // John — слева
        0, // Alex — сверху
        2, // Annie — справа
      ],
    );

    _syncHandDominoKeys();

    _playerAvatarKeys =
        List<GlobalKey>.generate(
      _game.playerCount,
      (_) => GlobalKey(),
    );

    _tableImpactController =
        AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 120,
      ),
    );

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _beginCurrentTurn();
    });
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    _computerTurnTimer?.cancel();
    _tableImpactController.dispose();

    super.dispose();
  }

  bool get _isMyTurn =>
      _currentPlayerIndex == _meIndex;

  double get _turnProgress =>
      _turnSecondsLeft /
      _turnDurationSeconds;

  void _syncHandDominoKeys() {
    _handDominoKeys =
        List<GlobalKey>.generate(
      _game.handCountFor(_meIndex),
      (_) => GlobalKey(),
    );
  }

  void _beginCurrentTurn() {
    if (
      !mounted ||
      _game.isRoundOver
    ) {
      return;
    }

    _turnTimer?.cancel();
    _computerTurnTimer?.cancel();

    setState(() {
      _turnSecondsLeft =
          _turnDurationSeconds;

      selectedDominoIndex = null;
    });

    _startTurnTimer();

    final currentPlayer =
        _game.currentPlayerIndex;

    if (
      !_game.hasLegalMove(
        currentPlayer,
      )
    ) {
      if (_game.hasBoneyard) {
        if (!_isMyTurn) {
          _computerTurnTimer = Timer(
            const Duration(
              milliseconds: 700,
            ),
            () {
              if (
                !mounted ||
                _game.isRoundOver ||
                _game.currentPlayerIndex !=
                    currentPlayer
              ) {
                return;
              }

              _performAutomaticBazaarTurn();
            },
          );
        }

        return;
      }

      _computerTurnTimer = Timer(
        const Duration(
          milliseconds: 650,
        ),
        () {
          if (
            !mounted ||
            _game.isRoundOver ||
            _game.currentPlayerIndex !=
                currentPlayer
          ) {
            return;
          }

          _skipCurrentPlayer();
        },
      );

      return;
    }

    if (!_isMyTurn) {
      _computerTurnTimer = Timer(
        const Duration(
          milliseconds: 950,
        ),
        () {
          if (
            !mounted ||
            _game.isRoundOver ||
            _game.currentPlayerIndex !=
                currentPlayer
          ) {
            return;
          }

          _performAutomaticTurn();
        },
      );
    }
  }

  void _startTurnTimer() {
    _turnTimer?.cancel();

    if (_game.isRoundOver) {
      return;
    }

    _turnTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (
          !mounted ||
          _game.isRoundOver
        ) {
          return;
        }

        if (_turnSecondsLeft > 1) {
          setState(() {
            _turnSecondsLeft--;
          });

          return;
        }

        _handleTurnTimeout();
      },
    );
  }

  void _handleTurnTimeout() {
    _turnTimer?.cancel();

    final currentPlayer =
        _game.currentPlayerIndex;

    if (
      !_game.hasLegalMove(
        currentPlayer,
      )
    ) {
      if (_game.hasBoneyard) {
        _performAutomaticBazaarTurn();
      } else {
        _skipCurrentPlayer();
      }

      return;
    }

    _performAutomaticTurn();
  }

  Offset? _globalCenterOf(GlobalKey key) {
    final context = key.currentContext;

    if (context == null) {
      return null;
    }

    final renderObject =
        context.findRenderObject();

    if (
      renderObject is! RenderBox ||
      !renderObject.hasSize
    ) {
      return null;
    }

    return renderObject.localToGlobal(
      renderObject.size.center(
        Offset.zero,
      ),
    );
  }

  void _drawFromBoneyardForMe() {
    if (
      !_isMyTurn ||
      _boneyardDrawFlight != null ||
      _hiddenDrawnHandIndex != null ||
      !_game.canDrawFromBoneyard(
        _meIndex,
      )
    ) {
      return;
    }

    final sourceGlobalCenter =
        _globalCenterOf(
      _boneyardKey,
    );

    final result =
        _game.drawFromBoneyard(
      _meIndex,
    );

    if (result == null) {
      return;
    }

    setState(() {
      _handDominoKeys.add(
        GlobalKey(),
      );

      _hiddenDrawnHandIndex =
          result.handIndex;

      _pendingSelectedDrawIndex =
          result.hasLegalMove
              ? result.handIndex
              : null;

      _pendingSkipAfterBoneyardDraw =
          !result.hasLegalMove &&
          result.boneyardRemaining == 0;

      selectedDominoIndex = null;
    });

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final handDominoTarget =
          result.handIndex <
                  _handDominoKeys.length
              ? _globalCenterOf(
                  _handDominoKeys[
                    result.handIndex
                  ],
                )
              : null;

      final targetGlobalCenter =
          handDominoTarget ??
          _globalCenterOf(
            _handAreaKey,
          );

      if (
        sourceGlobalCenter == null ||
        targetGlobalCenter == null
      ) {
        _finishBoneyardDrawAnimation();
        return;
      }

      setState(() {
        _boneyardDrawAnimationId++;

        _boneyardDrawFlight =
            _BoneyardDrawFlight(
          id:
              _boneyardDrawAnimationId,
          domino:
              result.domino,
          sourceGlobalCenter:
              sourceGlobalCenter,
          targetGlobalCenter:
              targetGlobalCenter,
        );
      });
    });
  }

  void _finishBoneyardDrawAnimation() {
    if (!mounted) {
      return;
    }

    final shouldSkip =
        _pendingSkipAfterBoneyardDraw;

    setState(() {
      _boneyardDrawFlight = null;
      _hiddenDrawnHandIndex = null;

      selectedDominoIndex =
          _pendingSelectedDrawIndex;

      _pendingSelectedDrawIndex =
          null;

      _pendingSkipAfterBoneyardDraw =
          false;
    });

    if (!shouldSkip) {
      return;
    }

    _computerTurnTimer?.cancel();

    _computerTurnTimer = Timer(
      const Duration(
        milliseconds: 300,
      ),
      () {
        if (
          mounted &&
          _isMyTurn &&
          !_game.hasLegalMove(
            _meIndex,
          )
        ) {
          _skipCurrentPlayer();
        }
      },
    );
  }

  void _performAutomaticBazaarTurn() {
    final playerIndex =
        _game.currentPlayerIndex;

    final results =
        _game.drawUntilPlayable(
      playerIndex,
    );

    if (results.isEmpty) {
      if (
        !_game.hasLegalMove(
          playerIndex,
        ) &&
        !_game.hasBoneyard
      ) {
        _skipCurrentPlayer();
      }

      return;
    }

    setState(() {
      if (playerIndex == _meIndex) {
        for (final _ in results) {
          _handDominoKeys.add(
            GlobalKey(),
          );
        }

        final lastResult =
            results.last;

        selectedDominoIndex =
            lastResult.hasLegalMove
                ? lastResult.handIndex
                : null;
      }

      _turnSecondsLeft =
          _turnDurationSeconds;
    });

    _computerTurnTimer?.cancel();

    _computerTurnTimer = Timer(
      const Duration(
        milliseconds: 420,
      ),
      () {
        if (
          !mounted ||
          _game.isRoundOver ||
          _game.currentPlayerIndex !=
              playerIndex
        ) {
          return;
        }

        if (
          _game.hasLegalMove(
            playerIndex,
          )
        ) {
          _performAutomaticTurn();
        } else {
          _skipCurrentPlayer();
        }
      },
    );
  }

  void _skipCurrentPlayer() {
    final playerIndex =
        _game.currentPlayerIndex;

    final playerName =
        players[playerIndex].name;

    final result =
        _game.skipTurn(
      playerIndex,
    );

    if (result == null) {
      return;
    }

    setState(() {
      selectedDominoIndex = null;
      _turnSecondsLeft =
          _turnDurationSeconds;
    });

    if (
      mounted &&
      playerIndex == _meIndex
    ) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          duration: const Duration(
            milliseconds: 900,
          ),
          content: Text(
            '$playerName: базар пуст, подходящего хода нет — пропуск',
          ),
        ),
      );
    }

    _afterGameAction(
      roundEnded: result.roundEnded,
    );
  }

  void _performAutomaticTurn() {
    final playerIndex =
        _game.currentPlayerIndex;

    if (
      !_game.hasLegalMove(
        playerIndex,
      )
    ) {
      if (_game.hasBoneyard) {
        _performAutomaticBazaarTurn();
      } else {
        _skipCurrentPlayer();
      }

      return;
    }

    Offset sourceGlobalCenter;

    if (playerIndex == _meIndex) {
      final selectedIndex =
          selectedDominoIndex;

      if (
        selectedIndex != null &&
        selectedIndex >= 0 &&
        selectedIndex <
            playerHand.length &&
        _game.canPlayHandIndex(
          playerIndex: _meIndex,
          handIndex: selectedIndex,
        )
      ) {
        sourceGlobalCenter =
            _getHandDominoGlobalCenter(
              selectedIndex,
            ) ??
            _fallbackAnimationSource();
      } else {
        sourceGlobalCenter =
            _fallbackAnimationSource();
      }
    } else {
      sourceGlobalCenter =
          _getPlayerAvatarGlobalCenter(
            playerIndex,
          ) ??
          _fallbackOpponentSource(
            playerIndex,
          );
    }

    final result =
        _game.playAutomaticTurn(
      playerIndex,
    );

    if (result == null) {
      _skipCurrentPlayer();
      return;
    }

    setState(() {
      if (
        playerIndex == _meIndex &&
        result.handIndex >= 0 &&
        result.handIndex <
            _handDominoKeys.length
      ) {
        _handDominoKeys.removeAt(
          result.handIndex,
        );
      }

      _playAnimationId++;
      _animatedTableIndex =
          result.tableIndex;

      _animationSourceGlobalCenter =
          sourceGlobalCenter;

      selectedDominoIndex = null;
      _turnSecondsLeft =
          _turnDurationSeconds;
    });

    _afterGameAction(
      roundEnded: result.roundEnded,
    );
  }

  void _afterGameAction({
    required bool roundEnded,
  }) {
    _turnTimer?.cancel();
    _computerTurnTimer?.cancel();

    if (roundEnded) {
      Future<void>.delayed(
        const Duration(
          milliseconds: 950,
        ),
        () {
          if (mounted) {
            _showRoundResultDialog();
          }
        },
      );

      return;
    }

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _beginCurrentTurn();
    });
  }

  Future<void>
      _showRoundResultDialog() async {
    if (
      !mounted ||
      _roundDialogOpen ||
      !_game.isRoundOver
    ) {
      return;
    }

    final result =
        _game.lastRoundResult;

    if (result == null) {
      return;
    }

    _roundDialogOpen = true;

    final currentPlayers =
        players;

    final winnerNames =
        result.winnerIndices
            .map(
              (index) =>
                  currentPlayers[index]
                      .name,
            )
            .join(', ');

    final isFish =
        result.reason ==
        DominoRoundEndReason.fish;

    final isMatchOver =
        _game.isMatchOver;

    final action =
        await showDialog<
            _RoundDialogAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              const Color(0xFF111827),
          title: Text(
            isMatchOver
                ? 'Матч завершён'
                : isFish
                    ? 'Рыба'
                    : 'Раунд завершён',
            style: const TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  isFish
                      ? 'Минимум очков на руках: $winnerNames'
                      : 'Раунд выиграл: $winnerNames',
                  style:
                      const TextStyle(
                    color:
                        Colors.white70,
                  ),
                ),
                const SizedBox(
                  height: 14,
                ),
                for (
                  var index = 0;
                  index <
                      currentPlayers
                          .length;
                  index++
                )
                  Padding(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            currentPlayers[
                                    index]
                                .name,
                            style:
                                const TextStyle(
                              color:
                                  Colors
                                      .white,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ),
                        Text(
                          '${result.handPoints[index]} → '
                          '+${result.addedPenalties[index]} → '
                          '${result.totalScores[index]}',
                          style:
                              const TextStyle(
                            color:
                                Colors
                                    .white70,
                            fontSize:
                                13,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (isMatchOver) ...[
                  const SizedBox(
                    height: 14,
                  ),
                  Text(
                    '101+ набрал: ${result.matchLoserIndices.map(
                      (index) => currentPlayers[index].name,
                    ).join(', ')}',
                    style:
                        const TextStyle(
                      color:
                          Colors.redAccent,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  isMatchOver
                      ? _RoundDialogAction
                          .newMatch
                      : _RoundDialogAction
                          .nextRound,
                );
              },
              child: Text(
                isMatchOver
                    ? 'Новая игра'
                    : 'Следующий раунд',
              ),
            ),
          ],
        );
      },
    );

    _roundDialogOpen = false;

    if (
      !mounted ||
      action == null
    ) {
      return;
    }

    setState(() {
      if (
        action ==
        _RoundDialogAction.newMatch
      ) {
        _game.resetMatch();
      } else {
        _game.startNextRound();
      }

      _syncHandDominoKeys();

      selectedDominoIndex = null;
      _animatedTableIndex = null;
      _animationSourceGlobalCenter =
          null;

      _boneyardDrawFlight = null;
      _hiddenDrawnHandIndex = null;
      _pendingSelectedDrawIndex =
          null;
      _pendingSkipAfterBoneyardDraw =
          false;

      _turnSecondsLeft =
          _turnDurationSeconds;
    });

    WidgetsBinding.instance
        .addPostFrameCallback((_) {
      _beginCurrentTurn();
    });
  }

  void _openGiftMenu(
    Player clickedPlayer,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return GiftBottomSheet(
          players: players,
          initiallySelectedPlayer:
              clickedPlayer,
        );
      },
    );
  }

  void _openSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor:
          Colors.transparent,
      builder: (context) {
        return GameSettingsBottomSheet(
          soundEnabled:
              _soundEnabled,
          onSoundChanged: (value) {
            setState(() {
              _soundEnabled = value;
            });
          },
        );
      },
    );
  }

  void _triggerDoubleTableImpact() {
    _tableImpactController.forward(
      from: 0,
    );
  }

  bool _canPlayOnLeft(
    Domino domino,
  ) {
    return _game.canDominoPlayOnSide(
      playerIndex: _meIndex,
      domino: domino,
      side: DominoSide.left,
    );
  }

  bool _canPlayOnRight(
    Domino domino,
  ) {
    return _game.canDominoPlayOnSide(
      playerIndex: _meIndex,
      domino: domino,
      side: DominoSide.right,
    );
  }

  bool _canPlayDomino(
    Domino domino,
  ) {
    return _game.canPlayDomino(
      playerIndex: _meIndex,
      domino: domino,
    );
  }

  void _selectDomino(int index) {
    if (
      !_isMyTurn ||
      !_game.canPlayHandIndex(
        playerIndex: _meIndex,
        handIndex: index,
      )
    ) {
      return;
    }

    setState(() {
      if (
        selectedDominoIndex ==
        index
      ) {
        selectedDominoIndex = null;
      } else {
        selectedDominoIndex = index;
      }
    });
  }

  Offset? _getHandDominoGlobalCenter(
    int index,
  ) {
    if (
      index < 0 ||
      index >=
          _handDominoKeys.length
    ) {
      return null;
    }

    final currentContext =
        _handDominoKeys[index]
            .currentContext;

    final renderObject =
        currentContext
            ?.findRenderObject();

    if (
      renderObject is! RenderBox ||
      !renderObject.hasSize
    ) {
      return null;
    }

    return renderObject.localToGlobal(
      renderObject.size.center(
        Offset.zero,
      ),
    );
  }

  Offset?
      _getPlayerAvatarGlobalCenter(
    int playerIndex,
  ) {
    if (
      playerIndex < 0 ||
      playerIndex >=
          _playerAvatarKeys.length
    ) {
      return null;
    }

    final currentContext =
        _playerAvatarKeys[playerIndex]
            .currentContext;

    final renderObject =
        currentContext
            ?.findRenderObject();

    if (
      renderObject is! RenderBox ||
      !renderObject.hasSize
    ) {
      return null;
    }

    return renderObject.localToGlobal(
      renderObject.size.center(
        Offset.zero,
      ),
    );
  }

  Offset _fallbackAnimationSource() {
    final screenSize =
        MediaQuery.sizeOf(context);

    return Offset(
      screenSize.width / 2,
      screenSize.height - 90,
    );
  }

  Offset _fallbackOpponentSource(
    int playerIndex,
  ) {
    final screenSize =
        MediaQuery.sizeOf(context);

    return switch (playerIndex) {
      0 => Offset(
          screenSize.width / 2,
          150,
        ),
      1 => Offset(
          70,
          screenSize.height *
              0.34,
        ),
      2 => Offset(
          screenSize.width - 70,
          screenSize.height *
              0.34,
        ),
      _ => _fallbackAnimationSource(),
    };
  }

  void _playSelectedDomino(
    DominoSide preferredSide,
  ) {
    if (!_isMyTurn) {
      return;
    }

    final index =
        selectedDominoIndex;

    if (index == null) {
      return;
    }

    final sourceGlobalCenter =
        _getHandDominoGlobalCenter(
          index,
        ) ??
        _fallbackAnimationSource();

    final result =
        _game.playDomino(
      playerIndex: _meIndex,
      handIndex: index,
      preferredSide:
          preferredSide,
    );

    if (result == null) {
      return;
    }

    setState(() {
      if (
        index >= 0 &&
        index <
            _handDominoKeys.length
      ) {
        _handDominoKeys.removeAt(
          index,
        );
      }

      _playAnimationId++;
      _animatedTableIndex =
          result.tableIndex;

      _animationSourceGlobalCenter =
          sourceGlobalCenter;

      selectedDominoIndex = null;
      _turnSecondsLeft =
          _turnDurationSeconds;
    });

    _afterGameAction(
      roundEnded:
          result.roundEnded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPlayer = players[0];
    final leftPlayer = players[1];
    final rightPlayer = players[2];
    final me = players[3];

    return Scaffold(
      backgroundColor:
          const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.restaurant.name,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Настройки',
            onPressed: _openSettings,
            icon: const Icon(
              Icons.settings_rounded,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Expanded(
                  child: _buildGameArea(
                    topPlayer: topPlayer,
                    leftPlayer: leftPlayer,
                    rightPlayer:
                        rightPlayer,
                  ),
                ),
                _buildMyPanel(me),
              ],
            ),

            if (_boneyardDrawFlight != null)
              Positioned.fill(
                child: IgnorePointer(
                  child:
                      DominoBoneyardDrawAnimation(
                    key: ValueKey(
                      'boneyard-draw-${_boneyardDrawFlight!.id}',
                    ),
                    domino:
                        _boneyardDrawFlight!.domino,
                    sourceGlobalCenter:
                        _boneyardDrawFlight!
                            .sourceGlobalCenter,
                    targetGlobalCenter:
                        _boneyardDrawFlight!
                            .targetGlobalCenter,
                    soundEnabled:
                        _soundEnabled,
                    onCompleted:
                        _finishBoneyardDrawAnimation,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameArea({
    required Player topPlayer,
    required Player leftPlayer,
    required Player rightPlayer,
  }) {
    return AnimatedBuilder(
      animation:
          _tableImpactController,
      builder: (
        context,
        child,
      ) {
        final progress =
            _tableImpactController.value;

        final decay =
            1 - progress;

        final dx =
            math.sin(
                  progress *
                      math.pi *
                      7,
                ) *
                decay *
                4.8;

        final dy =
            math.sin(
                  progress *
                      math.pi *
                      9,
                ) *
                decay *
                2.2;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: child,
        );
      },
      child: Container(
        width: double.infinity,
        margin:
            const EdgeInsets.fromLTRB(
          8,
          4,
          8,
          0,
        ),
        decoration: BoxDecoration(
          gradient:
              const LinearGradient(
            begin:
                Alignment.topCenter,
            end:
                Alignment.bottomCenter,
            colors: [
              Color(0xFF1B5978),
              Color(0xFF123B54),
            ],
          ),
          borderRadius:
              BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white24,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  10,
                  88,
                  10,
                  18,
                ),
                child:
                    _buildTableDominoes(),
              ),
            ),

            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: Center(
                child: PlayerAvatar(
                  key: _playerAvatarKeys[0],
                  player: topPlayer,
                  dominoCount:
                      _game.handCountFor(0),
                  isActive:
                      _currentPlayerIndex == 0,
                  turnSecondsLeft:
                      _currentPlayerIndex == 0
                          ? _turnSecondsLeft
                          : null,
                  turnProgress:
                      _currentPlayerIndex == 0
                          ? _turnProgress
                          : 0,
                  onTap: () {
                    _openGiftMenu(
                      topPlayer,
                    );
                  },
                ),
              ),
            ),

            Positioned(
              left: 10,
              top: 48,
              child: PlayerAvatar(
                key: _playerAvatarKeys[1],
                player: leftPlayer,
                dominoCount:
                    _game.handCountFor(1),
                isActive:
                    _currentPlayerIndex == 1,
                turnSecondsLeft:
                    _currentPlayerIndex == 1
                        ? _turnSecondsLeft
                        : null,
                turnProgress:
                    _currentPlayerIndex == 1
                        ? _turnProgress
                        : 0,
                onTap: () {
                  _openGiftMenu(
                    leftPlayer,
                  );
                },
              ),
            ),

            Positioned(
              right: 10,
              top: 48,
              child: PlayerAvatar(
                key: _playerAvatarKeys[2],
                player: rightPlayer,
                dominoCount:
                    _game.handCountFor(2),
                isActive:
                    _currentPlayerIndex == 2,
                turnSecondsLeft:
                    _currentPlayerIndex == 2
                        ? _turnSecondsLeft
                        : null,
                turnProgress:
                    _currentPlayerIndex == 2
                        ? _turnProgress
                        : 0,
                onTap: () {
                  _openGiftMenu(
                    rightPlayer,
                  );
                },
              ),
            ),

            if (_game.boneyardCount > 0)
              Positioned(
                right: 14,
                bottom: 14,
                child: DominoBoneyardPile(
                  key: _boneyardKey,
                  count:
                      _game.boneyardCount,
                  enabled:
                      _isMyTurn &&
                      _boneyardDrawFlight ==
                          null &&
                      _hiddenDrawnHandIndex ==
                          null &&
                      _game.canDrawFromBoneyard(
                        _meIndex,
                      ),
                  onTap:
                      _drawFromBoneyardForMe,
                ),
              ),

          ],
        ),
      ),
    );
  }

  Widget _buildTableDominoes() {
    if (tableDominoes.isEmpty) {
      final index = selectedDominoIndex;

      if (index == null) {
        return Center(
          child: Text(
            _isMyTurn
                ? 'Выберите костяшку из руки'
                : 'Ход: ${players[_currentPlayerIndex].name}',
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      final domino = playerHand[index];
      final isDouble = domino.left == domino.right;

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Первый ход',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            DominoPlacementTarget(
              width: isDouble
                  ? _tableDominoShortSide
                  : _tableDominoLongSide,
              height: isDouble
                  ? _tableDominoLongSide
                  : _tableDominoShortSide,
              onTap: () {
                _playSelectedDomino(
                  DominoSide.right,
                );
              },
            ),
          ],
        ),
      );
    }

    return _buildSnakeChain();
  }

  Widget _buildSnakeChain() {
    return LayoutBuilder(
      builder: (
        context,
        constraints,
      ) {
        final trackLayout =
            _createFixedTrackLayout(
          constraints.biggest,
        );

        Domino? selectedDomino;
        bool canPlayLeft = false;
        bool canPlayRight = false;

        final selectedIndex =
            selectedDominoIndex;

        if (
          selectedIndex != null &&
          selectedIndex >= 0 &&
          selectedIndex <
              playerHand.length
        ) {
          selectedDomino =
              playerHand[selectedIndex];

          canPlayLeft =
              _canPlayOnLeft(
            selectedDomino,
          );

          canPlayRight =
              _canPlayOnRight(
            selectedDomino,
          );
        }

        return SizedBox(
          width:
              trackLayout.width,
          height:
              trackLayout.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (
                final placement
                    in trackLayout
                        .placements
              )
                _buildPlacedTableDomino(
                  placement,
                  shortSide:
                      trackLayout.dominoShortSide,
                ),

              if (
                selectedDomino != null &&
                canPlayLeft
              )
                _buildPlacementTarget(
                  connectionPoint:
                      trackLayout
                          .leftEnd,
                  outwardDirection:
                      trackLayout
                          .leftTargetDirection,
                  previousOutwardDirection:
                      trackLayout
                          .leftPreviousDirection,
                  domino:
                      selectedDomino,
                  side:
                      DominoSide.left,
                  boardSize:
                      constraints.biggest,
                  shortSide:
                      trackLayout.dominoShortSide,
                ),

              if (
                selectedDomino != null &&
                canPlayRight
              )
                _buildPlacementTarget(
                  connectionPoint:
                      trackLayout
                          .rightEnd,
                  outwardDirection:
                      _rightTargetDirectionFor(
                    layout:
                        trackLayout,
                    domino:
                        selectedDomino,
                  ),
                  previousOutwardDirection:
                      trackLayout
                          .rightPreviousDirection,
                  domino:
                      selectedDomino,
                  side:
                      DominoSide.right,
                  boardSize:
                      constraints.biggest,
                  shortSide:
                      trackLayout.dominoShortSide,
                ),
            ],
          ),
        );
      },
    );
  }

  _ChainDirection _oppositeDirection(
    _ChainDirection direction,
  ) {
    return switch (direction) {
      _ChainDirection.right =>
        _ChainDirection.left,
      _ChainDirection.left =>
        _ChainDirection.right,
      _ChainDirection.up =>
        _ChainDirection.down,
      _ChainDirection.down =>
        _ChainDirection.up,
    };
  }

  Offset _directionVector(
    _ChainDirection direction,
  ) {
    return switch (direction) {
      _ChainDirection.right =>
        const Offset(1, 0),
      _ChainDirection.left =>
        const Offset(-1, 0),
      _ChainDirection.up =>
        const Offset(0, -1),
      _ChainDirection.down =>
        const Offset(0, 1),
    };
  }

  bool _directionIsHorizontal(
    _ChainDirection direction,
  ) {
    return direction ==
            _ChainDirection.right ||
        direction ==
            _ChainDirection.left;
  }

  bool _displayHorizontalFor({
    required Domino domino,
    required _ChainDirection direction,
  }) {
    final pathIsHorizontal =
        _directionIsHorizontal(
      direction,
    );

    if (domino.left == domino.right) {
      // Дубль всегда поперёк линии.
      return !pathIsHorizontal;
    }

    // Обычная костяшка всегда вдоль линии.
    return pathIsHorizontal;
  }

  Size _displaySizeFor({
    required Domino domino,
    required _ChainDirection direction,
    required double shortSide,
  }) {
    final horizontal =
        _displayHorizontalFor(
      domino: domino,
      direction: direction,
    );

    final longSide =
        _tableDominoLongSideFor(shortSide);

    return Size(
      horizontal ? longSide : shortSide,
      horizontal ? shortSide : longSide,
    );
  }

  double _halfCenterOffsetFor(double shortSide) {
    return (
      _tableDominoLongSideFor(shortSide) -
      shortSide
    ) /
        2;
  }

  _TrackStepGeometry _placeTrackStep({
    required Offset connectionPoint,
    required _ChainDirection previousDirection,
    required _ChainDirection direction,
    required Domino domino,
    required double shortSide,
  }) {
    final vector =
        _directionVector(
      direction,
    );

    final isDouble =
        domino.left ==
        domino.right;

    final horizontal =
        _displayHorizontalFor(
      domino: domino,
      direction: direction,
    );

    // previousDirection намеренно не участвует в координатах.
    // На повороте мы просто начинаем новую костяшку
    // от центра открытого квадрата в новом направлении.
    //
    // Это даёт стык:
    //
    // [ 3 | 6 ]
    //       [ 6 ]
    //       [ 2 ]
    //
    // без диагонального сдвига и без наложения.
    if (isDouble) {
      // Дубль стоит поперёк направления цепочки.
      // Его центральная линия совпадает с линией соединения,
      // а ближайший край касается соседнего квадрата.
      //
      // connectionPoint — центр открытого квадрата предыдущей
      // костяшки. Сдвиг на один размер квадрата ставит дубль
      // ровно рядом с ним.
      final center =
          connectionPoint +
          vector *
              (
                shortSide +
                _trackGap
              );

      // ВАЖНО: для следующей костяшки точкой соединения
      // является центр дубля. Следующий обычный камень сам
      // сдвинется ещё на один квадрат и коснётся дальнего
      // края дубля. Если сдвинуть nextConnection ещё раз здесь,
      // получится пустой разрыв размером в целый квадрат.
      return _TrackStepGeometry(
        center: center,
        nextConnection: center,
        horizontal: horizontal,
      );
    }

    final connectingSquareCenter =
        connectionPoint +
        vector *
            (
              shortSide +
              _trackGap
            );

    final center =
        connectingSquareCenter +
        vector *
            _halfCenterOffsetFor(shortSide);

    final nextConnection =
        center +
        vector *
            _halfCenterOffsetFor(shortSide);

    return _TrackStepGeometry(
      center: center,
      nextConnection:
          nextConnection,
      horizontal: horizontal,
    );
  }

  _ChainDirection _rightTargetDirectionFor({
    required _FixedTrackLayout layout,
    required Domino domino,
  }) {
    final requiredSquares =
        domino.left == domino.right ? 1 : 2;

    final wouldOverflow =
        layout.rightRowUsedSquares + requiredSquares >
        _horizontalTrackSquares;

    if (layout.rightNeedsTurn || wouldOverflow) {
      return _ChainDirection.down;
    }

    return layout.rightRowDirection;
  }

  Widget _buildPlacementTarget({
    required Offset connectionPoint,
    required _ChainDirection outwardDirection,
    required _ChainDirection previousOutwardDirection,
    required Domino domino,
    required DominoSide side,
    required Size boardSize,
    required double shortSide,
  }) {
    final geometry =
        _placeTrackStep(
      connectionPoint:
          connectionPoint,
      previousDirection:
          previousOutwardDirection,
      direction:
          outwardDirection,
      domino:
          domino,
      shortSide:
          shortSide,
    );

    final logicalDirection = side == DominoSide.left
        ? _oppositeDirection(outwardDirection)
        : outwardDirection;

    final size = _displaySizeFor(
      domino: domino,
      direction: logicalDirection,
      shortSide: shortSide,
    );

    const targetMargin = 8.0;

    final rawLeft =
        geometry.center.dx -
        size.width / 2;

    final rawTop =
        geometry.center.dy -
        size.height / 2;

    final maxLeft =
        math.max(
          targetMargin,
          boardSize.width -
              targetMargin -
              size.width,
        );

    final maxTop =
        math.max(
          targetMargin,
          boardSize.height -
              targetMargin -
              size.height,
        );

    final safeLeft =
        rawLeft
            .clamp(
              targetMargin,
              maxLeft,
            )
            .toDouble();

    final safeTop =
        rawTop
            .clamp(
              targetMargin,
              maxTop,
            )
            .toDouble();

    return Positioned(
      left: safeLeft,
      top: safeTop,
      child: DominoPlacementTarget(
        width: size.width,
        height: size.height,
        onTap: () {
          _playSelectedDomino(side);
        },
      ),
    );
  }

  _TrackLayoutDraft _buildTrackLayoutDraft({
    required double shortSide,
  }) {
    final rawPlacements = <_ChainPlacement>[];

    final firstDomino = tableDominoes.first;
    final firstIsDouble =
        firstDomino.left == firstDomino.right;

    rawPlacements.add(
      _ChainPlacement(
        tableIndex: 0,
        domino: firstDomino,
        center: Offset.zero,
        direction: _ChainDirection.right,
      ),
    );

    final halfCenterOffset =
        _halfCenterOffsetFor(shortSide);

    final rawLeftEnd = firstIsDouble
        ? Offset.zero
        : Offset(-halfCenterOffset, 0);

    var connectionPoint = firstIsDouble
        ? Offset.zero
        : Offset(halfCenterOffset, 0);

    var previousDirection = _ChainDirection.right;
    var rowDirection = _ChainDirection.right;

    var rowUsedSquares = firstIsDouble ? 1 : 2;
    var needsTurn =
        rowUsedSquares >= _horizontalTrackSquares;

    for (
      var tableIndex = 1;
      tableIndex < tableDominoes.length;
      tableIndex++
    ) {
      final domino = tableDominoes[tableIndex];
      final isDouble = domino.left == domino.right;
      final requiredSquares = isDouble ? 1 : 2;

      final wouldOverflow =
          rowUsedSquares + requiredSquares >
          _horizontalTrackSquares;

      // ВАЖНО:
      // поворот больше НЕ зависит ни от текущего дубля,
      // ни от того, была ли предыдущая костяшка дублем.
      // Если строка заполнена или следующая костяшка не помещается,
      // траектория обязана перейти вниз до placement.
      final shouldTurnBeforeDomino =
          needsTurn || wouldOverflow;

      late final _ChainDirection direction;

      if (shouldTurnBeforeDomino) {
        direction = _ChainDirection.down;

        rowDirection =
            rowDirection == _ChainDirection.right
                ? _ChainDirection.left
                : _ChainDirection.right;

        // Вертикальный обычный камень занимает по ширине
        // нового ряда 1 квадрат. Дубль на вертикальном повороте
        // отображается горизонтально и физически занимает 2.
        rowUsedSquares = isDouble ? 2 : 1;
        needsTurn =
            rowUsedSquares >= _horizontalTrackSquares;
      } else {
        direction = rowDirection;
      }

      final geometry = _placeTrackStep(
        connectionPoint: connectionPoint,
        previousDirection: previousDirection,
        direction: direction,
        domino: domino,
        shortSide: shortSide,
      );

      rawPlacements.add(
        _ChainPlacement(
          tableIndex: tableIndex,
          domino: domino,
          center: geometry.center,
          direction: direction,
        ),
      );

      connectionPoint = geometry.nextConnection;

      if (_directionIsHorizontal(direction)) {
        rowUsedSquares += requiredSquares;
        needsTurn =
            rowUsedSquares >= _horizontalTrackSquares;
      }

      previousDirection = direction;
    }

    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;

    for (final placement in rawPlacements) {
      final size = _displaySizeFor(
        domino: placement.domino,
        direction: placement.direction,
        shortSide: shortSide,
      );

      minX = math.min(
        minX,
        placement.center.dx - size.width / 2,
      );
      maxX = math.max(
        maxX,
        placement.center.dx + size.width / 2,
      );
      minY = math.min(
        minY,
        placement.center.dy - size.height / 2,
      );
      maxY = math.max(
        maxY,
        placement.center.dy + size.height / 2,
      );
    }

    return _TrackLayoutDraft(
      placements: rawPlacements,
      leftEnd: rawLeftEnd,
      rightEnd: connectionPoint,
      previousDirection: previousDirection,
      rowDirection: rowDirection,
      needsTurn: needsTurn,
      rowUsedSquares: rowUsedSquares,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
  }

  _FixedTrackLayout _createFixedTrackLayout(
    Size boardSize,
  ) {
    final preferredShortSide =
        _preferredTableDominoShortSideForBoard(boardSize);

    if (tableDominoes.isEmpty) {
      return _FixedTrackLayout(
        placements: const [],
        leftEnd: Offset.zero,
        rightEnd: Offset.zero,
        leftTargetDirection: _ChainDirection.left,
        leftPreviousDirection: _ChainDirection.left,
        rightPreviousDirection: _ChainDirection.right,
        rightRowDirection: _ChainDirection.right,
        rightNeedsTurn: false,
        rightRowUsedSquares: 0,
        dominoShortSide: preferredShortSide,
        width: boardSize.width,
        height: boardSize.height,
      );
    }

    final safeBottomMargin =
        _game.boneyardCount > 0
            ? _boneyardSafeBottomMargin
            : _tableSafeMargin;

    final availableWidth = math.max(
      1.0,
      boardSize.width - (_tableSafeMargin * 2),
    );

    final availableHeight = math.max(
      1.0,
      boardSize.height -
          _tableSafeMargin -
          safeBottomMargin,
    );

    var shortSide = preferredShortSide;
    var draft = _buildTrackLayoutDraft(
      shortSide: shortSide,
    );

    // Размер подбирается по ФАКТИЧЕСКИ построенной змейке,
    // поэтому учитывается не только ширина, но и высота поля.
    // Геометрия линейно масштабируется вместе с shortSide.
    for (var attempt = 0; attempt < 3; attempt++) {
      final widthScale =
          draft.contentWidth <= 0
              ? 1.0
              : availableWidth / draft.contentWidth;

      final heightScale =
          draft.contentHeight <= 0
              ? 1.0
              : availableHeight / draft.contentHeight;

      final fitScale = math.min(
        1.0,
        math.min(widthScale, heightScale),
      );

      if (fitScale >= 0.999) {
        break;
      }

      // Маленький запас защищает от дробных пикселей и округления.
      shortSide = math.max(
        1.0,
        shortSide * fitScale * 0.985,
      );

      draft = _buildTrackLayoutDraft(
        shortSide: shortSide,
      );
    }

    final contentCenterX =
        (draft.minX + draft.maxX) / 2;
    final contentCenterY =
        (draft.minY + draft.maxY) / 2;

    final desiredShiftX =
        boardSize.width / 2 - contentCenterX;

    final minShiftX =
        _tableSafeMargin - draft.minX;
    final maxShiftX =
        boardSize.width -
        _tableSafeMargin -
        draft.maxX;

    final shiftX = minShiftX <= maxShiftX
        ? desiredShiftX
            .clamp(minShiftX, maxShiftX)
            .toDouble()
        : desiredShiftX;

    final minAllowedY = _tableSafeMargin;
    final maxAllowedY =
        boardSize.height - safeBottomMargin;

    final desiredCenterY =
        (minAllowedY + maxAllowedY) / 2;
    final desiredShiftY =
        desiredCenterY - contentCenterY;

    final minShiftY =
        minAllowedY - draft.minY;
    final maxShiftY =
        maxAllowedY - draft.maxY;

    final shiftY = minShiftY <= maxShiftY
        ? desiredShiftY
            .clamp(minShiftY, maxShiftY)
            .toDouble()
        : desiredShiftY;

    final shift = Offset(shiftX, shiftY);

    final placements = draft.placements.map(
      (placement) {
        return _ChainPlacement(
          tableIndex: placement.tableIndex,
          domino: placement.domino,
          center: placement.center + shift,
          direction: placement.direction,
        );
      },
    ).toList();

    return _FixedTrackLayout(
      placements: placements,
      leftEnd: draft.leftEnd + shift,
      rightEnd: draft.rightEnd + shift,
      leftTargetDirection: _ChainDirection.left,
      leftPreviousDirection: _ChainDirection.left,
      rightPreviousDirection: draft.previousDirection,
      rightRowDirection: draft.rowDirection,
      rightNeedsTurn: draft.needsTurn,
      rightRowUsedSquares: draft.rowUsedSquares,
      dominoShortSide: shortSide,
      width: boardSize.width,
      height: boardSize.height,
    );
  }

  Widget _buildPlacedTableDomino(
    _ChainPlacement placement, {
    required double shortSide,
  }) {
    final horizontal =
        placement
            .displayHorizontal;

    final size =
        _displaySizeFor(
      domino:
          placement.domino,
      direction:
          placement.direction,
      shortSide:
          shortSide,
    );

    final width =
        size.width;

    final height =
        size.height;

    final dominoTile =
        DominoTile(
      domino:
          placement.displayDomino,
      width: width,
      height: height,
      dotSize:
          _tableDominoDotSizeFor(shortSide),
      horizontal: horizontal,
    );

    final shouldAnimate =
        placement.tableIndex ==
            _animatedTableIndex &&
        _animationSourceGlobalCenter !=
            null;

    final child =
        shouldAnimate
            ? DominoPlayAnimation(
                key: ValueKey(
                  'domino-play-$_playAnimationId',
                ),
                sourceGlobalCenter:
                    _animationSourceGlobalCenter!,
                isDouble:
                    placement.isDouble,
                horizontal:
                    horizontal,
                soundEnabled:
                    _soundEnabled,
                onDoubleImpact:
                    _triggerDoubleTableImpact,
                child: dominoTile,
              )
            : dominoTile;

    return Positioned(
      left:
          placement.center.dx -
          width / 2,
      top:
          placement.center.dy -
          height / 2,
      child: child,
    );
  }


  Widget _buildMyPanel(Player me) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.only(
        top: 5,
        bottom: 8,
      ),
      decoration:
          const BoxDecoration(
        color: Color(0xFF111827),
      ),
      child: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          PlayerAvatar(
            key: _playerAvatarKeys[_meIndex],
            player: me,
            dominoCount:
                _game.handCountFor(_meIndex),
            isActive:
                _currentPlayerIndex == 3,
            turnSecondsLeft:
                _currentPlayerIndex == 3
                    ? _turnSecondsLeft
                    : null,
            turnProgress:
                _currentPlayerIndex == 3
                    ? _turnProgress
                    : 0,
            onTap: () {
              _openGiftMenu(me);
            },
          ),

          const SizedBox(height: 5),

          SizedBox(
            key: _handAreaKey,
            height: 108,
            child:
                ListView.separated(
              scrollDirection:
                  Axis.horizontal,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              itemCount:
                  playerHand.length,
              separatorBuilder: (
                context,
                index,
              ) {
                return const SizedBox(
                  width: 6,
                );
              },
              itemBuilder: (
                context,
                index,
              ) {
                final domino =
                    playerHand[index];

                final isSelected =
                    selectedDominoIndex ==
                        index;

                final isHiddenByDraw =
                    _hiddenDrawnHandIndex ==
                        index;

                final canPlay =
                    _isMyTurn &&
                    !isHiddenByDraw &&
                    _boneyardDrawFlight ==
                        null &&
                    _canPlayDomino(
                      domino,
                    );

                return AnimatedOpacity(
                  duration:
                      const Duration(
                    milliseconds: 180,
                  ),
                  opacity:
                      isHiddenByDraw
                          ? 0
                          : canPlay
                              ? 1
                              : (_isMyTurn ? 0.35 : 0.58),
                  child:
                      AnimatedContainer(
                    key:
                        _handDominoKeys[
                          index
                        ],
                    duration:
                        const Duration(
                      milliseconds: 180,
                    ),
                    curve:
                        Curves.easeOut,
                    transform:
                        Matrix4
                            .translationValues(
                      0,
                      isSelected
                          ? -8
                          : 0,
                      0,
                    ),
                    child: DominoTile(
                      domino: domino,
                      width: 52,
                      height: 88,
                      dotSize: 7,
                      onTap:
                          canPlay
                              ? () {
                                  _selectDomino(
                                    index,
                                  );
                                }
                              : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
