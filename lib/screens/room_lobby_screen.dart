import 'dart:async';

import 'package:flutter/material.dart';

import '../models/game_room.dart';
import '../models/multiplayer_game_state.dart';
import '../models/restaurant.dart';
import '../models/room_player.dart';
import '../services/api_service.dart';
import '../services/game_socket_service.dart';
import 'multiplayer_game_screen.dart';

class RoomLobbyScreen extends StatefulWidget {
  final Restaurant restaurant;
  final GameRoom initialRoom;
  final RoomPlayer localPlayer;

  const RoomLobbyScreen({
    super.key,
    required this.restaurant,
    required this.initialRoom,
    required this.localPlayer,
  });

  @override
  State<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends State<RoomLobbyScreen> {
  static const ApiService _apiService = ApiService();

  late final GameSocketService _socketService;
  StreamSubscription<Map<String, dynamic>>? _socketMessageSubscription;
  StreamSubscription<SocketConnectionStatus>? _socketStatusSubscription;

  late GameRoom _room;
  SocketConnectionStatus _socketStatus = SocketConnectionStatus.connecting;

  bool _isRefreshing = false;
  bool _isLeaving = false;
  bool _isStartingGame = false;
  bool _isOpeningGame = false;
  bool _allowPop = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _room = widget.initialRoom;
    _socketService = GameSocketService();

    _socketMessageSubscription = _socketService.messages.listen(
      _handleSocketMessage,
    );
    _socketStatusSubscription = _socketService.statuses.listen(
      _handleSocketStatus,
    );

    unawaited(
      _socketService.connectToRoom(
        roomId: _room.id,
        playerId: widget.localPlayer.id,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_socketMessageSubscription?.cancel());
    unawaited(_socketStatusSubscription?.cancel());
    unawaited(_socketService.dispose());
    super.dispose();
  }

  RoomPlayer get _currentLocalPlayer {
    for (final player in _room.players) {
      if (player.id == widget.localPlayer.id && player.isActive) {
        return player;
      }
    }
    return widget.localPlayer;
  }

  void _handleSocketStatus(SocketConnectionStatus status) {
    if (!mounted) return;

    setState(() {
      _socketStatus = status;
    });
  }

  void _handleSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];

    if (type == 'room_state') {
      final rawRoom = message['room'];
      if (rawRoom is! Map) return;

      final room = GameRoom.fromJson(Map<String, dynamic>.from(rawRoom));
      if (!mounted) return;

      setState(() {
        _room = room;
        _errorMessage = null;
      });
      return;
    }

    if (type == 'game_started') {
      final rawGame = message['game'];
      if (rawGame is! Map) return;

      final gameState = MultiplayerGameState.fromJson(
        Map<String, dynamic>.from(rawGame),
      );
      unawaited(_openGame(gameState));
      return;
    }

    if (type == 'room_deleted') {
      unawaited(_handleRoomDeleted());
    }
  }

  Future<void> _startGame() async {
    if (_isStartingGame || _isOpeningGame) return;

    setState(() {
      _isStartingGame = true;
      _errorMessage = null;
    });

    try {
      final gameState = await _apiService.startGame(
        roomId: _room.id,
        playerId: widget.localPlayer.id,
      );

      if (!mounted) return;
      await _openGame(gameState);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Не удалось запустить игру.';
      });
    } finally {
      if (mounted && !_isOpeningGame) {
        setState(() {
          _isStartingGame = false;
        });
      }
    }
  }

  Future<void> _openGame(MultiplayerGameState gameState) async {
    if (!mounted || _isOpeningGame) return;

    setState(() {
      _isOpeningGame = true;
      _allowPop = true;
    });

    await _socketService.disconnect();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MultiplayerGameScreen(
          restaurant: widget.restaurant,
          initialGameState: gameState,
        ),
      ),
    );
  }

  Future<void> _handleRoomDeleted() async {
    if (!mounted || _isLeaving || _allowPop || _isOpeningGame) return;

    await _socketService.disconnect();
    if (!mounted) return;

    setState(() {
      _allowPop = true;
      _errorMessage = 'Стол закрыт: в комнате больше не осталось игроков.';
    });

    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    Navigator.of(context).pop();
  }

  Future<void> _leaveAndClose() async {
    if (_isLeaving || _allowPop || _isOpeningGame) return;

    setState(() {
      _isLeaving = true;
      _errorMessage = null;
    });

    try {
      await _apiService.leaveRoom(
        roomId: _room.id,
        playerId: widget.localPlayer.id,
      );

      if (!mounted) return;

      await _socketService.disconnect();
      if (!mounted) return;

      setState(() {
        _allowPop = true;
      });
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Не удалось выйти из комнаты.';
      });
    } finally {
      if (mounted && !_allowPop) {
        setState(() {
          _isLeaving = false;
        });
      }
    }
  }

  Future<void> _refreshRoom() async {
    if (_isRefreshing || _isLeaving || _isOpeningGame) return;

    setState(() {
      _isRefreshing = true;
      _errorMessage = null;
    });

    try {
      final room = await _apiService.fetchRoom(_room.id);
      if (!mounted) return;

      setState(() {
        _room = room;
      });

      if (room.status == 'playing') {
        final gameState = await _apiService.fetchGameState(
          roomId: room.id,
          playerId: widget.localPlayer.id,
        );
        if (!mounted) return;
        await _openGame(gameState);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Не удалось обновить комнату.';
      });
    } finally {
      if (mounted && !_isOpeningGame) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localPlayer = _currentLocalPlayer;
    final isLocalOwner = localPlayer.isOwner;
    final allPlayersReady = _room.currentPlayers >= _room.maxPlayers;
    final canStart =
        allPlayersReady &&
        isLocalOwner &&
        _room.status == 'waiting' &&
        !_isStartingGame &&
        !_isOpeningGame;

    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _leaveAndClose();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_room.displayName),
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _refreshRoom,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _LobbyHeader(
                  restaurantName: widget.restaurant.name,
                  room: _room,
                  allPlayersReady: allPlayersReady,
                ),
                const SizedBox(height: 12),
                _RealtimeStatus(status: _socketStatus),
                const SizedBox(height: 24),
                const Text(
                  'Игроки',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                for (var seat = 0; seat < _room.maxPlayers; seat++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _LobbySeat(
                      seatIndex: seat,
                      player: _playerAtSeat(seat),
                      localPlayerId: widget.localPlayer.id,
                    ),
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (isLocalOwner && allPlayersReady) ...[
                  SizedBox(
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: canStart ? _startGame : null,
                      icon: _isStartingGame || _isOpeningGame
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded),
                      label: Text(
                        _isStartingGame || _isOpeningGame
                            ? 'Запускаем игру...'
                            : 'Начать игру',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  allPlayersReady
                      ? isLocalOwner
                          ? 'Все игроки в сборе. Можно запускать серверную раздачу.'
                          : 'Все игроки в сборе. Ожидаем запуск от создателя комнаты.'
                      : 'Ожидаем ещё ${_room.maxPlayers - _room.currentPlayers} игрока(ов).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_isRefreshing) ...[
                  const SizedBox(height: 16),
                  const Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  RoomPlayer? _playerAtSeat(int seatIndex) {
    for (final player in _room.players) {
      if (player.isActive && player.seatIndex == seatIndex) {
        return player;
      }
    }
    return null;
  }
}

class _RealtimeStatus extends StatelessWidget {
  final SocketConnectionStatus status;

  const _RealtimeStatus({required this.status});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (icon, title, subtitle, isLoading) = switch (status) {
      SocketConnectionStatus.connected => (
          Icons.bolt_rounded,
          'Realtime подключён',
          'Игроки и запуск игры приходят автоматически',
          false,
        ),
      SocketConnectionStatus.connecting => (
          Icons.sync_rounded,
          'Подключаем realtime',
          'Устанавливаем WebSocket-соединение',
          true,
        ),
      SocketConnectionStatus.reconnecting => (
          Icons.sync_rounded,
          'Переподключаемся',
          'Соединение восстановится автоматически',
          true,
        ),
      SocketConnectionStatus.disconnected => (
          Icons.cloud_off_rounded,
          'Realtime временно недоступен',
          'Пробуем подключиться снова автоматически',
          true,
        ),
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.check_circle_rounded,
              color: colorScheme.primary,
            ),
        ],
      ),
    );
  }
}

class _LobbyHeader extends StatelessWidget {
  final String restaurantName;
  final GameRoom room;
  final bool allPlayersReady;

  const _LobbyHeader({
    required this.restaurantName,
    required this.room,
    required this.allPlayersReady,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            restaurantName,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            room.displayName,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                allPlayersReady
                    ? Icons.check_circle_rounded
                    : Icons.hourglass_top_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  allPlayersReady
                      ? 'Все игроки в сборе'
                      : 'Ожидание игроков',
                  style: TextStyle(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${room.currentPlayers} / ${room.maxPlayers}',
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LobbySeat extends StatelessWidget {
  final int seatIndex;
  final RoomPlayer? player;
  final int localPlayerId;

  const _LobbySeat({
    required this.seatIndex,
    required this.player,
    required this.localPlayerId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMe = player?.id == localPlayerId;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.55)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe
              ? theme.colorScheme.primary.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: player == null
                ? theme.colorScheme.surfaceContainerHighest
                : theme.colorScheme.primary,
            foregroundColor: player == null
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onPrimary,
            child: player == null
                ? const Icon(Icons.person_add_alt_1_rounded)
                : Text(
                    player!.name.isEmpty
                        ? '?'
                        : player!.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player?.name ?? 'Свободное место',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  player == null
                      ? 'Ожидаем игрока'
                      : [
                          if (player!.isOwner) 'Создатель комнаты',
                          if (isMe) 'Это ты',
                          if (!player!.isOwner && !isMe)
                            'Игрок ${seatIndex + 1}',
                        ].join(' • '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (player != null)
            Icon(
              Icons.check_circle_rounded,
              color: theme.colorScheme.primary,
            ),
        ],
      ),
    );
  }
}
