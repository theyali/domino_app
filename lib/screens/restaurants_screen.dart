import 'dart:async';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../localization/app_localizations.dart';
import '../localization/statistics_strings.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/play_palette.dart';
import '../widgets/restaurant_tile.dart';
import 'restaurant_room_screen.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  static const ApiService _apiService = ApiService();
  static const Duration _refreshInterval = Duration(seconds: 4);

  Timer? _refreshTimer;
  bool _isLoading = true;
  bool _isRefreshingSilently = false;
  String? _errorMessage;
  List<Restaurant> _restaurants = const [];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(_loadRestaurants(silent: true));
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRestaurants({bool silent = false}) async {
    if (silent && (_isRefreshingSilently || _isLoading)) return;

    if (silent) {
      _isRefreshingSilently = true;
    } else if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final restaurants = await _apiService.fetchRestaurants();
      if (!mounted) return;

      setState(() {
        _restaurants = restaurants;
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
        _errorMessage = context.tr('django_connection_failed');
      });
    } finally {
      if (silent) {
        _isRefreshingSilently = false;
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openRestaurant(Restaurant restaurant) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RestaurantRoomScreen(
          restaurant: restaurant,
        ),
      ),
    );

    if (mounted) {
      await _loadRestaurants(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleRestaurants = _restaurants
        .where((restaurant) => restaurant.active)
        .toList(growable: false);
    final navigationStrings = StatisticsStrings.of(context);
    final isAz = context.appLanguage.code == 'az';
    final onlinePlayers = visibleRestaurants.fold<int>(
      0,
      (total, restaurant) => total + restaurant.players,
    );
    final openTables = visibleRestaurants.fold<int>(
      0,
      (total, restaurant) => total + restaurant.waitingRooms,
    );
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = screenWidth >= 720 ? 3 : 2;

    return Scaffold(
      backgroundColor: PlayPalette.backgroundTop,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: PlayPalette.pageGradient,
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -130,
              right: -90,
              child: _AmbientGlow(size: 300, color: Color(0x33268CFF)),
            ),
            const Positioned(
              top: 340,
              left: -110,
              child: _AmbientGlow(size: 260, color: Color(0x2243D8FF)),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 7, 12, 6),
                    child: Row(
                      children: [
                        const SizedBox(width: 50, height: 48),
                        Expanded(
                          child: Text(
                            navigationStrings.play,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 25,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                        _HeaderButton(
                          icon: Icons.refresh_rounded,
                          loading: _isLoading,
                          tooltip: context.tr('refresh'),
                          onTap: _isLoading ? null : () => _loadRestaurants(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: PlayPalette.blue,
                      backgroundColor: PlayPalette.white,
                      onRefresh: () => _loadRestaurants(),
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
                              child: _PlayLobbyHeader(
                                restaurantsCount: visibleRestaurants.length,
                                openTables: openTables,
                                onlinePlayers: onlinePlayers,
                                isAz: isAz,
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 11, 16, 9),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isAz ? 'Restoranlar' : 'Рестораны',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.35,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          isAz
                                              ? 'Oynamaq istədiyiniz məkanı seçin'
                                              : 'Выбери место, где хочешь играть',
                                          style: const TextStyle(
                                            color: PlayPalette.muted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0x22268CFF),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0x3343B8FF),
                                      ),
                                    ),
                                    child: Text(
                                      '${visibleRestaurants.length}',
                                      style: const TextStyle(
                                        color: PlayPalette.blueSoft,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (_isLoading && _restaurants.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: PlayPalette.blueBright,
                                ),
                              ),
                            )
                          else if (_errorMessage != null && _restaurants.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _RestaurantsError(
                                message: _errorMessage!,
                                onRetry: () => _loadRestaurants(),
                              ),
                            )
                          else if (visibleRestaurants.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _PlayEmptyState(
                                message: context.tr('restaurants_empty'),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
                              sliver: SliverGrid.builder(
                                itemCount: visibleRestaurants.length,
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  mainAxisExtent: 206,
                                ),
                                itemBuilder: (context, index) {
                                  final restaurant = visibleRestaurants[index];
                                  return RestaurantTile(
                                    restaurant: restaurant,
                                    onTap: () => _openRestaurant(restaurant),
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AmbientGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _AmbientGlow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 90,
              spreadRadius: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool loading;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: PlayPalette.navySoft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0x3343B8FF),
              width: 1.2,
            ),
          ),
          child: loading
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: PlayPalette.blueBright,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 25),
        ),
      ),
    );
  }
}

class _PlayLobbyHeader extends StatelessWidget {
  final int restaurantsCount;
  final int openTables;
  final int onlinePlayers;
  final bool isAz;

  const _PlayLobbyHeader({
    required this.restaurantsCount,
    required this.openTables,
    required this.onlinePlayers,
    required this.isAz,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 15),
      decoration: BoxDecoration(
        gradient: PlayPalette.cardGradient,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0x558FE6FF),
          width: 1.3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44268CFF),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xECFFFFFF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: PlayPalette.blue,
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAz ? 'Oyuna qoşul' : 'Присоединяйся к игре',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isAz
                          ? 'Restoranı seç və masaya keç'
                          : 'Выбери ресторан и переходи к столу',
                      style: const TextStyle(
                        color: Color(0xDDFFFFFF),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _LobbyCounter(
                  icon: Icons.restaurant_rounded,
                  value: '$restaurantsCount',
                  label: isAz ? 'məkan' : 'мест',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LobbyCounter(
                  icon: Icons.table_restaurant_rounded,
                  value: '$openTables',
                  label: isAz ? 'masa' : 'столов',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LobbyCounter(
                  icon: Icons.groups_rounded,
                  value: '$onlinePlayers',
                  label: 'online',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LobbyCounter extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _LobbyCounter({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 47,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: const Color(0xDFFFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15, color: PlayPalette.ink),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  style: const TextStyle(
                    color: PlayPalette.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xAA10182A),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayEmptyState extends StatelessWidget {
  final String message;

  const _PlayEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 70, 30, 130),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              gradient: PlayPalette.cardGradient,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44268CFF),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.table_restaurant_rounded,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RestaurantsError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _RestaurantsError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: PlayPalette.coral,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 37,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('backend_unavailable'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: PlayPalette.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ApiConfig.baseUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 11),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: PlayPalette.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(
              context.tr('retry'),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
