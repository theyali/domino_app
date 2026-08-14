import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/game_room.dart';
import '../models/multiplayer_game_state.dart';
import '../models/restaurant.dart';
import '../models/room_player.dart';

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

class JoinRoomResult {
  final GameRoom room;
  final RoomPlayer player;

  const JoinRoomResult({required this.room, required this.player});
}

class ApiService {
  const ApiService();

  Future<List<Restaurant>> fetchRestaurants() async {
    final response = await http.get(ApiConfig.uri('/api/restaurants/'));
    final data = _decodeResponse(response);

    if (data is! List<dynamic>) {
      throw const ApiException('Сервер вернул неверный список ресторанов.');
    }

    return data
        .map(
          (item) => Restaurant.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<List<GameRoom>> fetchRooms(int restaurantId) async {
    final response = await http.get(
      ApiConfig.uri('/api/restaurants/$restaurantId/rooms/'),
    );
    final data = _decodeResponse(response);

    if (data is! List<dynamic>) {
      throw const ApiException('Сервер вернул неверный список комнат.');
    }

    return data
        .map(
          (item) => GameRoom.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<GameRoom> createRoom({
    required int restaurantId,
    required String ownerName,
    required int maxPlayers,
    String password = '',
    String name = '',
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/restaurants/$restaurantId/rooms/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'owner_name': ownerName.trim(),
        'max_players': maxPlayers,
        'password': password,
        'name': name.trim(),
      }),
    );

    final data = _decodeResponse(response);
    return GameRoom.fromJson(data as Map<String, dynamic>);
  }

  Future<JoinRoomResult> joinRoom({
    required int roomId,
    required String playerName,
    String password = '',
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/rooms/$roomId/join/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'player_name': playerName.trim(),
        'password': password,
      }),
    );

    final data = _decodeResponse(response) as Map<String, dynamic>;

    return JoinRoomResult(
      room: GameRoom.fromJson(data['room'] as Map<String, dynamic>),
      player: RoomPlayer.fromJson(data['player'] as Map<String, dynamic>),
    );
  }

  Future<GameRoom> fetchRoom(int roomId) async {
    final response = await http.get(ApiConfig.uri('/api/rooms/$roomId/'));
    final data = _decodeResponse(response);

    return GameRoom.fromJson(data as Map<String, dynamic>);
  }

  Future<void> leaveRoom({
    required int roomId,
    required int playerId,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/rooms/$roomId/leave/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'player_id': playerId}),
    );

    _decodeResponse(response);
  }

  Future<MultiplayerGameState> startGame({
    required int roomId,
    required int playerId,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/rooms/$roomId/start/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'player_id': playerId}),
    );

    return _decodeGameStateResponse(response);
  }

  Future<MultiplayerGameState> fetchGameState({
    required int roomId,
    required int playerId,
  }) async {
    final response = await http.get(
      ApiConfig.uri('/api/rooms/$roomId/game/').replace(
        queryParameters: {'player_id': '$playerId'},
      ),
    );

    return _decodeGameStateResponse(response);
  }

  Future<MultiplayerGameState> playDomino({
    required int roomId,
    required int playerId,
    required int dominoId,
    required String side,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/rooms/$roomId/game/play/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'player_id': playerId,
        'domino_id': dominoId,
        'side': side,
      }),
    );

    return _decodeGameStateResponse(response);
  }

  MultiplayerGameState _decodeGameStateResponse(http.Response response) {
    final data = _decodeResponse(response) as Map<String, dynamic>;
    final rawGame = data['game'];

    if (rawGame is! Map) {
      throw const ApiException('Сервер не вернул состояние игры.');
    }

    return MultiplayerGameState.fromJson(
      Map<String, dynamic>.from(rawGame),
    );
  }

  dynamic _decodeResponse(http.Response response) {
    dynamic data;

    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        'Сервер вернул некорректный ответ (${response.statusCode}).',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw ApiException(_extractErrorMessage(data, response.statusCode));
  }

  String _extractErrorMessage(dynamic data, int statusCode) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }

      for (final entry in data.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }

    return 'Ошибка сервера ($statusCode).';
  }
}
