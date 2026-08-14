import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/multiplayer_game_state.dart';
import '../models/player.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../services/game_socket_service.dart';
import '../theme/app_colors.dart';
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
  final ScrollController _handScrollController = ScrollController();

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
    _handScrollController.dispose();
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

  void _scrollHandToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_handScrollController.hasClients) return;

      final position = _handScrollController.position;
      unawaited(
        _handScrollController.animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 330),
          curve: Curves.easeOutCubic,
        ),
      );
    });
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

    _showMessage(context.tr('room_closed_all_left'));
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

    if (newDraw != null && (drawSource == null || drawTarget == null)) {
      _scrollHandToEnd();
    }
  }

  Future<void> _onDominoTap(ServerDomino domino) async {
    if (_isSubmittingMove || !_gameState.isActive) {
      return;
    }

    if (!_gameState.isMyTurn) {
      _showMessage(
        context.tr(
          'current_turn_message',
          arguments: {'player': _gameState.currentPlayer.name},
        ),
      );
      return;
    }

    final sides = _gameState.playableSidesFor(domino);
    if (sides.isEmpty) {
      _showMessage(context.tr('domino_not_playable'));
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
      _showMessage(context.tr('chain_end_unavailable'));
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
      _finishSubmittingWithError(context.tr('move_send_failed'));
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
      _finishSubmittingWithError(context.tr('draw_failed'));
    }
  }

  void _finishBoneyardDrawAnimation() {
    if (!mounted) return;
    setState(() {
      _boneyardDrawFlight = null;
      _hiddenDrawnDominoId = null;
    });
    _scrollHandToEnd();
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
      _finishSubmittingWithError(context.tr('pass_failed'));
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
      _showMessage(context.tr('next_round_failed'));
    }
  }

  Future<void> _requestExitGame() async {
    if (_isLeavingGame || _allowPop) return;

    final activeMatch = _gameState.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(context.tr('exit_game_title')),
          content: Text(
            context.tr(
              activeMatch
                  ? 'exit_active_match_description'
                  : 'exit_table_description',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.tr('stay')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.tr('exit')),
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
      _showMessage(context.tr('exit_game_failed'));
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppColors.background,
          foregroundColor: Colors.white,
          elevation: 0,
          toolbarHeight: 54,
          title: Text(
            widget.restaurant.name,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            onPressed: _isLeavingGame ? null : _requestExitGame,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
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
              if (_socketStatus != SocketConnectionStatus.connected)
                Positioned(
                  top: 10,
                  left: 24,
                  right: 24,
                  child: _ReconnectBanner(status: _socketStatus),
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
      margin: const EdgeInsets.fromLTRB(8, 2, 8, 0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF123B54),
        image: const DecorationImage(
          image: AssetImage('assets/texture/table.jpg'),
          fit: BoxFit.cover,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: AppColors.lime.withValues(alpha: 0.58),
          width: 2.4,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.lime.withValues(alpha: 0.10),
            blurRadius: 18,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.34),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.22),
                      const Color(0xFF07131D).withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.34),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ..._buildOpponentAvatars(),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 110, 10, 86),
              child: _buildTableCenter(),
            ),
          ),
          if (_gameState.boneyardCount > 0)
            Positioned(
              right: 12,
              bottom: 12,
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
                  backgroundColor: AppColors.lime,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.badgeLight,
                  disabledForegroundColor: Colors.white38,
                  elevation: 7,
                  shadowColor: Colors.black54,
                  side: const BorderSide(
                    color: AppColors.ink,
                    width: 2,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                icon: const Icon(Icons.skip_next_rounded, size: 21),
                label: Text(
                  context.tr('pass'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            bottom: 12,
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
      final giftPlacement = relativeSeat == 1
          ? PlayerGiftPlacement.left
          : PlayerGiftPlacement.right;
      final avatar = PlayerAvatar(
        key: _playerAvatarKeyFor(opponent.id),
        player: _toPlayer(opponent, isMe: false),
        dominoCount: opponent.dominoCount,
        isActive: isCurrentTurn,
        turnSecondsLeft: isCurrentTurn ? _turnSecondsLeft : null,
        turnProgress: isCurrentTurn ? _turnProgress : 0,
        isOnline: opponent.isOnline,
        activeGiftImageUrl: opponent.activeGift?.imageUrl,
        activeGiftName: opponent.activeGift?.name,
        giftPlacement: giftPlacement,
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

      return MultiplayerDominoSnake(
        dominoes: _gameState.table,
        selectedDomino: selected,
        playableSides: selectedSides,
        onTargetTap: _playSelectedSide,
        animatedMoveNumber: _animatedMoveNumber,
        animationSourceGlobalCenter: _animationSourceGlobalCenter,
        soundEnabled: _soundEnabled,
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
            Text(
              context.tr('first_move'),
              style: const TextStyle(
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
            Text(
              context.tr('tap_dotted_submit'),
              textAlign: TextAlign.center,
              style: const TextStyle(
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
            color: isMyTurn ? AppColors.lime : Colors.white54,
            size: 30,
          ),
          const SizedBox(height: 10),
          Text(
            isMyTurn
                ? context.tr('your_first_move')
                : context.tr(
                    'first_move_player',
                    arguments: {'player': _gameState.currentPlayer.name},
                  ),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isMyTurn ? AppColors.lime : Colors.white70,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            context.tr(
              openingDomino == null
                  ? 'server_dealt_dominoes'
                  : 'select_green_start',
            ),
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
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 2),
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.panelTop,
            AppColors.panelBottom,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isMyCurrentTurn
              ? AppColors.lime.withValues(alpha: 0.44)
              : Colors.white.withValues(alpha: 0.10),
          width: isMyCurrentTurn ? 1.5 : 1,
        ),
        boxShadow: [
          const BoxShadow(
            color: Colors.black45,
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
          if (isMyCurrentTurn)
            BoxShadow(
              color: AppColors.lime.withValues(alpha: 0.06),
              blurRadius: 12,
            ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 3,
            margin: const EdgeInsets.only(bottom: 1),
            decoration: BoxDecoration(
              color: isMyCurrentTurn
                  ? AppColors.lime.withValues(alpha: 0.62)
                  : Colors.white24,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          PlayerAvatar(
            key: _playerAvatarKeyFor(me.id),
            player: _toPlayer(me, isMe: true),
            dominoCount: _gameState.myHand.length,
            isActive: isMyCurrentTurn,
            turnSecondsLeft: isMyCurrentTurn ? _turnSecondsLeft : null,
            turnProgress: isMyCurrentTurn ? _turnProgress : 0,
            isOnline:
                _socketStatus == SocketConnectionStatus.connected && me.isOnline,
            activeGiftImageUrl: me.activeGift?.imageUrl,
            activeGiftName: me.activeGift?.name,
            giftPlacement: PlayerGiftPlacement.right,
            onTap: () {},
          ),
          const SizedBox(height: 2),
          Container(
            key: _handAreaKey,
            height: 98,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: ListView.separated(
              controller: _handScrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: _gameState.myHand.length,
              separatorBuilder: (context, index) => const SizedBox(width: 5),
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
                      isSelected ? -5 : 0,
                      0,
                    ),
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: isSelected
                          ? AppColors.lime.withValues(alpha: 0.12)
                          : Colors.transparent,
                      border: Border.all(
                        color: isPlayable || isRequiredOpening
                            ? AppColors.lime
                            : Colors.transparent,
                        width: isSelected ? 3 : 2.6,
                      ),
                      boxShadow: isPlayable
                          ? [
                              BoxShadow(
                                color: AppColors.lime.withValues(
                                  alpha: isSelected ? 0.38 : 0.20,
                                ),
                                blurRadius: isSelected ? 14 : 9,
                              ),
                            ]
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        DominoTile(
                          domino: serverDomino.domino,
                          width: 45,
                          height: 78,
                          dotSize: 5.8,
                          onTap: isHiddenByDraw
                              ? null
                              : () => _onDominoTap(serverDomino),
                        ),
                        if (isPending)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.38),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: AppColors.lime,
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
        ],
      ),
    );
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

class _ReconnectBanner extends StatelessWidget {
  final SocketConnectionStatus status;

  const _ReconnectBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (status) {
      SocketConnectionStatus.connecting => (
          Icons.sync_rounded,
          context.tr('connecting_game'),
        ),
      SocketConnectionStatus.reconnecting => (
          Icons.sync_rounded,
          context.tr('reconnecting_game'),
        ),
      SocketConnectionStatus.disconnected => (
          Icons.cloud_off_rounded,
          context.tr('connection_lost'),
        ),
      SocketConnectionStatus.connected => (
          Icons.check_circle_rounded,
          context.tr('connection_restored'),
        ),
    };

    return IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xEE102537),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.orangeAccent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orangeAccent,
              ),
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
    return Tooltip(
      message: context.tr(
        'round_number',
        arguments: {'number': roundNumber},
      ),
      child: Container(
        height: 42,
        padding: const EdgeInsets.fromLTRB(7, 5, 9, 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.panelTop,
              AppColors.panelBottom,
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.lime.withValues(alpha: 0.64),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.lime,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.ink,
                  width: 1.4,
                ),
              ),
              child: const Icon(
                Icons.flag_rounded,
                size: 17,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$roundNumber',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
