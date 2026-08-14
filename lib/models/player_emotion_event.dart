class PlayerEmotionEvent {
  final String id;
  final int playerId;
  final String assetPath;

  const PlayerEmotionEvent({
    required this.id,
    required this.playerId,
    required this.assetPath,
  });
}
