import 'package:shared_preferences/shared_preferences.dart';

class SavedActiveGameSession {
  final int roomId;
  final int playerId;

  const SavedActiveGameSession({
    required this.roomId,
    required this.playerId,
  });
}

class ActiveGameSessionStore {
  static const String _roomIdKey = 'active_game.room_id';
  static const String _playerIdKey = 'active_game.player_id';

  final SharedPreferencesAsync _preferences;

  ActiveGameSessionStore({SharedPreferencesAsync? preferences})
      : _preferences = preferences ?? SharedPreferencesAsync();

  Future<void> save({
    required int roomId,
    required int playerId,
  }) async {
    await _preferences.setInt(_roomIdKey, roomId);
    await _preferences.setInt(_playerIdKey, playerId);
  }

  Future<SavedActiveGameSession?> load() async {
    final roomId = await _preferences.getInt(_roomIdKey);
    final playerId = await _preferences.getInt(_playerIdKey);

    if (roomId == null || playerId == null) {
      return null;
    }

    return SavedActiveGameSession(
      roomId: roomId,
      playerId: playerId,
    );
  }

  Future<void> clearIfMatches({
    required int roomId,
    required int playerId,
  }) async {
    final saved = await load();
    if (saved == null ||
        saved.roomId != roomId ||
        saved.playerId != playerId) {
      return;
    }

    await clear();
  }

  Future<void> clear() async {
    await _preferences.remove(_roomIdKey);
    await _preferences.remove(_playerIdKey);
  }
}
