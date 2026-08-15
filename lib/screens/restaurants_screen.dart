import 'dart:async';

import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../localization/app_localizations.dart';
import '../localization/statistics_strings.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/cartoon_page_background.dart';
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
  bool showOnlyActive = false;
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

  @override
  Widget build(BuildContext context) {
    final visibleRestaurants = showOnlyActive
        ? _restaurants.where((restaurant) => restaurant.active).toList()
        : _restaurants;
    final navigationStrings = StatisticsStrings.of(context);
    final onlinePlayers = _restaurants.fold<int>(
      0,
      (total, restaurant) => total + restaurant.players,
    );
    final openTables = _restaurants.fold<int>(
      0,
      (total, restaurant) => total + restaurant.waitingRooms,
    );

    return CartoonPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            navigationStrings.play,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : () => _loadRestaurants(),
              tooltip: context.tr('refresh'),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.lime,
          backgroundColor: AppColors.surfaceRaised,
          onRefresh: () => _loadRestaurants(),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                  child: _PlayLobbyHeader(
                    restaurantsCount: _restaurants.length,
                    openTables: openTables,
                    onlinePlayers: onlinePlayers,
                    onlyActive: showOnlyActive,
                    onFilterChanged: (value) {
                      setState(() {
                        showOnlyActive = value;
                      });
                    },
                  ),
                ),
              ),
              if (_isLoading && _restaurants.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.lime),
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
                  padding: const EdgeInsets.fromLTRB(0, 5, 0, 28),
                  sliver: SliverList.builder(
                    itemCount: visibleRestaurants.length,
                    itemBuilder: (context, index) {
                      final restaurant = visibleRestaurants[index];

                      return RestaurantTile(
                        restaurant: restaurant,
                        onTap: () async {
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
                        },
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

class _PlayLobbyHeader extends StatelessWidget {
  final int restaurantsCount;
  final int openTables;
  final int onlinePlayers;
  final bool onlyActive;
  final ValueChanged<bool> onFilterChanged;

  const _PlayLobbyHeader({
    required this.restaurantsCount,
    required this.openTables,
    required this.onlinePlayers,
    required this.onlyActive,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 14, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3528), Color(0xFF101D18)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.brass.withValues(alpha: 0.46),
          width: 1.35,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.brassLight, AppColors.brassDark],
                  ),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: AppColors.ink,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _LobbyCounter(
                      icon: Icons.restaurant_rounded,
                      value: '$restaurantsCount',
                      color: AppColors.brassLight,
                    ),
                    _LobbyCounter(
                      icon: Icons.table_restaurant_rounded,
                      value: '$openTables',
                      color: AppColors.brass,
                    ),
                    _LobbyCounter(
                      icon: Icons.groups_rounded,
                      value: '$onlinePlayers',
                      color: AppColors.lime,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          GestureDetector(
            onTap: () => onFilterChanged(!onlyActive),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.19),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: onlyActive
                      ? AppColors.lime.withValues(alpha: 0.42)
                      : AppColors.brass.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr('only_active_restaurants'),
                          style: const TextStyle(
                            color: AppColors.cream,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('only_available_rooms'),
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    width: 48,
                    height: 28,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: onlyActive
                          ? AppColors.lime
                          : const Color(0xFF293229),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: onlyActive
                            ? AppColors.limeDark
                            : AppColors.brass.withValues(alpha: 0.34),
                      ),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 170),
                      alignment: onlyActive
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: onlyActive ? AppColors.ink : Colors.white54,
                        ),
                      ),
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

class _LobbyCounter extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _LobbyCounter({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
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
            width: 92,
            height: 72,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.rackWoodLight, AppColors.rackWoodDark],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.brass, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 12,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: const Icon(
              Icons.table_restaurant_rounded,
              size: 43,
              color: AppColors.brassLight,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 19,
              fontWeight: FontWeight.w900,
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
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.surfaceRaised,
              border: Border.all(color: AppColors.brass, width: 2),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: Color(0xFFFF655B),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('backend_unavailable'),
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white60),
          ),
          const SizedBox(height: 6),
          Text(
            ApiConfig.baseUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.lime,
              foregroundColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
