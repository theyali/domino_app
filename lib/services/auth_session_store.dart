import 'package:shared_preferences/shared_preferences.dart';

class AuthSessionStore {
  static const String _tokenKey = 'auth_token';

  Future<void> saveToken(String token) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, token);
  }

  Future<String?> loadToken() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey)?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
  }
}
