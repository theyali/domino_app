import 'user_gender.dart';

class PlayerAvatarCache {
  static final Map<int, String> _urls = <int, String>{};

  const PlayerAvatarCache._();

  static void remember(int playerId, String? avatarUrl) {
    final normalized = avatarUrl?.trim();
    if (normalized == null || normalized.isEmpty) {
      _urls.remove(playerId);
      return;
    }
    _urls[playerId] = normalized;
  }

  static String? avatarUrlFor(int playerId) => _urls[playerId];
}

class PlayerGenderCache {
  static final Map<int, UserGender> _genders = <int, UserGender>{};

  const PlayerGenderCache._();

  static void remember(int playerId, UserGender? gender) {
    if (gender == null) {
      _genders.remove(playerId);
      return;
    }
    _genders[playerId] = gender;
  }

  static UserGender? genderFor(int playerId) => _genders[playerId];
}

class Player {
  final int id;
  final String name;
  final String? avatarUrl;
  final UserGender? gender;
  final int score;
  final bool isMe;

  const Player({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.gender,
    this.score = 0,
    this.isMe = false,
  });
}
