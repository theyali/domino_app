import 'room_player.dart';

class GameRoom {
  final int id;
  final int restaurantId;
  final String name;
  final String displayName;
  final String ownerName;
  final int maxPlayers;
  final int currentPlayers;
  final bool isLocked;
  final bool isFull;
  final String status;
  final List<RoomPlayer> players;
  final DateTime? createdAt;

  const GameRoom({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.displayName,
    required this.ownerName,
    required this.maxPlayers,
    required this.currentPlayers,
    required this.isLocked,
    required this.isFull,
    required this.status,
    required this.players,
    this.createdAt,
  });

  factory GameRoom.fromJson(Map<String, dynamic> json) {
    final playersJson = json['players'] as List<dynamic>? ?? const [];

    return GameRoom(
      id: json['id'] as int,
      restaurantId: json['restaurant_id'] as int,
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Стол #${json['id']}',
      ownerName: json['owner_name'] as String,
      maxPlayers: json['max_players'] as int,
      currentPlayers: json['current_players'] as int? ?? playersJson.length,
      isLocked: json['is_locked'] as bool? ?? false,
      isFull: json['is_full'] as bool? ?? false,
      status: json['status'] as String? ?? 'waiting',
      players: playersJson
          .map(
            (item) => RoomPlayer.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}
