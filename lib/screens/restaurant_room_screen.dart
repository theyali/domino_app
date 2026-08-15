import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/game_room.dart';
import '../models/restaurant.dart';
import '../models/room_player.dart';
import '../services/api_service.dart';
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

  Widget _withEasyDismiss({
    required BuildContext sheetContext,
    required Widget child,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: 12,
          right: 14,
          child: _SheetCloseButton(
            onTap: () => Navigator.of(sheetContext).pop(),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateRoomSheet() async {
    if (_isSubmitting) return;

    final request = await showModalBottomSheet<CreateRoomRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      builder: (sheetContext) => _withEasyDismiss(
        sheetContext: sheetContext,
        child: const CreateRoomBottomSheet(),
      ),
    );

    if (request == null || !mounted) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final room = await _apiService.createRoom(
        restaurantId: widget.restaurant.id,
        maxPlayers: request.maxPlayers,
        gameMode: request.gameMode,
        targetScore: request.targetScore,
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
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      builder: (sheetContext) => _withEasyDismiss(
        sheetContext: sheetContext,
        child: JoinRoomBottomSheet(room: room),
      ),
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
    final roomsCount = _rooms.length;
    final waitingPlayers = _rooms.fold<int>(
      0,
      (total, room) => total + room.currentPlayers,
    );

    return CartoonPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 66,
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _TopActionButton(
              icon: Icons.arrow_back_ios_new_rounded,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onTap: () => Navigator.maybePop(context),
            ),
          ),
          title: Text(
            widget.restaurant.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
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
            _TopActionButton(
              icon: Icons.card_giftcard_rounded,
              tooltip: context.tr('restaurant_gifts'),
              onTap: _showGiftShop,
              color: _RestaurantPalette.mint,
            ),
            const SizedBox(width: 8),
            _TopActionButton(
              icon: Icons.refresh_rounded,
              tooltip: context.tr('refresh'),
              onTap: _isLoading ? null : _loadRooms,
              color: _RestaurantPalette.skyBlue,
            ),
            const SizedBox(width: 12),
          ],
        ),
        floatingActionButton: _CreateTableFloatingButton(
          isBusy: _isSubmitting,
          label: context.tr('create_table'),
          onTap: _isSubmitting ? null : _showCreateRoomSheet,
        ),
        body: RefreshIndicator(
          color: _RestaurantPalette.ink,
          backgroundColor: _RestaurantPalette.cream,
          onRefresh: _loadRooms,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
                  child: _RestaurantRoomHeader(
                    restaurant: widget.restaurant,
                    roomsCount: roomsCount,
                    waitingPlayers: waitingPlayers,
                    onOpenGiftShop: _showGiftShop,
                  ),
                ),
              ),
              if (_isLoading && _rooms.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _RestaurantPalette.ink,
                    ),
                  ),
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
                    color: _RestaurantPalette.coral,
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
                    color: _RestaurantPalette.skyBlue,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
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

class _SheetCloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SheetCloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _RestaurantPalette.coral,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _RestaurantPalette.ink, width: 2.8),
          boxShadow: const [
            BoxShadow(
              color: _RestaurantPalette.ink,
              blurRadius: 0,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.close_rounded,
          color: _RestaurantPalette.ink,
          size: 25,
        ),
      ),
    );
  }
}

class _CreateTableFloatingButton extends StatelessWidget {
  final bool isBusy;
  final String label;
  final VoidCallback? onTap;

  const _CreateTableFloatingButton({
    required this.isBusy,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: _RestaurantPalette.lime,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: _RestaurantPalette.ink,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: _RestaurantPalette.ink,
                blurRadius: 0,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isBusy)
                const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: _RestaurantPalette.ink,
                  ),
                )
              else
                const Icon(
                  Icons.add_rounded,
                  color: _RestaurantPalette.ink,
                  size: 25,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: _RestaurantPalette.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _RestaurantPalette.yellow,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _RestaurantPalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _RestaurantPalette.ink,
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
              _RestaurantHeaderLogo(restaurant: restaurant),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  restaurant.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _RestaurantPalette.ink,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 9,
            runSpacing: 9,
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
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              onOpenGiftShop();
            },
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: _RestaurantPalette.lime,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: _RestaurantPalette.ink,
                  width: 3,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: _RestaurantPalette.ink,
                    blurRadius: 0,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.card_giftcard_rounded,
                    color: _RestaurantPalette.ink,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.tr('restaurant_gifts'),
                    style: const TextStyle(
                      color: _RestaurantPalette.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
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
      width: 72,
      height: 72,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _RestaurantPalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _RestaurantPalette.ink,
            blurRadius: 0,
            offset: Offset(3, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
      color: _RestaurantPalette.cream,
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_rounded,
        size: 34,
        color: _RestaurantPalette.ink,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _RestaurantPalette.ink, width: 2.3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: _RestaurantPalette.ink),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: _RestaurantPalette.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color color;

  const _TopActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = _RestaurantPalette.cream,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.45 : 1,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _RestaurantPalette.ink, width: 2.6),
              boxShadow: const [
                BoxShadow(
                  color: _RestaurantPalette.ink,
                  blurRadius: 0,
                  offset: Offset(2, 3),
                ),
              ],
            ),
            child: Icon(icon, color: _RestaurantPalette.ink, size: 21),
          ),
        ),
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
  final Color color;

  const _RoomListMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 125),
      child: Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _RestaurantPalette.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: _RestaurantPalette.ink,
                blurRadius: 0,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _RestaurantPalette.ink,
                    width: 3,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: _RestaurantPalette.ink,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _RestaurantPalette.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _RestaurantPalette.inkSoft,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  onPressed();
                },
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _RestaurantPalette.lime,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: _RestaurantPalette.ink,
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: _RestaurantPalette.ink,
                        blurRadius: 0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    buttonText,
                    style: const TextStyle(
                      color: _RestaurantPalette.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
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

class _RestaurantPalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF4A4037);
  static const Color cream = Color(0xFFFFF5D9);
  static const Color yellow = Color(0xFFFFD65C);
  static const Color skyBlue = Color(0xFF79CDF1);
  static const Color mint = Color(0xFF8CDD79);
  static const Color coral = Color(0xFFFF8A79);
  static const Color lime = Color(0xFF7CFC00);
}
