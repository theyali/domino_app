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
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: _isLoading ? null : () => _loadRestaurants(),
              tooltip: context.tr('refresh'),
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
        body: RefreshIndicator(
          color: AppColors.lime,
          backgroundColor: Colors.white,
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
        color: const Color(0xFFFFC93C),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.black,
          width: 3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 0,
            offset: Offset(5, 6),
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
                  color: const Color(0xFFFF6B6B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black, width: 2.5),
                ),
                child: const Icon(
                  Icons.sports_esports_rounded,
                  color: Colors.black,
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
                    ),
                    _LobbyCounter(
                      icon: Icons.table_restaurant_rounded,
                      value: '$openTables',
                    ),
                    _LobbyCounter(
                      icon: Icons.groups_rounded,
                      value: '$onlinePlayers',
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.black,
                  width: 2.4,
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
                            color: Colors.black,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.tr('only_available_rooms'),
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 170),
                    width: 50,
                    height: 29,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: onlyActive
                          ? const Color(0xFF7CFC00)
                          : const Color(0xFFE8E8E8),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: Colors.black,
                        width: 2,
                      ),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 170),
                      alignment: onlyActive
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 19,
                        height: 19,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black,
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

  const _LobbyCounter({
    required this.icon,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.black),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black,
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
              color: const Color(0xFF62C7F3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 0,
                  offset: Offset(4, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.table_restaurant_rounded,
              size: 43,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
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
              color: const Color(0xFFFF6B6B),
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 0,
                  offset: Offset(4, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('backend_unavailable'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ApiConfig.baseUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7CFC00),
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.black, width: 2.5),
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
