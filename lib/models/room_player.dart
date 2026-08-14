class RoomPlayer {
  final int id;
  final String name;
  final int seatIndex;
  final bool isOwner;
  final bool isActive;

  const RoomPlayer({
    required this.id,
    required this.name,
    required this.seatIndex,
    required this.isOwner,
    this.isActive = true,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      id: json['id'] as int,
      name: json['name'] as String,
      seatIndex: json['seat_index'] as int,
      isOwner: json['is_owner'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}
