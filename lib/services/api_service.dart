import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/game_room.dart';
import '../models/multiplayer_game_state.dart';
import '../models/restaurant.dart';
import '../models/room_player.dart';
import 'active_game_session_store.dart';
import 'auth_session_store.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class JoinRoomResult {
  final GameRoom room;
  final RoomPlayer player;

  const JoinRoomResult({required this.room, required this.player});
}

class ApiService {
  static final ActiveGameSessionStore _sessionStore = ActiveGameSessionStore();
  static final AuthSessionStore _authStore = AuthSessionStore();

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
    required int maxPlayers,
    required String gameMode,
    required int targetScore,
    int botCount = 0,
    String password = '',
    String name = '',
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/restaurants/$restaurantId/rooms/'),
      headers: await _authorizedJsonHeaders(),
      body: jsonEncode({
        'max_players': maxPlayers,
        'game_mode': gameMode,
        'target_score': targetScore,
        'bot_count': botCount,
        'password': password,
        'name': name.trim(),
      }),
    );

    final data = _decodeResponse(response);
    return GameRoom.fromJson(data as Map<String, dynamic>);
  }

  Future<JoinRoomResult> joinRoom({
    required int roomId,
    String password = '',
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/rooms/$roomId/join/'),
      headers: await _authorizedJsonHeaders(),
      body: jsonEncode({
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
    await _sessionStore.clearIfMatches(
      roomId: roomId,
      playerId: playerId,
    );
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

  Future<MultiplayerGameState> startNextRound({
    required int roomId,
    required int playerId,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/rooms/$roomId/game/next-round/'),
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

  Future<MultiplayerGameState> drawDomino({
    required int roomId,
    required int playerId,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/rooms/$roomId/game/draw/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'player_id': playerId}),
    );

    return _decodeGameStateResponse(response);
  }

  Future<MultiplayerGameState> passTurn({
    required int roomId,
    required int playerId,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/rooms/$roomId/game/pass/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'player_id': playerId}),
    );

    return _decodeGameStateResponse(response);
  }

  Future<MultiplayerGameState> surrenderGame({
    required int roomId,
    required int playerId,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/rooms/$roomId/game/surrender/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'player_id': playerId}),
    );

    return _decodeGameStateResponse(response);
  }

  Future<Map<String, String>> _authorizedJsonHeaders() async {
    final token = await _authStore.loadToken();
    if (token == null) {
      throw const ApiException('Сессия авторизации не найдена.', statusCode: 401);
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Token $token',
    };
  }

  MultiplayerGameState _decodeGameStateResponse(http.Response response) {
    final data = _decodeResponse(response) as Map<String, dynamic>;
    final rawGame = data['game'];

    if (rawGame is! Map) {
      throw ApiException(
        'Сервер не вернул состояние игры.',
        statusCode: response.statusCode,
      );
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
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    throw ApiException(
      _extractErrorMessage(data, response.statusCode),
      statusCode: response.statusCode,
    );
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
