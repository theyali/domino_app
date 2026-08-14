import 'dart:async';

import '../models/player_emotion_event.dart';

typedef EmotionSender = bool Function(String assetPath);

class EmotionRealtimeService {
  EmotionRealtimeService._();

  static final EmotionRealtimeService instance = EmotionRealtimeService._();

  final StreamController<PlayerEmotionEvent> _eventController =
      StreamController<PlayerEmotionEvent>.broadcast();

  Object? _senderOwner;
  EmotionSender? _sender;

  Stream<PlayerEmotionEvent> get events => _eventController.stream;

  void attachSender({
    required Object owner,
    required EmotionSender sender,
  }) {
    _senderOwner = owner;
    _sender = sender;
  }

  void detachSender(Object owner) {
    if (!identical(_senderOwner, owner)) {
      return;
    }

    _senderOwner = null;
    _sender = null;
  }

  bool sendEmotion(String assetPath) {
    if (!_isSupportedAssetPath(assetPath)) {
      return false;
    }

    final sender = _sender;
    return sender?.call(assetPath) ?? false;
  }

  void handleSocketMessage(Map<String, dynamic> message) {
    if (message['type'] != 'player_emotion') {
      return;
    }

    final rawPlayerId = message['player_id'];
    final rawEmotion = message['emotion'];
    final rawEventId = message['event_id'];

    if (rawPlayerId is! int ||
        rawEmotion is! String ||
        rawEventId is! String ||
        !_isSupportedAssetPath(rawEmotion)) {
      return;
    }

    if (_eventController.isClosed) {
      return;
    }

    _eventController.add(
      PlayerEmotionEvent(
        id: rawEventId,
        playerId: rawPlayerId,
        assetPath: rawEmotion,
      ),
    );
  }

  bool _isSupportedAssetPath(String value) {
    final normalized = value.trim().toLowerCase();
    if (!normalized.startsWith('assets/emotions/')) {
      return false;
    }
    if (normalized.contains('..')) {
      return false;
    }

    return normalized.endsWith('.png') ||
        normalized.endsWith('.jpg') ||
        normalized.endsWith('.jpeg') ||
        normalized.endsWith('.webp') ||
        normalized.endsWith('.gif');
  }
}
