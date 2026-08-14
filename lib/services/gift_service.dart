import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/gift.dart';
import 'api_service.dart';
import 'auth_session_store.dart';

class GiftService {
  static final AuthSessionStore _authStore = AuthSessionStore();

  const GiftService();

  Future<List<Gift>> fetchRestaurantGifts(int restaurantId) async {
    final response = await http.get(
      ApiConfig.uri('/api/restaurants/$restaurantId/gifts/'),
      headers: await _authHeaders(),
    );
    final data = _decodeResponse(response);

    if (data is! List) {
      throw const ApiException('Сервер вернул неверный каталог подарков.');
    }

    return data
        .map(
          (item) => Gift.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<int> purchaseGift({
    required int restaurantId,
    required int giftId,
    int quantity = 1,
  }) async {
    final response = await http.post(
      ApiConfig.uri(
        '/api/restaurants/$restaurantId/gifts/$giftId/purchase/',
      ),
      headers: await _authJsonHeaders(),
      body: jsonEncode({'quantity': quantity}),
    );
    final data = _decodeResponse(response);

    if (data is! Map) {
      throw const ApiException('Сервер не вернул количество подарков.');
    }

    final rawCount = data['giftable_count'];
    if (rawCount is! int) {
      throw const ApiException('Сервер вернул неверное количество подарков.');
    }

    return rawCount;
  }

  Future<List<InventoryGift>> fetchInventory() async {
    final response = await http.get(
      ApiConfig.uri('/api/inventory/gifts/'),
      headers: await _authHeaders(),
    );
    final data = _decodeResponse(response);

    if (data is! List) {
      throw const ApiException('Сервер вернул неверный инвентарь.');
    }

    return data
        .map(
          (item) => InventoryGift.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList(growable: false);
  }

  Future<void> sendGift({
    required int roomId,
    required int giftId,
    required List<int> recipientPlayerIds,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/rooms/$roomId/gifts/send/'),
      headers: await _authJsonHeaders(),
      body: jsonEncode({
        'gift_id': giftId,
        'recipient_player_ids': recipientPlayerIds,
      }),
    );

    _decodeResponse(response);
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
    if (data is Map) {
      for (final value in data.values) {
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
