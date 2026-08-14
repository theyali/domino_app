import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../localization/app_localizations.dart';
import '../models/restaurant.dart';
import '../services/api_service.dart';
import '../widgets/restaurant_tile.dart';
import 'restaurant_room_screen.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  static const ApiService _apiService = ApiService();

  bool showOnlyActive = false;
  bool _isLoading = true;
  String? _errorMessage;
  List<Restaurant> _restaurants = const [];

  @override
  void initState() {
    super.initState();
    _loadRestaurants();
  }

  Future<void> _loadRestaurants() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final restaurants = await _apiService.fetchRestaurants();
      if (!mounted) return;

      setState(() {
        _restaurants = restaurants;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr('django_connection_failed');
      });
    } finally {
      if (mounted) {
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

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('restaurants')),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadRestaurants,
            tooltip: context.tr('refresh'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRestaurants,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  title: Text(context.tr('only_active_restaurants')),
                  subtitle: Text(context.tr('only_available_rooms')),
                  value: showOnlyActive,
                  onChanged: (value) {
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
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null && _restaurants.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _RestaurantsError(
                  message: _errorMessage!,
                  onRetry: _loadRestaurants,
                ),
              )
            else if (visibleRestaurants.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      context.tr('restaurants_empty'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
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
                          _loadRestaurants();
                        }
                      },
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Text(
                  'Backend: ${ApiConfig.baseUrl}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
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
          Icon(
            Icons.cloud_off_rounded,
            size: 58,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            context.tr('backend_unavailable'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(
            ApiConfig.baseUrl,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.tr('retry')),
          ),
        ],
      ),
    );
  }
}
