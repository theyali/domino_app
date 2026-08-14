import 'package:flutter/material.dart';

import '../models/game_room.dart';
import '../models/restaurant.dart';
import '../models/room_player.dart';
import '../services/api_service.dart';
import '../widgets/create_room_bottom_sheet.dart';
import '../widgets/game_room_card.dart';
import '../widgets/join_room_bottom_sheet.dart';
import 'room_lobby_screen.dart';

class RestaurantRoomScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantRoomScreen({super.key, required this.restaurant});

  @override
  State<RestaurantRoomScreen> createState() => _RestaurantRoomScreenState();
}

class _RestaurantRoomScreenState extends State<RestaurantRoomScreen> {
  static const ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<GameRoom> _rooms = const [];

  @override
  void initState() {
    super.initState();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rooms = await _apiService.fetchRooms(widget.restaurant.id);
      if (!mounted) return;

      setState(() {
        _rooms = rooms;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Не удалось загрузить комнаты.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showCreateRoomSheet() async {
    if (_isSubmitting) return;

    final request = await showModalBottomSheet<CreateRoomRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) => const CreateRoomBottomSheet(),
    );

    if (request == null || !mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final room = await _apiService.createRoom(
        restaurantId: widget.restaurant.id,
        maxPlayers: request.maxPlayers,
        password: request.password,
        name: request.roomName,
      );

      final owner = _findOwner(room);
      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoomLobbyScreen(
            restaurant: widget.restaurant,
            initialRoom: room,
            localPlayer: owner,
          ),
        ),
      );

      if (mounted) {
        await _loadRooms();
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
    } catch (_) {
      if (!mounted) return;
      _showError('Не удалось создать комнату.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _showJoinRoomSheet(GameRoom room) async {
    if (_isSubmitting || room.isFull) return;

    final request = await showModalBottomSheet<JoinRoomRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (context) => JoinRoomBottomSheet(room: room),
    );

    if (request == null || !mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final result = await _apiService.joinRoom(
        roomId: room.id,
        password: request.password,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RoomLobbyScreen(
            restaurant: widget.restaurant,
            initialRoom: result.room,
            localPlayer: result.player,
          ),
        ),
      );

      if (mounted) {
        await _loadRooms();
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      _showError(error.message);
      await _loadRooms();
    } catch (_) {
      if (!mounted) return;
      _showError('Не удалось войти в комнату.');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  RoomPlayer _findOwner(GameRoom room) {
    for (final player in room.players) {
      if (player.isOwner) {
        return player;
      }
    }

    throw const ApiException('Сервер не вернул создателя комнаты.');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurant.name),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadRooms,
            tooltip: 'Обновить',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSubmitting ? null : _showCreateRoomSheet,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_rounded),
        label: const Text('Создать стол'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadRooms,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: _RestaurantRoomHeader(
                  restaurant: widget.restaurant,
                  roomsCount: _rooms.length,
                  waitingPlayers: _rooms.fold<int>(
                    0,
                    (total, room) => total + room.currentPlayers,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Открытые столы',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (_rooms.isNotEmpty)
                      Text(
                        '${_rooms.length}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            if (_isLoading && _rooms.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null && _rooms.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _RoomListMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Не удалось загрузить комнаты',
                  subtitle: _errorMessage!,
                  buttonText: 'Повторить',
                  onPressed: _loadRooms,
                ),
              )
            else if (_rooms.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _RoomListMessage(
                  icon: Icons.table_restaurant_outlined,
                  title: 'Пока нет открытых столов',
                  subtitle: 'Создай первый стол на 2, 3 или 4 игроков.',
                  buttonText: 'Создать стол',
                  onPressed: _showCreateRoomSheet,
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                sliver: SliverList.builder(
                  itemCount: _rooms.length,
                  itemBuilder: (context, index) {
                    final room = _rooms[index];
                    return GameRoomCard(
                      room: room,
                      onTap: () => _showJoinRoomSheet(room),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantRoomHeader extends StatelessWidget {
  final Restaurant restaurant;
  final int roomsCount;
  final int waitingPlayers;

  const _RestaurantRoomHeader({
    required this.restaurant,
    required this.roomsCount,
    required this.waitingPlayers,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.restaurant_rounded,
            size: 34,
            color: colorScheme.onPrimaryContainer,
          ),
          const SizedBox(height: 12),
          Text(
            restaurant.name,
            style: TextStyle(
              color: colorScheme.onPrimaryContainer,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(
                icon: Icons.table_restaurant,
                label: '$roomsCount столов',
              ),
              _StatChip(
                icon: Icons.groups_rounded,
                label: '$waitingPlayers игроков',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RoomListMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final Future<void> Function() onPressed;

  const _RoomListMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 60,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: onPressed, child: Text(buttonText)),
        ],
      ),
    );
  }
}
