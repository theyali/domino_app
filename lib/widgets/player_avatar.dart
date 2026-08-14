import 'dart:async';

import 'package:flutter/material.dart';

import '../models/gift.dart';
import '../models/player.dart';
import '../services/active_game_session_store.dart';
import '../services/api_service.dart';
import '../services/emotion_realtime_service.dart';
import '../services/gift_realtime_service.dart';
import '../services/gift_service.dart';
import '../services/player_avatar_registry.dart';
import 'emotion_picker_sheet.dart';
import 'gift_flight_animation.dart';
import 'multiplayer_gift_sheet.dart';
import 'player_emotion_overlay.dart';

enum PlayerGiftPlacement { left, right }

class PlayerAvatar extends StatefulWidget {
  final Player player;
  final VoidCallback onTap;
  final bool isActive;
  final int? turnSecondsLeft;
  final double turnProgress;
  final int dominoCount;
  final bool? isOnline;
  final String? activeGiftImageUrl;
  final String? activeGiftName;
  final PlayerGiftPlacement giftPlacement;

  const PlayerAvatar({
    super.key,
    required this.player,
    required this.onTap,
    required this.dominoCount,
    this.isActive = false,
    this.turnSecondsLeft,
    this.turnProgress = 0,
    this.isOnline,
    this.activeGiftImageUrl,
    this.activeGiftName,
    this.giftPlacement = PlayerGiftPlacement.right,
  });

  @override
  State<PlayerAvatar> createState() => _PlayerAvatarState();
}

class _PlayerAvatarState extends State<PlayerAvatar> {
  static const ApiService _apiService = ApiService();
  static const GiftService _giftService = GiftService();

  final ActiveGameSessionStore _sessionStore = ActiveGameSessionStore();
  final GiftRealtimeService _giftRealtime = GiftRealtimeService.instance;
  final PlayerAvatarRegistry _avatarRegistry = PlayerAvatarRegistry.instance;
  final GlobalKey _anchorKey = GlobalKey();

  StreamSubscription<GiftRealtimeEvent>? _giftEventSubscription;
  StreamSubscription<void>? _giftStateSubscription;

  Gift? _activeGift;
  String? _pendingGiftEventId;
  OverlayEntry? _flightOverlay;
  bool _isOpeningGiftMenu = false;

  bool get _isMultiplayerAvatar => widget.isOnline != null;

  @override
  void initState() {
    super.initState();
    _activeGift = _giftRealtime.activeGiftFor(widget.player.id);
    _giftEventSubscription = _giftRealtime.events.listen(_handleGiftEvent);
    _giftStateSubscription = _giftRealtime.stateChanges.listen((_) {
      if (!mounted || _pendingGiftEventId != null) return;
      setState(() {
        _activeGift = _giftRealtime.activeGiftFor(widget.player.id);
      });
    });
    _registerAnchorAfterFrame();
  }

  @override
  void didUpdateWidget(covariant PlayerAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.player.id != widget.player.id) {
      _avatarRegistry.unregister(
        playerId: oldWidget.player.id,
        owner: this,
      );
      _activeGift = _giftRealtime.activeGiftFor(widget.player.id);
    }

    _registerAnchorAfterFrame();
  }

  @override
  void dispose() {
    _avatarRegistry.unregister(
      playerId: widget.player.id,
      owner: this,
    );
    unawaited(_giftEventSubscription?.cancel());
    unawaited(_giftStateSubscription?.cancel());
    _flightOverlay?.remove();
    _flightOverlay = null;
    super.dispose();
  }

  void _registerAnchorAfterFrame() {
    if (!_isMultiplayerAvatar) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final anchorContext = _anchorKey.currentContext;
      if (anchorContext == null) return;

      _avatarRegistry.register(
        playerId: widget.player.id,
        owner: this,
        context: anchorContext,
      );
    });
  }

  Future<void> _handleTap() async {
    if (!_isMultiplayerAvatar) {
      widget.onTap();
      return;
    }

    if (widget.player.isMe) {
      await _showEmotionPicker();
      return;
    }

    await _showGiftPicker();
  }

  Future<void> _showEmotionPicker() async {
    final emotionAsset = await EmotionPickerSheet.show(context);
    if (emotionAsset == null || !mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 170));
    if (!mounted) return;

    final sent = EmotionRealtimeService.instance.sendEmotion(emotionAsset);
    if (!sent) {
      _showMessage('Эмоцию можно отправить после восстановления realtime.');
    }
  }

  Future<void> _showGiftPicker() async {
    if (_isOpeningGiftMenu) return;
    _isOpeningGiftMenu = true;

    try {
      final savedSession = await _sessionStore.load();
      if (savedSession == null) {
        _showMessage('Не удалось определить текущий стол.');
        return;
      }

      final gameState = await _apiService.fetchGameState(
        roomId: savedSession.roomId,
        playerId: savedSession.playerId,
      );
      final room = await _apiService.fetchRoom(savedSession.roomId);

      if (!mounted) return;

      final request = await MultiplayerGiftSheet.show(
        context,
        restaurantId: room.restaurantId,
        myPlayerId: gameState.myPlayerId,
        initialRecipientPlayerId: widget.player.id,
        players: gameState.players,
      );

      if (request == null || !mounted) return;

      await _giftService.sendGift(
        roomId: savedSession.roomId,
        giftId: request.giftId,
        recipientPlayerIds: request.recipientPlayerIds,
      );
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage('Не удалось отправить подарок.');
    } finally {
      _isOpeningGiftMenu = false;
    }
  }

  void _handleGiftEvent(GiftRealtimeEvent event) {
    if (!mounted ||
        !_isMultiplayerAvatar ||
        !event.recipientPlayerIds.contains(widget.player.id)) {
      return;
    }

    setState(() {
      _pendingGiftEventId = event.id;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingGiftEventId != event.id) return;

      final source = _avatarRegistry.globalCenterFor(event.senderPlayerId);
      final avatarTarget = _avatarRegistry.globalCenterFor(widget.player.id);
      final target = avatarTarget == null
          ? null
          : avatarTarget +
              Offset(
                widget.giftPlacement == PlayerGiftPlacement.right ? 58 : -58,
                -6,
              );

      if (source == null || target == null) {
        _finishGiftLanding(event);
        return;
      }

      _flightOverlay?.remove();
      _flightOverlay = null;

      late final OverlayEntry entry;
      entry = OverlayEntry(
        builder: (overlayContext) {
          return Positioned.fill(
            child: GiftFlightAnimation(
              imageUrl: event.gift.imageUrl,
              giftName: event.gift.name,
              sourceGlobalCenter: source,
              targetGlobalCenter: target,
              onCompleted: () {
                if (entry.mounted) {
                  entry.remove();
                }
                if (identical(_flightOverlay, entry)) {
                  _flightOverlay = null;
                }
                _finishGiftLanding(event);
              },
            ),
          );
        },
      );

      _flightOverlay = entry;
      Overlay.of(context, rootOverlay: true).insert(entry);
    });
  }

  void _finishGiftLanding(GiftRealtimeEvent event) {
    if (!mounted || _pendingGiftEventId != event.id) return;

    _giftRealtime.setActiveGiftAfterLanding(widget.player.id, event.gift);
    setState(() {
      _pendingGiftEventId = null;
      _activeGift = event.gift;
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final avatarBorderColor = widget.isActive
        ? Colors.greenAccent
        : player.isMe
            ? Colors.green
            : Colors.white;
    final nameColor = widget.isActive
        ? Colors.greenAccent
        : player.isMe
            ? Colors.greenAccent
            : Colors.white;
    final avatarLetter = player.name.trim().isEmpty
        ? '?'
        : player.name.trim().substring(0, 1).toUpperCase();

    final realtimeGift = _activeGift;
    final activeGiftImageUrl = realtimeGift?.imageUrl ?? widget.activeGiftImageUrl;
    final activeGiftName = realtimeGift?.name ?? widget.activeGiftName;
    final hasActiveGift =
        (activeGiftImageUrl?.trim().isNotEmpty ?? false) ||
        (activeGiftName?.trim().isNotEmpty ?? false);

    return GestureDetector(
      key: _anchorKey,
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 88,
            height: 80,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 10,
                  top: 6,
                  child: SizedBox(
                    width: 68,
                    height: 68,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (widget.isActive)
                          SizedBox(
                            width: 68,
                            height: 68,
                            child: CircularProgressIndicator(
                              value: widget.turnProgress.clamp(0.0, 1.0).toDouble(),
                              strokeWidth: 4,
                              backgroundColor: Colors.black.withValues(alpha: 0.30),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.greenAccent,
                              ),
                            ),
                          ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: widget.isActive ? 3 : 2.5,
                              color: avatarBorderColor,
                            ),
                            boxShadow: widget.isActive
                                ? [
                                    BoxShadow(
                                      color: Colors.greenAccent.withValues(alpha: 0.28),
                                      blurRadius: 12,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                          child: CircleAvatar(
                            backgroundColor: Colors.grey.shade300,
                            child: Text(
                              avatarLetter,
                              style: const TextStyle(
                                color: Color(0xFF5B3A9E),
                                fontSize: 23,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _RoundBadge(
                    text: '${player.score}',
                    minWidth: 27,
                    backgroundColor: const Color(0xFF0B1F33),
                    borderColor: Colors.white,
                  ),
                ),
                if (widget.isActive && widget.turnSecondsLeft != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _RoundBadge(
                      text: '${widget.turnSecondsLeft}',
                      minWidth: 31,
                      backgroundColor: const Color(0xFF123C2B),
                      borderColor: Colors.greenAccent,
                    ),
                  ),
                if (widget.isOnline != null)
                  Positioned(
                    left: 10,
                    bottom: 5,
                    child: _PresenceDot(isOnline: widget.isOnline!),
                  ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _DominoCountBadge(count: widget.dominoCount),
                ),
                if (hasActiveGift && _pendingGiftEventId == null)
                  Positioned(
                    left: widget.giftPlacement == PlayerGiftPlacement.left
                        ? -48
                        : null,
                    right: widget.giftPlacement == PlayerGiftPlacement.right
                        ? -48
                        : null,
                    top: 18,
                    child: _ActiveGiftImage(
                      imageUrl: activeGiftImageUrl,
                      name: activeGiftName,
                    ),
                  ),
                if (widget.isOnline != null)
                  Positioned.fill(
                    child: PlayerEmotionOverlay(playerId: player.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            player.isMe ? '${player.name} (Ты)' : player.name,
            style: TextStyle(
              color: nameColor,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveGiftImage extends StatelessWidget {
  final String? imageUrl;
  final String? name;

  const _ActiveGiftImage({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: name?.trim().isNotEmpty == true ? name! : 'Подарок',
      child: SizedBox(
        width: 44,
        height: 44,
        child: imageUrl?.trim().isNotEmpty == true
            ? Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.amberAccent,
                    size: 34,
                  );
                },
              )
            : const Icon(
                Icons.card_giftcard_rounded,
                color: Colors.amberAccent,
                size: 34,
              ),
      ),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  final bool isOnline;

  const _PresenceDot({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? Colors.greenAccent : Colors.blueGrey.shade300;
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: const Color(0xFF0D1B2A), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _DominoCountBadge extends StatelessWidget {
  final int count;

  const _DominoCountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF15283A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.78),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _MiniDominoIcon(),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundBadge extends StatelessWidget {
  final String text;
  final double minWidth;
  final Color backgroundColor;
  final Color borderColor;

  const _RoundBadge({
    required this.text,
    required this.minWidth,
    required this.backgroundColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 27,
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MiniDominoIcon extends StatelessWidget {
  const _MiniDominoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 16,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(2.5),
      ),
      child: Column(
        children: [
          const Expanded(child: SizedBox()),
          Container(height: 1, color: const Color(0xFF15283A)),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
