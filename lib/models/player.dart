class Player {
  final int id;
  final String name;
  final String? avatarUrl;
  final int score;
  final bool isMe;

  const Player({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.score = 0,
    this.isMe = false,
  });
}
