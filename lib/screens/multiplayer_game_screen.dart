import 'dart:async';

import 'package:flutter/material.dart';

import '../models/multiplayer_game_state.dart';
import '../models/player.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../services/game_socket_service.dart';
import '../widgets/domino_boneyard_pile.dart';
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

  bool _isSubmittingMove = false;
  int? _pendingDominoId;

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

  void _applyGameState(MultiplayerGameState state) {
    if (!mounted || state.version < _gameState.version) {
      return;
    }

    setState(() {
      _gameState = state;
      if (_pendingDominoId != null &&
          !_gameState.myHand.any((domino) => domino.id == _pendingDominoId)) {
        _pendingDominoId = null;
        _isSubmittingMove = false;
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

    String? side;

    if (sides.length == 1) {
      side = sides.first;
    } else {
      side = await _chooseSide(sides);
    }

    if (!mounted || side == null) {
      return;
    }

    await _submitMove(domino: domino, side: side);
  }

  Future<String?> _chooseSide(Set<String> sides) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF15283A),
      showDragHandle: true,
      builder: (context) {
        final leftEnd = _gameState.leftEnd;
        final rightEnd = _gameState.rightEnd;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Куда положить костяшку?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                if (sides.contains('left'))
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop('left'),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: Text(
                      'Слева${leftEnd == null ? '' : ' · край $leftEnd'}',
                    ),
                  ),
                if (sides.contains('left') && sides.contains('right'))
                  const SizedBox(height: 10),
                if (sides.contains('right'))
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop('right'),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      'Справа${rightEnd == null ? '' : ' · край $rightEnd'}',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitMove({
    required ServerDomino domino,
    required String side,
  }) async {
    if (_isSubmittingMove) return;

    setState(() {
      _isSubmittingMove = true;
      _pendingDominoId = domino.id;
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
    });

    try {
      final state = await _apiService.drawDomino(
        roomId: _gameState.roomId,
        playerId: _gameState.myPlayerId,
      );

      if (!mounted) return;
      _applyGameState(state);
      setState(() {
        _isSubmittingMove = false;
      });
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
    });

    try {
      final state = await _apiService.passTurn(
        roomId: _gameState.roomId,
        playerId: _gameState.myPlayerId,
      );

      if (!mounted) return;
      _applyGameState(state);
      setState(() {
        _isSubmittingMove = false;
      });
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
    if (_gameState.table.isNotEmpty) {
      return Column(
        children: [
          Expanded(
            child: MultiplayerDominoSnake(
              dominoes: [
                for (final serverDomino in _gameState.table)
                  serverDomino.domino,
              ],
            ),
          ),
          const SizedBox(height: 6),
          _TableStatus(gameState: _gameState),
        ],
      );
    }

    final isMyTurn = _gameState.isMyTurn;
    final openingDomino = _gameState.requiredOpeningDomino;

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
                : 'Нажми подсвеченную костяшку — сервер проверит ход.',
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
                final isRequiredOpening =
                    _gameState.table.isEmpty &&
                    _gameState.isMyTurn &&
                    serverDomino.id == _gameState.openingDominoId;

                return AnimatedOpacity(
                  duration: const Duration(milliseconds: 160),
                  opacity: _gameState.isMyTurn && !isPlayable ? 0.55 : 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: isPlayable || isRequiredOpening
                            ? Colors.greenAccent
                            : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isPlayable
                          ? [
                              BoxShadow(
                                color: Colors.greenAccent.withValues(alpha: 0.24),
                                blurRadius: 12,
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

    if (_gameState.table.isEmpty) {
      return 'Нажми зелёную стартовую костяшку.';
    }

    if (_gameState.hasPlayableDomino) {
      return 'Зелёные костяшки можно сыграть. Нажми на одну из них.';
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
