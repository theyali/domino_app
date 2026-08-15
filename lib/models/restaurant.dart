import '../config/api_config.dart';

class Restaurant {
  final int id;
  final String name;
  final String? imageUrl;
  final int players;
  final bool active;
  final int waitingRooms;

  const Restaurant({
    required this.id,
    required this.name,
    this.imageUrl,
    required this.players,
    required this.active,
    this.waitingRooms = 0,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as int,
      name: json['name'] as String,
      imageUrl: ApiConfig.resolveUrl(json['image_url'] as String?),
      players: json['players'] as int? ?? 0,
      active: json['active'] as bool? ?? true,
      waitingRooms: json['waiting_rooms'] as int? ?? 0,
    );
  }
}
