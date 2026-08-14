import 'package:shared_preferences/shared_preferences.dart';

import '../models/multiplayer_game_state.dart';
import '../models/restaurant.dart';

class SavedActiveGameSession {
  final int roomId;
  final int playerId;
  final int restaurantId;
  final String restaurantName;

  const SavedActiveGameSession({
    required this.roomId,
    required this.playerId,
    required this.restaurantId,
    required this.restaurantName,
  });

  Restaurant get restaurant => Restaurant(
        id: restaurantId,
        name: restaurantName,
        players: 0,
        active: true,
      );
}

class ActiveGameSessionStore {
  static const String _roomIdKey = 'active_game.room_id';
  static const String _playerIdKey = 'active_game.player_id';
  static const String _restaurantIdKey = 'active_game.restaurant_id';
  static const String _restaurantNameKey = 'active_game.restaurant_name';

  final SharedPreferencesAsync _preferences;

  ActiveGameSessionStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  Future<void> save({
    required Restaurant restaurant,
    required MultiplayerGameState gameState,
  }) async {
    await _preferences.setInt(_roomIdKey, gameState.roomId);
    await _preferences.setInt(_playerIdKey, gameState.myPlayerId);
    await _preferences.setInt(_restaurantIdKey, restaurant.id);
    await _preferences.setString(_restaurantNameKey, restaurant.name);
  }

  Future<SavedActiveGameSession?> load() async {
    final roomId = await _preferences.getInt(_roomIdKey);
    final playerId = await _preferences.getInt(_playerIdKey);
    final restaurantId = await _preferences.getInt(_restaurantIdKey);
    final restaurantName = await _preferences.getString(_restaurantNameKey);

    if (roomId == null ||
        playerId == null ||
        restaurantId == null ||
        restaurantName == null ||
        restaurantName.trim().isEmpty) {
      return null;
    }

    return SavedActiveGameSession(
      roomId: roomId,
      playerId: playerId,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
    );
  }

  Future<void> clear() async {
    await _preferences.remove(_roomIdKey);
    await _preferences.remove(_playerIdKey);
    await _preferences.remove(_restaurantIdKey);
    await _preferences.remove(_restaurantNameKey);
  }
}
