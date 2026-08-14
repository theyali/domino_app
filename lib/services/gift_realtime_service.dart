import 'dart:async';

import '../models/gift.dart';

class GiftRealtimeEvent {
  final String id;
  final int senderPlayerId;
  final List<int> recipientPlayerIds;
  final Gift gift;

  const GiftRealtimeEvent({
    required this.id,
    required this.senderPlayerId,
    required this.recipientPlayerIds,
    required this.gift,
  });
}

class GiftRealtimeService {
  GiftRealtimeService._();

  static final GiftRealtimeService instance = GiftRealtimeService._();

  final StreamController<GiftRealtimeEvent> _eventController =
      StreamController<GiftRealtimeEvent>.broadcast();
  final StreamController<void> _stateController =
      StreamController<void>.broadcast();

  final Map<int, Gift?> _activeGifts = <int, Gift?>{};

  Stream<GiftRealtimeEvent> get events => _eventController.stream;
  Stream<void> get stateChanges => _stateController.stream;

  Gift? activeGiftFor(int playerId) => _activeGifts[playerId];

  void handleSocketMessage(Map<String, dynamic> message) {
    final type = message['type'];

    if (type == 'game_started' || type == 'game_state') {
      final rawGame = message['game'];
      if (rawGame is Map) {
        _syncGameState(Map<String, dynamic>.from(rawGame));
      }
      return;
    }

    if (type != 'gift_sent') {
      return;
    }

    final eventId = message['event_id'];
    final senderPlayerId = message['sender_player_id'];
    final rawRecipients = message['recipient_player_ids'];
    final rawGift = message['gift'];

    if (eventId is! String ||
        senderPlayerId is! int ||
        rawRecipients is! List ||
        rawGift is! Map) {
      return;
    }

    final recipients = rawRecipients
        .whereType<num>()
        .map((value) => value.toInt())
        .toList(growable: false);
    if (recipients.isEmpty) return;

    final gift = Gift.fromRealtimeJson(
      Map<String, dynamic>.from(rawGift),
    );

    if (!_eventController.isClosed) {
      _eventController.add(
        GiftRealtimeEvent(
          id: eventId,
          senderPlayerId: senderPlayerId,
          recipientPlayerIds: recipients,
          gift: gift,
        ),
      );
    }
  }

  void setActiveGiftAfterLanding(int playerId, Gift gift) {
    _activeGifts[playerId] = gift;
    _notifyStateChanged();
  }

  void _syncGameState(Map<String, dynamic> game) {
    final rawPlayers = game['players'];
    if (rawPlayers is! List) return;

    for (final rawPlayer in rawPlayers) {
      if (rawPlayer is! Map) continue;
      final player = Map<String, dynamic>.from(rawPlayer);
      final playerId = player['id'];
      if (playerId is! int) continue;

      final rawGift = player['active_gift'];
      _activeGifts[playerId] = rawGift is Map
          ? Gift.fromRealtimeJson(Map<String, dynamic>.from(rawGift))
          : null;
    }

    _notifyStateChanged();
  }

  void _notifyStateChanged() {
    if (!_stateController.isClosed) {
      _stateController.add(null);
    }
  }
}
