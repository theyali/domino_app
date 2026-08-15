import '../config/api_config.dart';
import 'user_gender.dart';

class UserAccount {
  final int id;
  final String username;
  final String email;
  final String firstName;
  final String? avatarUrl;
  final UserGender? gender;

  const UserAccount({
    required this.id,
    required this.username,
    required this.email,
    required this.firstName,
    this.avatarUrl,
    this.gender,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'] as int,
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      avatarUrl: ApiConfig.resolveUrl(json['avatar_url'] as String?),
      gender: UserGender.fromApi(json['gender']),
    );
  }

  String get displayName => firstName.trim().isNotEmpty ? firstName : username;
}
