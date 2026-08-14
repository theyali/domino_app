import 'dart:async';

import 'package:flutter/material.dart';

import '../models/multiplayer_game_state.dart';
import '../models/player.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../services/game_socket_service.dart';
import '../widgets/domino_boneyard_pile.dart';
import '../widgets/domino_placement_target.dart';
import '../widgets/domino_tile.dart';
import '../widgets/multiplayer_domino_snake.dart';
import '../widgets/player_avatar.dart';

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

  bool _isSubmittingMove = false;
  int? _pendingDominoId;
  int? _selectedDominoId;

  Offset? _pendingMoveSourceGlobalCenter;
  int? _animatedMoveNumber;
  Offset? _animationSourceGlobalCenter;

  @override
  void initState() {
    super.initState();
    _gameState = widget.initialGameState;
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
  }

  @override
  void dispose() {
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

      if (newest == null ||
          moveNumber > (newest.moveNumber ?? -1)) {
        newest = domino;
      }
    }

    return newest;
  }

  void _applyGameState(MultiplayerGameState state) {
    if (!mounted || state.version < _gameState.version) {
      return;
    }

    final previousState = _gameState;
    final isNewVersion = state.version > previousState.version;
    final newMove = isNewVersion
        ? _findNewMove(previousState, state)
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

    setState(() {
      _gameState = state;

      if (newMove != null &&
          newMove.moveNumber != null &&
          moveSource != null) {
        _animatedMoveNumber = newMove.moveNumber;
        _animationSourceGlobalCenter = moveSource;
      }

      if (_selectedDominoId != null &&
          !_gameState.myHand.any(
            (domino) => domino.id == _selectedDominoId,
          )) {
        _selectedDominoId = null;
      }

      if (!_gameState.isMyTurn) {
        _selectedDominoId = null;
      }

      if (isNewVersion) {
        _isSubmittingMove = false;
        _pendingDominoId = null;
        _pendingMoveSourceGlobalCenter = null;
      } else if (_pendingDominoId != null &&
          !_gameState.myHand.any(
            (domino) => domino.id == _pendingDominoId,
          )) {
        _pendingDominoId = null;
        _isSubmittingMove = false;
        _pendingMoveSourceGlobalCenter = null;
      }
    });
  }

  Future<void> _onDominoTap(ServerDomino domino) async {
    if (_isSubmittingMove) {
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
      _selectedDominoId = _selectedDominoId == domino.id
          ? null
          : domino.id;
    });
  }

  Future<void> _playSelectedSide(String side) async {
    if (_isSubmittingMove) return;

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
    if (_isSubmittingMove) return;

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

    setState(() {
      _isSubmittingMove = true;
      _pendingDominoId = null;
      _selectedDominoId = null;
      _pendingMoveSourceGlobalCenter = null;
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

  void _finishSubmittingWithError(String message) {
    if (!mounted) return;
    setState(() {
      _isSubmittingMove = false;
      _pendingDominoId = null;
      _pendingMoveSourceGlobalCenter = null;
    });
    _showMessage(message);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showExitMessage() {
    _showMessage(
      'Игра уже запущена. Безопасный выход и reconnect добавим отдельным этапом.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitMessage();
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
            onPressed: _showExitMessage,
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
          child: Column(
            children: [
              Expanded(child: _buildGameArea()),
              _buildMyPanel(),
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
      final avatar = PlayerAvatar(
        key: _playerAvatarKeyFor(opponent.id),
        player: _toPlayer(opponent, isMe: false),
        dominoCount: opponent.dominoCount,
        isActive: opponent.id == _gameState.currentPlayerId,
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
              soundEnabled: true,
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
    final canPlaceOpening = selected != null &&
        selectedSides.contains('center');

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
            isActive: _gameState.isMyTurn,
            onTap: () {},
          ),
          const SizedBox(height: 5),
          SizedBox(
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
                final isRequiredOpening =
                    _gameState.table.isEmpty &&
                    _gameState.isMyTurn &&
                    serverDomino.id == _gameState.openingDominoId;

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: _gameState.isMyTurn && !isPlayable ? 0.55 : 1,
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
                          onTap: () => _onDominoTap(serverDomino),
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
