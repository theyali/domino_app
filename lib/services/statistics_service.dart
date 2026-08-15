import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/league_statistics.dart';
import 'api_service.dart';
import 'auth_session_store.dart';

class StatisticsService {
  static final AuthSessionStore _authStore = AuthSessionStore();

  const StatisticsService();

  Future<LeagueStatistics> fetchStatistics() async {
    final token = await _authStore.loadToken();
    if (token == null) {
      throw const ApiException(
        'Сессия авторизации не найдена.',
        statusCode: 401,
      );
    }

    final response = await http.get(
      ApiConfig.uri('/api/stats/'),
      headers: {'Authorization': 'Token $token'},
    );

    dynamic data;
    try {
      data = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        'Сервер вернул некорректный ответ статистики.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = data is Map
          ? (data['detail']?.toString() ?? 'Не удалось загрузить статистику.')
          : 'Не удалось загрузить статистику.';
      throw ApiException(message, statusCode: response.statusCode);
    }

    if (data is! Map) {
      throw const ApiException('Сервер вернул неверную статистику.');
    }

    return LeagueStatistics.fromJson(Map<String, dynamic>.from(data));
  }
}
