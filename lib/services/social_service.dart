import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/social.dart';
import 'api_service.dart';
import 'auth_session_store.dart';

class SocialService {
  static final AuthSessionStore _authStore = AuthSessionStore();

  const SocialService();

  Future<void> heartbeat() async {
    final response = await http.post(
      ApiConfig.uri('/api/social/heartbeat/'),
      headers: await _authJsonHeaders(),
    );
    _decode(response);
  }

  Future<SocialOverview> fetchOverview() async {
    final response = await http.get(
      ApiConfig.uri('/api/social/overview/'),
      headers: await _authHeaders(),
    );
    final data = _decode(response);
    if (data is! Map) {
      throw const ApiException('Сервер вернул неверные социальные данные.');
    }
    return SocialOverview.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<SocialUser>> fetchOnlineUsers({int? roomId}) async {
    var uri = ApiConfig.uri('/api/social/online/');
    if (roomId != null) {
      uri = uri.replace(queryParameters: {'room_id': '$roomId'});
    }
    final response = await http.get(uri, headers: await _authHeaders());
    final data = _decode(response);
    if (data is! List) {
      throw const ApiException('Сервер вернул неверный список игроков.');
    }
    return data
        .whereType<Map>()
        .map((item) => SocialUser.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> sendFriendRequest(int userId) async {
    final response = await http.post(
      ApiConfig.uri('/api/social/friends/request/'),
      headers: await _authJsonHeaders(),
      body: jsonEncode({'user_id': userId}),
    );
    _decode(response);
  }

  Future<void> acceptFriendRequest(int friendshipId) async {
    final response = await http.post(
      ApiConfig.uri('/api/social/friends/$friendshipId/accept/'),
      headers: await _authJsonHeaders(),
    );
    _decode(response);
  }

  Future<void> removeFriendship(int friendshipId) async {
    final response = await http.post(
      ApiConfig.uri('/api/social/friends/$friendshipId/remove/'),
      headers: await _authJsonHeaders(),
    );
    _decode(response);
  }

  Future<DirectMessageThread> fetchMessages(int userId) async {
    final response = await http.get(
      ApiConfig.uri('/api/social/chats/$userId/'),
      headers: await _authHeaders(),
    );
    final data = _decode(response);
    return DirectMessageThread.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<DirectMessageItem> sendMessage({
    required int userId,
    required String body,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/social/chats/$userId/'),
      headers: await _authJsonHeaders(),
      body: jsonEncode({'body': body}),
    );
    final data = _decode(response);
    return DirectMessageItem.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<int> sendRoomInvitations({
    required int roomId,
    required List<int> userIds,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/social/rooms/$roomId/invitations/'),
      headers: await _authJsonHeaders(),
      body: jsonEncode({'user_ids': userIds}),
    );
    final data = _decode(response);
    if (data is! Map) {
      throw const ApiException('Сервер не подтвердил приглашения.');
    }
    return data['sent'] as int? ?? 0;
  }

  Future<SocialJoinResult> acceptInvitation(int invitationId) async {
    final response = await http.post(
      ApiConfig.uri('/api/social/invitations/$invitationId/accept/'),
      headers: await _authJsonHeaders(),
    );
    final data = _decode(response);
    return SocialJoinResult.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<void> declineInvitation(int invitationId) async {
    final response = await http.post(
      ApiConfig.uri('/api/social/invitations/$invitationId/decline/'),
      headers: await _authJsonHeaders(),
    );
    _decode(response);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _authStore.loadToken();
    if (token == null) {
      throw const ApiException('Сессия авторизации не найдена.', statusCode: 401);
    }
    return {'Authorization': 'Token $token'};
  }

  Future<Map<String, String>> _authJsonHeaders() async {
    return {
      ...await _authHeaders(),
      'Content-Type': 'application/json',
    };
  }

  dynamic _decode(http.Response response) {
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

    String message = 'Ошибка сервера (${response.statusCode}).';
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        message = detail;
      } else {
        for (final value in data.values) {
          if (value is List && value.isNotEmpty) {
            message = value.first.toString();
            break;
          }
          if (value is String && value.trim().isNotEmpty) {
            message = value;
            break;
          }
        }
      }
    }
    throw ApiException(message, statusCode: response.statusCode);
  }
}
