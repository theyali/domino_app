import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/game_room.dart';
import '../models/restaurant.dart';
import '../models/room_player.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/cartoon_page_background.dart';
import '../widgets/create_room_bottom_sheet.dart';
import '../widgets/game_room_card.dart';
import '../widgets/join_room_bottom_sheet.dart';
import '../widgets/restaurant_gift_shop_sheet.dart';
import 'room_lobby_screen.dart';

class RestaurantRoomScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantRoomScreen({super.key, required this.restaurant});

  @override
  State<RestaurantRoomScreen> createState() => _RestaurantRoomScreenState();
}

class _RestaurantRoomScreenState extends State<RestaurantRoomScreen> {
  static const ApiService _apiService = ApiService();
  static const Duration _autoRefreshInterval = Duration(seconds: 2);

  Timer? _autoRefreshTimer;
  bool _isLoading = true;
  bool _isSilentRefreshing = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  List<GameRoom> _rooms = const [];

  @override
  void initState() {
    super.initState();
    _loadRooms();
    _autoRefreshTimer = Timer.periodic(_autoRefreshInterval, (_) {
      unawaited(_loadRooms(silent: true));
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRooms({bool silent = false}) async {
    if (silent && (_isSilentRefreshing || _isLoading || _isSubmitting)) {
      return;
    }

    if (silent) {
      _isSilentRefreshing = true;
    } else if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final rooms = await _apiService.fetchRooms(widget.restaurant.id);
      if (!mounted) return;

      setState(() {
        _rooms = rooms;
        _errorMessage = null;
      });
    } on ApiException catch (error) {
      if (!mounted || silent) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted || silent) return;
      setState(() {
        _errorMessage = context.tr('rooms_load_failed');
      });
    } finally {
      if (silent) {
        _isSilentRefreshing = false;
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showGiftShop() async {
    await RestaurantGiftShopSheet.show(
      context,
      restaurantId: widget.restaurant.id,
      restaurantName: widget.restaurant.name,
    );
  }

  Widget _buildLobbyRoute({
    required GameRoom room,
    required RoomPlayer localPlayer,
  }) {
    return CartoonPageBackground(
      child: Theme(
        data: Theme.of(context).copyWith(
          scaffoldBackgroundColor: Colors.transparent,
          appBarTheme: Theme.of(context).appBarTheme.copyWith(
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
        ),
        child: RoomLobbyScreen(
          restaurant: widget.restaurant,
          initialRoom: room,
          localPlayer: localPlayer,
        ),
      ),
    );
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
          builder: (context) => _buildLobbyRoute(
            room: room,
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
      _showError(context.tr('create_room_failed'));
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
          builder: (context) => _buildLobbyRoute(
            room: result.room,
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
      _showError(context.tr('join_room_failed'));
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

    throw ApiException(context.tr('room_owner_missing'));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CartoonPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: Text(widget.restaurant.name),
          actions: [
            IconButton(
              onPressed: _showGiftShop,
              tooltip: context.tr('restaurant_gifts'),
              icon: const Icon(Icons.card_giftcard_rounded),
            ),
            IconButton(
              onPressed: _isLoading ? null : _loadRooms,
              tooltip: context.tr('refresh'),
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
          label: Text(context.tr('create_table')),
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
                    onOpenGiftShop: _showGiftShop,
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          context.tr('open_tables'),
                          style: const TextStyle(
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
                    title: context.tr('rooms_load_failed_title'),
                    subtitle: _errorMessage!,
                    buttonText: context.tr('retry'),
                    onPressed: () => _loadRooms(),
                  ),
                )
              else if (_rooms.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _RoomListMessage(
                    icon: Icons.table_restaurant_outlined,
                    title: context.tr('no_open_tables'),
                    subtitle: context.tr('create_first_table'),
                    buttonText: context.tr('create_table'),
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
      ),
    );
  }
}

class _RestaurantRoomHeader extends StatelessWidget {
  final Restaurant restaurant;
  final int roomsCount;
  final int waitingPlayers;
  final Future<void> Function() onOpenGiftShop;

  const _RestaurantRoomHeader({
    required this.restaurant,
    required this.roomsCount,
    required this.waitingPlayers,
    required this.onOpenGiftShop,
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
          _RestaurantHeaderLogo(restaurant: restaurant),
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
                label: context.tr(
                  'tables_count',
                  arguments: {'count': roomsCount},
                ),
              ),
              _StatChip(
                icon: Icons.groups_rounded,
                label: context.tr(
                  'players_count',
                  arguments: {'count': waitingPlayers},
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: onOpenGiftShop,
              icon: const Icon(Icons.card_giftcard_rounded),
              label: Text(
                context.tr('restaurant_gifts'),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantHeaderLogo extends StatelessWidget {
  final Restaurant restaurant;

  const _RestaurantHeaderLogo({required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final imageUrl = restaurant.imageUrl;
    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AppColors.brass,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrl?.isNotEmpty == true
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _RestaurantHeaderFallback(),
              )
            : const _RestaurantHeaderFallback(),
      ),
    );
  }
}

class _RestaurantHeaderFallback extends StatelessWidget {
  const _RestaurantHeaderFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.badge,
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_rounded,
        size: 30,
        color: AppColors.cream,
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
