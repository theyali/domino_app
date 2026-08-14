import '../config/api_config.dart';

class RoomPlayer {
  final int id;
  final String name;
  final String? avatarUrl;
  final int seatIndex;
  final bool isOwner;
  final bool isActive;
  final bool isOnline;
  final DateTime? lastSeenAt;

  const RoomPlayer({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.seatIndex,
    required this.isOwner,
    this.isActive = true,
    this.isOnline = false,
    this.lastSeenAt,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      id: json['id'] as int,
      name: json['name'] as String,
      avatarUrl: ApiConfig.resolveUrl(json['avatar_url'] as String?),
      seatIndex: json['seat_index'] as int,
      isOwner: json['is_owner'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
    );
  }
}
