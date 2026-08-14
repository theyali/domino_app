import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/gift.dart';
import '../models/player.dart';
import '../services/active_game_session_store.dart';
import '../services/api_service.dart';
import '../services/emotion_realtime_service.dart';
import '../services/gift_realtime_service.dart';
import '../services/gift_service.dart';
import '../services/player_avatar_registry.dart';
import '../theme/app_colors.dart';
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
  int _activeGiftVisualRevision = 0;

  bool get _isMultiplayerAvatar => widget.isOnline != null;

  bool get _isAzerbaijani => context.appLanguage.code == 'az';

  @override
  void initState() {
    super.initState();
    _activeGift = _giftRealtime.activeGiftFor(widget.player.id);
    _giftEventSubscription = _giftRealtime.events.listen(_handleGiftEvent);
    _giftStateSubscription = _giftRealtime.stateChanges.listen((_) {
      if (!mounted || _pendingGiftEventId != null) return;
      setState(() {
        _activeGift = _giftRealtime.activeGiftFor(widget.player.id);
        _activeGiftVisualRevision += 1;
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
      _activeGiftVisualRevision = 0;
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
      _showMessage(
        _isAzerbaijani
            ? 'Emosiyanı realtime bərpa olunduqdan sonra göndərmək olar.'
            : 'Эмоцию можно отправить после восстановления realtime.',
      );
    }
  }

  Future<void> _showGiftPicker() async {
    if (_isOpeningGiftMenu) return;
    _isOpeningGiftMenu = true;

    try {
      final savedSession = await _sessionStore.load();
      if (savedSession == null) {
        _showMessage(
          _isAzerbaijani
              ? 'Cari masanı müəyyən etmək mümkün olmadı.'
              : 'Не удалось определить текущий стол.',
        );
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
      if (mounted) {
        _showMessage(
          _isAzerbaijani
              ? 'Hədiyyəni göndərmək mümkün olmadı.'
              : 'Не удалось отправить подарок.',
        );
      }
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
                widget.giftPlacement == PlayerGiftPlacement.right ? 29 : -29,
                4,
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
      _activeGiftVisualRevision += 1;
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
    final emphasized = widget.isActive || player.isMe;
    final avatarLetter = player.name.trim().isEmpty
        ? '?'
        : player.name.trim().substring(0, 1).toUpperCase();

    final avatarFrameGradient = widget.isActive
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF7FAFC),
              Color(0xFF9AA8B6),
            ],
          )
        : player.isMe
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.limeSoft,
                  AppColors.lime,
                  AppColors.limeDark,
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFF93A1AE),
                ],
              );

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
            width: 92,
            height: 82,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 10,
                  top: 5,
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (widget.isActive)
                          SizedBox(
                            width: 72,
                            height: 72,
                            child: CircularProgressIndicator(
                              value: widget.turnProgress.clamp(0.0, 1.0).toDouble(),
                              strokeWidth: 4.5,
                              backgroundColor: Colors.black.withValues(alpha: 0.38),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppColors.lime,
                              ),
                            ),
                          ),
                        Container(
                          width: 64,
                          height: 64,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: avatarFrameGradient,
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black54,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AppColors.cream,
                                  Color(0xFFE2E6EB),
                                ],
                              ),
                              border: Border.all(
                                color: AppColors.ink,
                                width: 1.7,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              avatarLetter,
                              style: const TextStyle(
                                color: Color(0xFF6242A3),
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                    color: Colors.white,
                                    offset: Offset(0, 1),
                                  ),
                                ],
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
                  child: _HudBadge(
                    text: '${player.score}',
                    minWidth: 29,
                    backgroundColor: AppColors.badge,
                    borderColor: AppColors.cream,
                  ),
                ),
                if (widget.isActive && widget.turnSecondsLeft != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _HudBadge(
                      text: '${widget.turnSecondsLeft}',
                      minWidth: 34,
                      backgroundColor: AppColors.lime,
                      borderColor: AppColors.ink,
                      textColor: Colors.black,
                      glow: true,
                    ),
                  ),
                if (!player.isMe)
                  Positioned(
                    right: -1,
                    bottom: 0,
                    child: _DominoCountBadge(count: widget.dominoCount),
                  ),
                Positioned(
                  left: widget.giftPlacement == PlayerGiftPlacement.left
                      ? -1
                      : null,
                  right: widget.giftPlacement == PlayerGiftPlacement.right
                      ? -1
                      : null,
                  top: 30,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      reverseDuration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.linear,
                      switchOutCurve: Curves.linear,
                      transitionBuilder: (child, animation) {
                        final scaleAnimation = Tween<double>(
                          begin: 0.58,
                          end: 1,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutBack,
                            reverseCurve: Curves.easeInCubic,
                          ),
                        );

                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: scaleAnimation,
                            child: child,
                          ),
                        );
                      },
                      child: hasActiveGift
                          ? Center(
                              key: ValueKey(
                                'gift-${widget.player.id}-$_activeGiftVisualRevision-'
                                '${activeGiftImageUrl ?? ''}|${activeGiftName ?? ''}',
                              ),
                              child: _ActiveGiftImage(
                                imageUrl: activeGiftImageUrl,
                                name: activeGiftName,
                              ),
                            )
                          : const SizedBox.shrink(
                              key: ValueKey('no-active-gift'),
                            ),
                    ),
                  ),
                ),
                if (widget.isOnline != null)
                  Positioned.fill(
                    child: PlayerEmotionOverlay(playerId: player.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 1),
          Container(
            constraints: const BoxConstraints(minWidth: 54),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.badge.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: emphasized
                    ? AppColors.lime.withValues(alpha: 0.72)
                    : Colors.white24,
                width: 1.2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              player.isMe
                  ? '${player.name} (${_isAzerbaijani ? 'Sən' : 'Ты'})'
                  : player.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: emphasized ? AppColors.lime : Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveGiftImage extends StatefulWidget {
  final String? imageUrl;
  final String? name;

  const _ActiveGiftImage({
    super.key,
    required this.imageUrl,
    required this.name,
  });

  @override
  State<_ActiveGiftImage> createState() => _ActiveGiftImageState();
}

class _ActiveGiftImageState extends State<_ActiveGiftImage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _float;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1550),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -1.2, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _scale = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallbackName = context.appLanguage.code == 'az' ? 'Hədiyyə' : 'Подарок';

    return Tooltip(
      message: widget.name?.trim().isNotEmpty == true ? widget.name! : fallbackName,
      child: AnimatedBuilder(
        animation: _controller,
        child: SizedBox(
          width: 26,
          height: 26,
          child: widget.imageUrl?.trim().isNotEmpty == true
              ? Image.network(
                  widget.imageUrl!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.card_giftcard_rounded,
                      color: Colors.amberAccent,
                      size: 22,
                    );
                  },
                )
              : const Icon(
                  Icons.card_giftcard_rounded,
                  color: Colors.amberAccent,
                  size: 22,
                ),
        ),
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _float.value),
            child: Transform.scale(
              scale: _scale.value,
              child: child,
            ),
          );
        },
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
      height: 23,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.badgeLight,
            AppColors.badge,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.cream.withValues(alpha: 0.82),
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 5,
            offset: Offset(0, 2),
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
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudBadge extends StatelessWidget {
  final String text;
  final double minWidth;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final bool glow;

  const _HudBadge({
    required this.text,
    required this.minWidth,
    required this.backgroundColor,
    required this.borderColor,
    this.textColor = Colors.white,
    this.glow = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 29,
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor, width: 1.8),
        boxShadow: [
          const BoxShadow(
            color: Colors.black45,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
          if (glow)
            BoxShadow(
              color: AppColors.lime.withValues(alpha: 0.32),
              blurRadius: 10,
              spreadRadius: 1,
            ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
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
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.ink, width: 0.8),
      ),
      child: Column(
        children: [
          const Expanded(child: SizedBox()),
          Container(height: 1, color: AppColors.ink),
          const Expanded(child: SizedBox()),
        ],
      ),
    );
  }
}
