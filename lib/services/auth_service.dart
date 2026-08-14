import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/user_account.dart';
import 'api_service.dart';

class AuthResult {
  final String token;
  final UserAccount user;

  const AuthResult({required this.token, required this.user});
}

class AuthService {
  const AuthService();

  Future<AuthResult> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/auth/register/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'email': email.trim(),
        'password': password,
        'password_confirm': passwordConfirm,
      }),
    );

    return _decodeAuthResult(response);
  }

  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      ApiConfig.uri('/api/auth/login/'),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'password': password,
      }),
    );

    return _decodeAuthResult(response);
  }

  Future<UserAccount> fetchMe(String token) async {
    final response = await http.get(
      ApiConfig.uri('/api/auth/me/'),
      headers: {'Authorization': 'Token $token'},
    );
    final data = _decodeResponse(response);
    return UserAccount.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<void> logout(String token) async {
    final response = await http.post(
      ApiConfig.uri('/api/auth/logout/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 204) {
      return;
    }

    _decodeResponse(response);
  }

  AuthResult _decodeAuthResult(http.Response response) {
    final data = _decodeResponse(response);
    if (data is! Map) {
      throw ApiException(
        'Сервер вернул неверные данные авторизации.',
        statusCode: response.statusCode,
      );
    }

    final map = Map<String, dynamic>.from(data);
    final token = map['token'];
    final rawUser = map['user'];

    if (token is! String || token.isEmpty || rawUser is! Map) {
      throw ApiException(
        'Сервер не вернул сессию пользователя.',
        statusCode: response.statusCode,
      );
    }

    return AuthResult(
      token: token,
      user: UserAccount.fromJson(Map<String, dynamic>.from(rawUser)),
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
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final detail = map['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }

      for (final value in map.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value is Map && value.isNotEmpty) {
          final nested = value.values.first;
          if (nested is List && nested.isNotEmpty) {
            return nested.first.toString();
          }
          return nested.toString();
        }
        if (value is String && value.trim().isNotEmpty) {
          return value;
        }
      }
    }

    return 'Ошибка сервера ($statusCode).';
  }
}
