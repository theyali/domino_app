import 'dart:async';

import 'package:flutter/material.dart';

import '../models/multiplayer_game_state.dart';
import '../models/player.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../services/game_socket_service.dart';
import '../widgets/domino_boneyard_draw_animation.dart';
import '../widgets/domino_boneyard_pile.dart';
import '../widgets/domino_placement_target.dart';
import '../widgets/domino_tile.dart';
import '../widgets/multiplayer_domino_snake.dart';
import '../widgets/multiplayer_game_result_overlay.dart';
import '../widgets/player_avatar.dart';

class _BoneyardDrawFlight {
  final int id;
  final ServerDomino domino;
  final Offset sourceGlobalCenter;
  final Offset targetGlobalCenter;

  const _BoneyardDrawFlight({
    required this.id,
    required this.domino,
    required this.sourceGlobalCenter,
    required this.targetGlobalCenter,
  });
}

class MultiplayerGameScreen extends StatefulWidget {
  final Restaurant restaurant;
  final MultiplayerGameState initialGameState;

  const MultiplayerGameScreen({
    super.key,
    required this.restaurant,
    required this.initialGameState,
  });

  @override
  State<MultiplayerGameScreen> createState() =>
      _MultiplayerGameScreenState();
}

class _MultiplayerGameScreenState extends State<MultiplayerGameScreen> {
  final ApiService _apiService = const ApiService();

  late final GameSocketService _socketService;
  StreamSubscription<Map<String, dynamic>>? _messageSubscription;
  StreamSubscription<SocketConnectionStatus>? _statusSubscription;

  late MultiplayerGameState _gameState;
  SocketConnectionStatus _socketStatus = SocketConnectionStatus.connecting;

  final Map<int, GlobalKey> _playerAvatarKeys = <int, GlobalKey>{};
  final Map<int, GlobalKey> _handDominoKeys = <int, GlobalKey>{};
  final GlobalKey _boneyardKey = GlobalKey(debugLabel: 'multiplayer-boneyard');
  final GlobalKey _handAreaKey = GlobalKey(debugLabel: 'multiplayer-hand-area');

  bool _isSubmittingMove = false;
  bool _isStartingNextRound = false;
  bool _isLeavingGame = false;
  bool _allowPop = false;

  int? _pendingDominoId;
  int? _selectedDominoId;

  Offset? _pendingMoveSourceGlobalCenter;
  int? _animatedMoveNumber;
  Offset? _animationSourceGlobalCenter;

  Offset? _pendingBoneyardSourceGlobalCenter;
  Offset? _pendingBoneyardTargetGlobalCenter;
  _BoneyardDrawFlight? _boneyardDrawFlight;
  int? _hiddenDrawnDominoId;
  int _boneyardAnimationId = 0;

  Timer? _turnTicker;
  Duration _serverClockOffset = Duration.zero;
  bool _isCheckingTurnTimeout = false;
  DateTime? _nextTurnTimeoutCheckAt;

  static const bool _soundEnabled = true;
  static const Duration _turnTickInterval = Duration(milliseconds: 200);

  @override
  void initState() {
    super.initState();
    _gameState = widget.initialGameState;
    _syncServerClock(_gameState);
    _socketService = GameSocketService();

    _messageSubscription = _socketService.messages.listen(_handleSocketMessage);
    _statusSubscription = _socketService.statuses.listen((status) {
      if (!mounted) return;
      setState(() {
        _socketStatus = status;
      });
    });

    unawaited(
      _socketService.connectToRoom(
        roomId: _gameState.roomId,
        playerId: _gameState.myPlayerId,
      ),
    );

    _restartTurnTicker();
  }

  @override
  void dispose() {
    _turnTicker?.cancel();
    unawaited(_messageSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    unawaited(_socketService.dispose());
    super.dispose();
  }

  GlobalKey _playerAvatarKeyFor(int playerId) {
    return _playerAvatarKeys.putIfAbsent(
      playerId,
      () => GlobalKey(debugLabel: 'multiplayer-avatar-$playerId'),
    );
  }

  GlobalKey _handDominoKeyFor(int dominoId) {
    return _handDominoKeys.putIfAbsent(
      dominoId,
      () => GlobalKey(debugLabel: 'multiplayer-hand-$dominoId'),
    );
  }

  Offset? _globalCenterForKey(GlobalKey? key) {
    if (key == null) return null;

    final renderObject = key.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    return renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
    );
  }

  void _syncServerClock(MultiplayerGameState state) {
    final serverTime = state.serverTime?.toUtc();
    if (serverTime == null) {
      return;
    }

    _serverClockOffset = serverTime.difference(DateTime.now().toUtc());
  }

  DateTime get _serverNow =>
      DateTime.now().toUtc().add(_serverClockOffset);

  int? get _turnSecondsLeft {
    if (!_gameState.isActive) {
      return null;
    }

    final deadline = _gameState.turnDeadlineAt?.toUtc();
    if (deadline == null) {
      return null;
    }

    final milliseconds = deadline.difference(_serverNow).inMilliseconds;
    if (milliseconds <= 0) {
      return 0;
    }

    return (milliseconds / 1000).ceil();
  }

  double get _turnProgress {
    if (!_gameState.isActive) {
      return 0;
    }

    final startedAt = _gameState.turnStartedAt?.toUtc();
    final deadline = _gameState.turnDeadlineAt?.toUtc();
    if (startedAt == null || deadline == null) {
      return 0;
    }

    final totalMilliseconds = deadline.difference(startedAt).inMilliseconds;
    if (totalMilliseconds <= 0) {
      return 0;
    }

    final remainingMilliseconds = deadline.difference(_serverNow).inMilliseconds;
    return (remainingMilliseconds / totalMilliseconds)
        .clamp(0.0, 1.0)
        .toDouble();
  }

  void _restartTurnTicker() {
    _turnTicker?.cancel();
    _turnTicker = null;
    _nextTurnTimeoutCheckAt = null;

    if (!_gameState.isActive || _gameState.turnDeadlineAt == null) {
      return;
    }

    _turnTicker = Timer.periodic(_turnTickInterval, _handleTurnTick);
  }

  void _handleTurnTick(Timer timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }

    setState(() {});

    final deadline = _gameState.turnDeadlineAt?.toUtc();
    if (!_gameState.isActive || deadline == null || _serverNow.isBefore(deadline)) {
      return;
    }

    final now = DateTime.now();
    final nextCheckAt = _nextTurnTimeoutCheckAt;
    if (_isCheckingTurnTimeout ||
        (nextCheckAt != null && now.isBefore(nextCheckAt))) {
      return;
    }

    _nextTurnTimeoutCheckAt = now.add(const Duration(seconds: 1));
    unawaited(_refreshExpiredTurn());
  }

  Future<void> _refreshExpiredTurn() async {
    if (_isCheckingTurnTimeout || !_gameState.isActive) {
      return;
    }

    _isCheckingTurnTimeout = true;

    try {
      final state = await _apiService.fetchGameState(
        roomId: _gameState.roomId,
        playerId: _gameState.myPlayerId,
      );

      if (!mounted) return;
      _applyGameState(state);
    } catch (_) {
      // Heartbeat/reconnect will retry server recovery. Do not show a snackbar
      // every second while the network is temporarily unavailable.
    } finally {
      _isCheckingTurnTimeout = false;
    }
  }

  ServerDomino? get _selectedDomino {
    final selectedId = _selectedDominoId;
    if (selectedId == null) return null;

    for (final domino in _gameState.myHand) {
      if (domino.id == selectedId) {
        return domino;
      }
    }

    return null;
  }

  void _handleSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];

    if (type == 'room_deleted') {
      unawaited(_handleRoomDeleted());
      return;
    }

    if (type != 'game_started' && type != 'game_state') {
      return;
    }

    final rawGame = message['game'];
    if (rawGame is! Map) return;

    final state = MultiplayerGameState.fromJson(
      Map<String, dynamic>.from(rawGame),
    );

    _applyGameState(state);
  }

  Future<void> _handleRoomDeleted() async {
    if (!mounted || _isLeavingGame || _allowPop) return;

    await _socketService.disconnect();
    if (!mounted) return;

    setState(() {
      _allowPop = true;
    });

    _showMessage('Стол закрыт: все игроки вышли.');
    Navigator.of(context).pop();
  }

  ServerDomino? _findNewMove(
    MultiplayerGameState previous,
    MultiplayerGameState next,
  ) {
    final previousMoveNumbers = previous.table
        .map((domino) => domino.moveNumber)
        .whereType<int>()
        .toSet();

    ServerDomino? newest;

    for (final domino in next.table) {
      final moveNumber = domino.moveNumber;
      if (moveNumber == null || previousMoveNumbers.contains(moveNumber)) {
        continue;
      }

      if (newest == null || moveNumber > (newest.moveNumber ?? -1)) {
        newest = domino;
      }
    }

    return newest;
  }

  ServerDomino? _findNewHandDomino(
    MultiplayerGameState previous,
    MultiplayerGameState next,
  ) {
    final previousIds = previous.myHand.map((domino) => domino.id).toSet();
    for (final domino in next.myHand.reversed) {
      if (!previousIds.contains(domino.id)) {
        return domino;
      }
    }
    return null;
  }

  void _applyGameState(MultiplayerGameState state) {
    if (!mounted || state.version < _gameState.version) {
      return;
    }

    final previousState = _gameState;
    final isNewVersion = state.version > previousState.version;
    final isNewRound = state.roundNumber != previousState.roundNumber;

    final newMove = isNewVersion ? _findNewMove(previousState, state) : null;
    final newDraw = isNewVersion &&
            state.boneyardCount < previousState.boneyardCount &&
            state.myHand.length > previousState.myHand.length
        ? _findNewHandDomino(previousState, state)
        : null;

    Offset? moveSource;

    if (newMove != null) {
      final playedBy = newMove.playedByPlayerId;

      if (playedBy == state.myPlayerId) {
        moveSource = _pendingMoveSourceGlobalCenter ??
            _globalCenterForKey(_handDominoKeys[newMove.id]) ??
            _globalCenterForKey(_playerAvatarKeys[state.myPlayerId]);
      } else if (playedBy != null) {
        moveSource = _globalCenterForKey(_playerAvatarKeys[playedBy]);
      }
    }

    final drawSource =
        _pendingBoneyardSourceGlobalCenter ?? _globalCenterForKey(_boneyardKey);
    final drawTarget = _pendingBoneyardTargetGlobalCenter ??
        _globalCenterForKey(_handAreaKey) ??
        _globalCenterForKey(_playerAvatarKeys[state.myPlayerId]);

    final serverTime = state.serverTime?.toUtc();
    final nextClockOffset = serverTime == null
        ? _serverClockOffset
        : serverTime.difference(DateTime.now().toUtc());

    setState(() {
      _gameState = state;
      _serverClockOffset = nextClockOffset;

      if (isNewRound) {
        _animatedMoveNumber = null;
        _animationSourceGlobalCenter = null;
        _selectedDominoId = null;
        _boneyardDrawFlight = null;
        _hiddenDrawnDominoId = null;
      }

      if (newMove != null &&
          newMove.moveNumber != null &&
          moveSource != null) {
        _animatedMoveNumber = newMove.moveNumber;
        _animationSourceGlobalCenter = moveSource;
      }

      if (newDraw != null && drawSource != null && drawTarget != null) {
        _boneyardAnimationId += 1;
        _hiddenDrawnDominoId = newDraw.id;
        _boneyardDrawFlight = _BoneyardDrawFlight(
          id: _boneyardAnimationId,
          domino: newDraw,
          sourceGlobalCenter: drawSource,
          targetGlobalCenter: drawTarget,
        );
      }

      if (_selectedDominoId != null &&
          !_gameState.myHand.any(
            (domino) => domino.id == _selectedDominoId,
          )) {
        _selectedDominoId = null;
      }

      if (!_gameState.isMyTurn || !_gameState.isActive) {
        _selectedDominoId = null;
      }

      if (isNewVersion) {
        _isSubmittingMove = false;
        _pendingDominoId = null;
        _pendingMoveSourceGlobalCenter = null;
        _pendingBoneyardSourceGlobalCenter = null;
        _pendingBoneyardTargetGlobalCenter = null;
      } else if (_pendingDominoId != null &&
          !_gameState.myHand.any(
            (domino) => domino.id == _pendingDominoId,
          )) {
        _pendingDominoId = null;
        _isSubmittingMove = false;
        _pendingMoveSourceGlobalCenter = null;
      }

      if (_gameState.isActive) {
        _isStartingNextRound = false;
      }
    });

    _restartTurnTicker();
  }

  Future<void> _onDominoTap(ServerDomino domino) async {
    if (_isSubmittingMove || !_gameState.isActive) {
      return;
    }

    if (!_gameState.isMyTurn) {
      _showMessage('Сейчас ход ${_gameState.currentPlayer.name}.');
      return;
    }

    final sides = _gameState.playableSidesFor(domino);
    if (sides.isEmpty) {
      _showMessage('Эта костяшка сейчас не подходит.');
      return;
    }

    setState(() {
      _selectedDominoId = _selectedDominoId == domino.id ? null : domino.id;
    });
  }

  Future<void> _playSelectedSide(String side) async {
    if (_isSubmittingMove || !_gameState.isActive) return;

    final domino = _selectedDomino;
    if (domino == null) {
      return;
    }

    final sides = _gameState.playableSidesFor(domino);
    if (!sides.contains(side)) {
      _showMessage('Этот конец цепочки уже недоступен для выбранной костяшки.');
      return;
    }

    await _submitMove(
      domino: domino,
      side: side,
    );
  }

  Future<void> _submitMove({
    required ServerDomino domino,
    required String side,
  }) async {
    if (_isSubmittingMove || !_gameState.isActive) return;

    final sourceCenter =
        _globalCenterForKey(_handDominoKeys[domino.id]) ??
        _globalCenterForKey(_playerAvatarKeys[_gameState.myPlayerId]);

    setState(() {
      _isSubmittingMove = true;
      _pendingDominoId = domino.id;
      _pendingMoveSourceGlobalCenter = sourceCenter;
    });

    try {
      final state = await _apiService.playDomino(
        roomId: _gameState.roomId,
        playerId: _gameState.myPlayerId,
        dominoId: domino.id,
        side: side,
      );

      if (!mounted) return;
      _applyGameState(state);
    } on ApiException catch (error) {
      _finishSubmittingWithError(error.message);
    } catch (_) {
      _finishSubmittingWithError('Не удалось отправить ход на сервер.');
    }
  }

  Future<void> _drawDomino() async {
    if (_isSubmittingMove || !_gameState.canDrawFromBoneyard) {
      return;
    }

    final sourceCenter = _globalCenterForKey(_boneyardKey);
    final targetCenter = _globalCenterForKey(_handAreaKey) ??
        _globalCenterForKey(_playerAvatarKeys[_gameState.myPlayerId]);

    setState(() {
      _isSubmittingMove = true;
      _pendingDominoId = null;
      _selectedDominoId = null;
      _pendingMoveSourceGlobalCenter = null;
      _pendingBoneyardSourceGlobalCenter = sourceCenter;
      _pendingBoneyardTargetGlobalCenter = targetCenter;
    });

    try {
      final state = await _apiService.drawDomino(
        roomId: _gameState.roomId,
        playerId: _gameState.myPlayerId,
      );

      if (!mounted) return;
      _applyGameState(state);
    } on ApiException catch (error) {
      _finishSubmittingWithError(error.message);
    } catch (_) {
      _finishSubmittingWithError('Не удалось взять костяшку из базара.');
    }
  }

  void _finishBoneyardDrawAnimation() {
    if (!mounted) return;
    setState(() {
      _boneyardDrawFlight = null;
      _hiddenDrawnDominoId = null;
    });
  }

  Future<void> _passTurn() async {
    if (_isSubmittingMove || !_gameState.canPass) {
      return;
    }

    setState(() {
      _isSubmittingMove = true;
      _pendingDominoId = null;
      _selectedDominoId = null;
      _pendingMoveSourceGlobalCenter = null;
    });

    try {
      final state = await _apiService.passTurn(
        roomId: _gameState.roomId,
        playerId: _gameState.myPlayerId,
      );

      if (!mounted) return;
      _applyGameState(state);
    } on ApiException catch (error) {
      _finishSubmittingWithError(error.message);
    } catch (_) {
      _finishSubmittingWithError('Не удалось передать ход.');
    }
  }

  Future<void> _startNextRound() async {
    if (_isStartingNextRound ||
        _isLeavingGame ||
        !_gameState.isRoundFinished ||
        !_gameState.myPlayer.isOwner) {
      return;
    }

    setState(() {
      _isStartingNextRound = true;
    });

    try {
      final state = await _apiService.startNextRound(
        roomId: _gameState.roomId,
        playerId: _gameState.myPlayerId,
      );

      if (!mounted) return;
      _applyGameState(state);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isStartingNextRound = false;
      });
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isStartingNextRound = false;
      });
      _showMessage('Не удалось запустить следующий раунд.');
    }
  }

  Future<void> _requestExitGame() async {
    if (_isLeavingGame || _allowPop) return;

    final activeMatch = _gameState.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выйти из игры?'),
          content: Text(
            activeMatch
                ? 'Если выйти сейчас, текущий матч завершится для остальных игроков.'
                : 'Ты покинешь этот стол. Когда выйдет последний игрок, стол удалится автоматически.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Остаться'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _isLeavingGame = true;
    });

    try {
      await _apiService.leaveRoom(
        roomId: _gameState.roomId,
        playerId: _gameState.myPlayerId,
      );

      await _socketService.disconnect();
      if (!mounted) return;

      setState(() {
        _allowPop = true;
      });

      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLeavingGame = false;
      });
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLeavingGame = false;
      });
      _showMessage('Не удалось выйти из игры.');
    }
  }

  void _finishSubmittingWithError(String message) {
    if (!mounted) return;
    setState(() {
      _isSubmittingMove = false;
      _pendingDominoId = null;
      _pendingMoveSourceGlobalCenter = null;
      _pendingBoneyardSourceGlobalCenter = null;
      _pendingBoneyardTargetGlobalCenter = null;
    });
    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          unawaited(_requestExitGame());
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFF0D1B2A),
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(widget.restaurant.name),
          centerTitle: true,
          leading: IconButton(
            onPressed: _isLeavingGame ? null : _requestExitGame,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _SocketDot(status: _socketStatus),
            ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(child: _buildGameArea()),
                  _buildMyPanel(),
                ],
              ),
              if (_boneyardDrawFlight != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DominoBoneyardDrawAnimation(
                      key: ValueKey(
                        'multiplayer-boneyard-draw-${_boneyardDrawFlight!.id}',
                      ),
                      domino: _boneyardDrawFlight!.domino.domino,
                      sourceGlobalCenter:
                          _boneyardDrawFlight!.sourceGlobalCenter,
                      targetGlobalCenter:
                          _boneyardDrawFlight!.targetGlobalCenter,
                      soundEnabled: _soundEnabled,
                      onCompleted: _finishBoneyardDrawAnimation,
                    ),
                  ),
                ),
              if (!_gameState.isActive && _gameState.roundResult != null)
                Positioned.fill(
                  child: MultiplayerGameResultOverlay(
                    gameState: _gameState,
                    isStartingNextRound: _isStartingNextRound,
                    isLeaving: _isLeavingGame,
                    onNextRound: _startNextRound,
                    onExit: _requestExitGame,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGameArea() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1B5978),
            Color(0xFF123B54),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white24),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ..._buildOpponentAvatars(),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 110, 10, 105),
              child: _buildTableCenter(),
            ),
          ),
          if (_gameState.boneyardCount > 0)
            Positioned(
              right: 14,
              bottom: 14,
              child: DominoBoneyardPile(
                key: _boneyardKey,
                count: _gameState.boneyardCount,
                enabled: _gameState.canDrawFromBoneyard && !_isSubmittingMove,
                onTap: _drawDomino,
              ),
            ),
          if (_gameState.canPass)
            Positioned(
              right: 14,
              bottom: 18,
              child: FilledButton.icon(
                onPressed: _isSubmittingMove ? null : _passTurn,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF183B52),
                  foregroundColor: Colors.greenAccent,
                  side: const BorderSide(color: Colors.greenAccent),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.skip_next_rounded, size: 20),
                label: const Text(
                  'Пас',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          Positioned(
            left: 14,
            bottom: 16,
            child: _RoundBadge(roundNumber: _gameState.roundNumber),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOpponentAvatars() {
    final mySeat = _gameState.myPlayer.seatIndex;
    final playerCount = _gameState.players.length;
    final opponents = _gameState.players
        .where((player) => player.id != _gameState.myPlayerId)
        .toList(growable: false);

    final widgets = <Widget>[];

    for (final opponent in opponents) {
      final relativeSeat =
          (opponent.seatIndex - mySeat + playerCount) % playerCount;
      final isCurrentTurn = _gameState.isActive &&
          opponent.isActive &&
          opponent.id == _gameState.currentPlayerId;
      final avatar = PlayerAvatar(
        key: _playerAvatarKeyFor(opponent.id),
        player: _toPlayer(opponent, isMe: false),
        dominoCount: opponent.dominoCount,
        isActive: isCurrentTurn,
        turnSecondsLeft: isCurrentTurn ? _turnSecondsLeft : null,
        turnProgress: isCurrentTurn ? _turnProgress : 0,
        onTap: () {},
      );

      if (playerCount == 2) {
        widgets.add(
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Center(child: avatar),
          ),
        );
        continue;
      }

      if (playerCount == 3) {
        if (relativeSeat == 1) {
          widgets.add(Positioned(right: 12, top: 34, child: avatar));
        } else {
          widgets.add(Positioned(left: 12, top: 34, child: avatar));
        }
        continue;
      }

      switch (relativeSeat) {
        case 1:
          widgets.add(Positioned(right: 10, top: 48, child: avatar));
          break;
        case 2:
          widgets.add(
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: Center(child: avatar),
            ),
          );
          break;
        case 3:
          widgets.add(Positioned(left: 10, top: 48, child: avatar));
          break;
      }
    }

    return widgets;
  }

  Widget _buildTableCenter() {
    final selected = _selectedDomino;

    if (_gameState.table.isNotEmpty) {
      final selectedSides = selected == null
          ? const <String>{}
          : _gameState.playableSidesFor(selected);

      return Column(
        children: [
          Expanded(
            child: MultiplayerDominoSnake(
              dominoes: _gameState.table,
              selectedDomino: selected,
              playableSides: selectedSides,
              onTargetTap: _playSelectedSide,
              animatedMoveNumber: _animatedMoveNumber,
              animationSourceGlobalCenter: _animationSourceGlobalCenter,
              soundEnabled: _soundEnabled,
            ),
          ),
          const SizedBox(height: 6),
          _TableStatus(gameState: _gameState),
        ],
      );
    }

    final isMyTurn = _gameState.isMyTurn;
    final openingDomino = _gameState.requiredOpeningDomino;
    final selectedSides = selected == null
        ? const <String>{}
        : _gameState.playableSidesFor(selected);
    final canPlaceOpening = selected != null && selectedSides.contains('center');

    if (canPlaceOpening) {
      final isDouble = selected.domino.left == selected.domino.right;

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Первый ход',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            DominoPlacementTarget(
              width: isDouble ? 34 : 68,
              height: isDouble ? 68 : 34,
              onTap: () => _playSelectedSide('center'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Нажми на пунктир, чтобы отправить ход серверу',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMyTurn ? Icons.touch_app_rounded : Icons.hourglass_top_rounded,
            color: isMyTurn ? Colors.greenAccent : Colors.white54,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            isMyTurn
                ? 'Твой первый ход'
                : 'Первый ход: ${_gameState.currentPlayer.name}',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isMyTurn ? Colors.greenAccent : Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            openingDomino == null
                ? 'Сервер раздал костяшки и определил очередь.'
                : 'Сначала выбери зелёную костяшку в своей руке.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPanel() {
    final me = _gameState.myPlayer;
    final isMyCurrentTurn = _gameState.isActive && _gameState.isMyTurn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 5, bottom: 8),
      decoration: const BoxDecoration(color: Color(0xFF111827)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlayerAvatar(
            key: _playerAvatarKeyFor(me.id),
            player: _toPlayer(me, isMe: true),
            dominoCount: _gameState.myHand.length,
            isActive: isMyCurrentTurn,
            turnSecondsLeft: isMyCurrentTurn ? _turnSecondsLeft : null,
            turnProgress: isMyCurrentTurn ? _turnProgress : 0,
            onTap: () {},
          ),
          const SizedBox(height: 5),
          SizedBox(
            key: _handAreaKey,
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _gameState.myHand.length,
              separatorBuilder: (context, index) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final serverDomino = _gameState.myHand[index];
                final playableSides = _gameState.playableSidesFor(serverDomino);
                final isPlayable = playableSides.isNotEmpty;
                final isPending = _pendingDominoId == serverDomino.id;
                final isSelected = _selectedDominoId == serverDomino.id;
                final isHiddenByDraw =
                    _hiddenDrawnDominoId == serverDomino.id;
                final isRequiredOpening = _gameState.table.isEmpty &&
                    _gameState.isMyTurn &&
                    serverDomino.id == _gameState.openingDominoId;

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: isHiddenByDraw
                      ? 0
                      : _gameState.isMyTurn && !isPlayable
                          ? 0.55
                          : 1,
                  child: AnimatedContainer(
                    key: _handDominoKeyFor(serverDomino.id),
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    transform: Matrix4.translationValues(
                      0,
                      isSelected ? -8 : 0,
                      0,
                    ),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      color: isSelected
                          ? Colors.greenAccent.withValues(alpha: 0.08)
                          : Colors.transparent,
                      border: Border.all(
                        color: isPlayable || isRequiredOpening
                            ? Colors.greenAccent
                            : Colors.transparent,
                        width: isSelected ? 3.4 : 3,
                      ),
                      boxShadow: isPlayable
                          ? [
                              BoxShadow(
                                color: Colors.greenAccent.withValues(
                                  alpha: isSelected ? 0.38 : 0.24,
                                ),
                                blurRadius: isSelected ? 18 : 12,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        DominoTile(
                          domino: serverDomino.domino,
                          width: 48,
                          height: 84,
                          dotSize: 6.2,
                          onTap: isHiddenByDraw
                              ? null
                              : () => _onDominoTap(serverDomino),
                        ),
                        if (isPending)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.34),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.greenAccent,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 2),
            child: Text(
              _handHintText(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _gameState.isMyTurn ? Colors.white70 : Colors.white38,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _handHintText() {
    if (_gameState.isRoundFinished) {
      return 'Раунд завершён.';
    }

    if (_gameState.isMatchFinished) {
      return 'Матч завершён.';
    }

    if (_isSubmittingMove) {
      return 'Сервер проверяет действие...';
    }

    if (!_gameState.isMyTurn) {
      return 'Ход: ${_gameState.currentPlayer.name}';
    }

    if (_selectedDomino != null) {
      if (_gameState.table.isEmpty) {
        return 'Костяшка выбрана — нажми пунктир в центре стола.';
      }
      return 'Костяшка выбрана — нажми доступный пунктир на конце цепочки.';
    }

    if (_gameState.table.isEmpty) {
      return 'Нажми зелёную стартовую костяшку.';
    }

    if (_gameState.hasPlayableDomino) {
      return 'Выбери зелёную костяшку — появятся доступные концы цепочки.';
    }

    if (_gameState.boneyardCount > 0) {
      return 'Нет подходящей костяшки — возьми одну из базара.';
    }

    return 'Ходов нет и базар пуст — нажми «Пас».';
  }

  Player _toPlayer(MultiplayerPlayerState player, {required bool isMe}) {
    return Player(
      id: player.id,
      name: player.name,
      score: player.score,
      isMe: isMe,
    );
  }
}

class _TableStatus extends StatelessWidget {
  final MultiplayerGameState gameState;

  const _TableStatus({required this.gameState});

  @override
  Widget build(BuildContext context) {
    if (!gameState.isActive) {
      return const SizedBox.shrink();
    }

    final isMyTurn = gameState.isMyTurn;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        '${isMyTurn ? 'Твой ход' : 'Ход: ${gameState.currentPlayer.name}'}'
        '  ·  ${gameState.leftEnd} ← цепочка → ${gameState.rightEnd}',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isMyTurn ? Colors.greenAccent : Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SocketDot extends StatelessWidget {
  final SocketConnectionStatus status;

  const _SocketDot({required this.status});

  @override
  Widget build(BuildContext context) {
    final connected = status == SocketConnectionStatus.connected;

    return Tooltip(
      message: connected ? 'Realtime подключён' : 'Realtime переподключается',
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: connected ? Colors.greenAccent : Colors.orangeAccent,
          boxShadow: [
            BoxShadow(
              color: (connected ? Colors.greenAccent : Colors.orangeAccent)
                  .withValues(alpha: 0.35),
              blurRadius: 7,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundBadge extends StatelessWidget {
  final int roundNumber;

  const _RoundBadge({required this.roundNumber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        'Раунд $roundNumber',
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
