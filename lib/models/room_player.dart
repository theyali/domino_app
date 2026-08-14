class RoomPlayer {
  final int id;
  final String name;
  final int seatIndex;
  final bool isOwner;

  const RoomPlayer({
    required this.id,
    required this.name,
    required this.seatIndex,
    required this.isOwner,
  });

  factory RoomPlayer.fromJson(Map<String, dynamic> json) {
    return RoomPlayer(
      id: json['id'] as int,
      name: json['name'] as String,
      seatIndex: json['seat_index'] as int,
      isOwner: json['is_owner'] as bool? ?? false,
    );
  }
}
