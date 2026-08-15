import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/game_room.dart';
import '../models/multiplayer_game_state.dart';
import '../models/restaurant.dart';
import '../models/room_player.dart';
import '../services/api_service.dart';
import '../services/game_socket_service.dart';
import '../widgets/invite_players_sheet.dart';
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
        _errorMessage = context.tr('game_start_failed');
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
      _errorMessage = context.tr('room_closed');
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
        _errorMessage = context.tr('leave_room_failed');
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
        _errorMessage = context.tr('room_refresh_failed');
      });
    } finally {
      if (mounted && !_isOpeningGame) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Future<void> _showInvitePlayers() async {
    if (_room.status != 'waiting' || _room.isFull) return;
    final sent = await InvitePlayersSheet.show(context, roomId: _room.id);
    if (!mounted || sent == null) return;

    final isAz = context.appLanguage.code == 'az';
    final message = sent > 0
        ? (isAz
            ? '$sent oyunçuya dəvət göndərildi.'
            : 'Приглашение отправлено: $sent игрок(а).')
        : (isAz
            ? 'Dəvət göndərilmədi: seçilən oyunçular artıq onlayn deyil.'
            : 'Никого не удалось пригласить: выбранные игроки уже не онлайн.');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final localPlayer = _currentLocalPlayer;
    final isLocalOwner = localPlayer.isOwner;
    final activePlayers = _room.players
        .where((player) => player.isActive)
        .toList(growable: false);
    final allPlayersReady = activePlayers.length >= _room.maxPlayers;
    final localRealtimeConnected =
        _socketStatus == SocketConnectionStatus.connected;
    final allPlayersOnline = allPlayersReady &&
        activePlayers.every(
          (player) => player.id == widget.localPlayer.id
              ? player.isOnline && localRealtimeConnected
              : player.isOnline,
        );
    final canStart = allPlayersReady &&
        allPlayersOnline &&
        isLocalOwner &&
        _room.status == 'waiting' &&
        !_isStartingGame &&
        !_isOpeningGame;

    final waitingMessage = allPlayersReady
        ? !allPlayersOnline
            ? context.tr('waiting_players')
            : isLocalOwner
                ? context.tr('owner_can_start')
                : context.tr('waiting_owner_start')
        : context.tr(
            'waiting_more_players',
            arguments: {
              'count': _room.maxPlayers - _room.currentPlayers,
            },
          );

    return PopScope<Object?>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _leaveAndClose();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 68,
          leadingWidth: 64,
          centerTitle: true,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _LobbyTopButton(
              icon: _isLeaving
                  ? Icons.hourglass_top_rounded
                  : Icons.arrow_back_ios_new_rounded,
              onTap: _isLeaving ? null : _leaveAndClose,
            ),
          ),
          title: Text(
            _room.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  offset: Offset(2, 3),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          actions: [
            _LobbyTopButton(
              icon: Icons.refresh_rounded,
              color: _LobbyPalette.skyBlue,
              onTap: _isRefreshing ? null : _refreshRoom,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: _LobbyPalette.ink,
            backgroundColor: _LobbyPalette.cream,
            onRefresh: _refreshRoom,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 34),
              children: [
                _LobbyHeader(
                  restaurantName: widget.restaurant.name,
                  room: _room,
                ),
                const SizedBox(height: 24),
                _LobbySectionTitle(
                  title: context.tr('players'),
                  count: '${_room.currentPlayers}/${_room.maxPlayers}',
                ),
                if (!allPlayersReady && _room.status == 'waiting') ...[
                  const SizedBox(height: 12),
                  _InvitePlayersButton(
                    label: context.appLanguage.code == 'az'
                        ? 'Onlayn oyunçuları dəvət et'
                        : 'Пригласить игроков онлайн',
                    onTap: _showInvitePlayers,
                  ),
                ],
                const SizedBox(height: 14),
                for (var seat = 0; seat < _room.maxPlayers; seat++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _LobbySeat(
                      seatIndex: seat,
                      player: _playerAtSeat(seat),
                      localPlayerId: widget.localPlayer.id,
                    ),
                  ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 2),
                  _LobbyErrorMessage(message: _errorMessage!),
                  const SizedBox(height: 18),
                ],
                if (isLocalOwner && allPlayersReady) ...[
                  _StartGameButton(
                    enabled: canStart,
                    isBusy: _isStartingGame || _isOpeningGame,
                    label: context.tr(
                      _isStartingGame || _isOpeningGame
                          ? 'starting_game'
                          : 'start_game',
                    ),
                    onTap: _startGame,
                  ),
                  const SizedBox(height: 16),
                ],
                _WaitingMessage(
                  message: waitingMessage,
                  allPlayersReady: allPlayersReady,
                  canStartNow: allPlayersOnline,
                ),
                if (_isRefreshing) ...[
                  const SizedBox(height: 18),
                  const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _LobbyPalette.ink,
                      ),
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

class _LobbyTopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _LobbyTopButton({
    required this.icon,
    required this.onTap,
    this.color = _LobbyPalette.cream,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.55 : 1,
        child: Container(
          width: 43,
          height: 43,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _LobbyPalette.ink, width: 2.7),
            boxShadow: const [
              BoxShadow(
                color: _LobbyPalette.ink,
                blurRadius: 0,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: Icon(icon, color: _LobbyPalette.ink, size: 21),
        ),
      ),
    );
  }
}

class _LobbyHeader extends StatelessWidget {
  final String restaurantName;
  final GameRoom room;

  const _LobbyHeader({
    required this.restaurantName,
    required this.room,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _LobbyPalette.yellow,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: _LobbyPalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _LobbyPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _LobbyPalette.inkSoft,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (room.isLocked)
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _LobbyPalette.coral,
                    shape: BoxShape.circle,
                    border: Border.all(color: _LobbyPalette.ink, width: 2.2),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: _LobbyPalette.ink,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            room.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _LobbyPalette.ink,
              fontSize: 31,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _LobbyPalette.paper,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: _LobbyPalette.ink, width: 2.3),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.hourglass_top_rounded,
                        color: _LobbyPalette.ink,
                        size: 19,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          context.tr('waiting_players'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _LobbyPalette.ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _LobbyPalette.lime,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _LobbyPalette.ink, width: 2.3),
                ),
                child: Text(
                  '${room.currentPlayers} / ${room.maxPlayers}',
                  style: const TextStyle(
                    color: _LobbyPalette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LobbySectionTitle extends StatelessWidget {
  final String title;
  final String count;

  const _LobbySectionTitle({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: _LobbyPalette.cream,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _LobbyPalette.ink, width: 2.6),
            boxShadow: const [
              BoxShadow(
                color: _LobbyPalette.ink,
                blurRadius: 0,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.groups_rounded,
                color: _LobbyPalette.ink,
                size: 20,
              ),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: _LobbyPalette.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: _LobbyPalette.skyBlue,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: _LobbyPalette.ink, width: 2.4),
          ),
          child: Text(
            count,
            style: const TextStyle(
              color: _LobbyPalette.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _InvitePlayersButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _InvitePlayersButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: _LobbyPalette.lavender,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _LobbyPalette.ink, width: 2.8),
          boxShadow: const [
            BoxShadow(
              color: _LobbyPalette.ink,
              blurRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.person_add_alt_1_rounded,
              color: _LobbyPalette.ink,
              size: 23,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _LobbyPalette.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
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

  Color get _seatColor {
    if (player == null) return _LobbyPalette.paper;
    if (player!.id == localPlayerId) return _LobbyPalette.lime;

    const colors = [
      _LobbyPalette.skyBlue,
      _LobbyPalette.yellow,
      _LobbyPalette.mint,
      _LobbyPalette.lavender,
    ];
    return colors[seatIndex % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isMe = player?.id == localPlayerId;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _seatColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _LobbyPalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _LobbyPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _LobbyAvatar(player: player),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player?.name ?? context.tr('empty_seat'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _LobbyPalette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player == null
                      ? context.tr('waiting_players')
                      : [
                          if (player!.isOwner) context.tr('owner'),
                          if (isMe) context.tr('you'),
                          if (!player!.isOwner && !isMe) '#${seatIndex + 1}',
                        ].join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _LobbyPalette.inkSoft,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (player == null)
            const Icon(
              Icons.add_circle_outline_rounded,
              color: _LobbyPalette.ink,
              size: 26,
            ),
        ],
      ),
    );
  }
}

class _LobbyAvatar extends StatelessWidget {
  final RoomPlayer? player;

  const _LobbyAvatar({required this.player});

  @override
  Widget build(BuildContext context) {
    final current = player;

    if (current == null) {
      return Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: _LobbyPalette.cream,
          shape: BoxShape.circle,
          border: Border.all(color: _LobbyPalette.ink, width: 2.8),
        ),
        child: const Icon(
          Icons.person_add_alt_1_rounded,
          color: _LobbyPalette.ink,
          size: 26,
        ),
      );
    }

    final letter = current.name.isEmpty
        ? '?'
        : current.name.substring(0, 1).toUpperCase();
    final avatarUrl = current.avatarUrl;

    return Container(
      width: 54,
      height: 54,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _LobbyPalette.paper,
        border: Border.all(color: _LobbyPalette.ink, width: 2.8),
      ),
      child: ClipOval(
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) =>
                    _LobbyAvatarLetter(letter: letter),
              )
            : _LobbyAvatarLetter(letter: letter),
      ),
    );
  }
}

class _LobbyAvatarLetter extends StatelessWidget {
  final String letter;

  const _LobbyAvatarLetter({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _LobbyPalette.skyBlue,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: _LobbyPalette.ink,
          fontSize: 19,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LobbyErrorMessage extends StatelessWidget {
  final String message;

  const _LobbyErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _LobbyPalette.coral,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _LobbyPalette.ink, width: 2.8),
        boxShadow: const [
          BoxShadow(
            color: _LobbyPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: _LobbyPalette.ink,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _LobbyPalette.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartGameButton extends StatelessWidget {
  final bool enabled;
  final bool isBusy;
  final String label;
  final VoidCallback onTap;

  const _StartGameButton({
    required this.enabled,
    required this.isBusy,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled || isBusy ? 1 : 0.55,
        child: Container(
          width: double.infinity,
          height: 62,
          decoration: BoxDecoration(
            color: _LobbyPalette.lime,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _LobbyPalette.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: _LobbyPalette.ink,
                blurRadius: 0,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isBusy)
                const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.7,
                    color: _LobbyPalette.ink,
                  ),
                )
              else
                const Icon(
                  Icons.play_arrow_rounded,
                  color: _LobbyPalette.ink,
                  size: 28,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _LobbyPalette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingMessage extends StatelessWidget {
  final String message;
  final bool allPlayersReady;
  final bool canStartNow;

  const _WaitingMessage({
    required this.message,
    required this.allPlayersReady,
    required this.canStartNow,
  });

  @override
  Widget build(BuildContext context) {
    final color = !allPlayersReady
        ? _LobbyPalette.cream
        : canStartNow
            ? _LobbyPalette.mint
            : _LobbyPalette.yellow;
    final icon = !allPlayersReady
        ? Icons.hourglass_bottom_rounded
        : canStartNow
            ? Icons.check_circle_rounded
            : Icons.hourglass_top_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _LobbyPalette.ink, width: 2.7),
        boxShadow: const [
          BoxShadow(
            color: _LobbyPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _LobbyPalette.ink, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _LobbyPalette.inkSoft,
                fontSize: 13,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LobbyPalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF574C42);
  static const Color cream = Color(0xFFFFE8B6);
  static const Color paper = Color(0xFFFFF8E8);
  static const Color lime = Color(0xFF7CFC00);
  static const Color yellow = Color(0xFFFFD65C);
  static const Color skyBlue = Color(0xFF79CDF1);
  static const Color mint = Color(0xFF8CDD79);
  static const Color coral = Color(0xFFFF8A79);
  static const Color lavender = Color(0xFFC7A7FF);
}
