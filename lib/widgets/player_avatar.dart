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
import '../services/social_service.dart';
import '../theme/app_colors.dart';
import '../theme/gender_style.dart';
import 'emotion_picker_sheet.dart';
import 'gift_flight_animation.dart';
import 'multiplayer_gift_sheet.dart';
import 'player_emotion_overlay.dart';

enum PlayerGiftPlacement { left, right }

class PlayerAvatar extends StatefulWidget {
  final Player player;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final bool isActive;
  final int? turnSecondsLeft;
  final double turnProgress;
  final int dominoCount;
  final bool? isOnline;
  final String? activeGiftImageUrl;
  final String? activeGiftName;
  final PlayerGiftPlacement giftPlacement;
  final bool showName;
  final bool compact;

  const PlayerAvatar({
    super.key,
    required this.player,
    required this.onTap,
    required this.dominoCount,
    this.onDoubleTap,
    this.isActive = false,
    this.turnSecondsLeft,
    this.turnProgress = 0,
    this.isOnline,
    this.activeGiftImageUrl,
    this.activeGiftName,
    this.giftPlacement = PlayerGiftPlacement.right,
    this.showName = true,
    this.compact = false,
  });

  @override
  State<PlayerAvatar> createState() => _PlayerAvatarState();
}

class _PlayerAvatarState extends State<PlayerAvatar> {
  static const ApiService _apiService = ApiService();
  static const GiftService _giftService = GiftService();
  static const SocialService _socialService = SocialService();

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
  bool _isOpeningSocialMenu = false;
  int _activeGiftVisualRevision = 0;

  bool get _isMultiplayerAvatar => widget.isOnline != null;

  bool get _isAzerbaijani => context.appLanguage.code == 'az';

  Color get _playerNameColor => GenderStyle.colorFor(
        widget.player.gender ?? PlayerGenderCache.genderFor(widget.player.id),
        fallback: AppColors.ink,
      );

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

  Future<void> _handleDoubleTap() async {
    final customAction = widget.onDoubleTap;
    if (customAction != null) {
      customAction();
      return;
    }

    if (!_isMultiplayerAvatar || widget.player.isMe || _isOpeningSocialMenu) {
      return;
    }

    _isOpeningSocialMenu = true;
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

      int? userId;
      for (final candidate in gameState.players) {
        if (candidate.id == widget.player.id) {
          userId = candidate.userId;
          break;
        }
      }

      if (userId == null || !mounted) {
        if (mounted) {
          _showMessage(
            _isAzerbaijani
                ? 'Bu oyunçunun hesabını müəyyən etmək mümkün olmadı.'
                : 'Не удалось определить аккаунт этого игрока.',
          );
        }
        return;
      }

      final addFriend = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black54,
        builder: (sheetContext) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: AppColors.ink, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.ink,
                      blurRadius: 0,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.ink,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.player.name,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _playerNameColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _isAzerbaijani
                          ? 'Oyunçu ilə nə etmək istəyirsən?'
                          : 'Что сделать с игроком?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.ink.withValues(alpha: 0.65),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: AppColors.ink,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: const BorderSide(
                            color: AppColors.ink,
                            width: 2.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded),
                        label: Text(
                          _isAzerbaijani
                              ? 'Dostlara əlavə et'
                              : 'Добавить в друзья',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );

      if (addFriend != true || !mounted) return;

      try {
        await _socialService.sendFriendRequest(userId);
        if (!mounted) return;
        _showMessage(
          _isAzerbaijani
              ? 'Dostluq sorğusu göndərildi.'
              : 'Заявка в друзья отправлена.',
        );
      } on ApiException catch (error) {
        if (mounted) _showMessage(error.message);
      } catch (_) {
        if (mounted) {
          _showMessage(
            _isAzerbaijani
                ? 'Dostluq sorğusunu göndərmək mümkün olmadı.'
                : 'Не удалось отправить заявку в друзья.',
          );
        }
      }
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(
          _isAzerbaijani
              ? 'Oyunçu menyusunu açmaq mümkün olmadı.'
              : 'Не удалось открыть меню игрока.',
        );
      }
    } finally {
      _isOpeningSocialMenu = false;
    }
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
      final giftOffset = widget.compact ? 25.0 : 29.0;
      final target = avatarTarget == null
          ? null
          : avatarTarget +
              Offset(
                widget.giftPlacement == PlayerGiftPlacement.right
                    ? giftOffset
                    : -giftOffset,
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
    final nameColor = _playerNameColor;
    final avatarLetter = player.name.trim().isEmpty
        ? '?'
        : player.name.trim().substring(0, 1).toUpperCase();
    final avatarUrl =
        player.avatarUrl ?? PlayerAvatarCache.avatarUrlFor(player.id);

    final canvasWidth = widget.compact ? 84.0 : 92.0;
    final canvasHeight = widget.compact ? 68.0 : 78.0;
    final avatarAreaSize = widget.compact ? 61.0 : 69.0;
    final frameSize = widget.compact ? 57.0 : 63.0;
    final avatarLeft = (canvasWidth - avatarAreaSize) / 2;
    final avatarTop = widget.compact ? 3.0 : 4.0;

    final realtimeGift = _activeGift;
    final activeGiftImageUrl =
        realtimeGift?.imageUrl ?? widget.activeGiftImageUrl;
    final activeGiftName = realtimeGift?.name ?? widget.activeGiftName;
    final hasActiveGift =
        (activeGiftImageUrl?.trim().isNotEmpty ?? false) ||
        (activeGiftName?.trim().isNotEmpty ?? false);

    final frameColor = widget.isActive
        ? AppColors.lime
        : player.isMe
            ? AppColors.cartoonPurple
            : AppColors.cartoonYellow;

    final frameRotation = player.id.isEven ? 0.035 : -0.035;

    return GestureDetector(
      key: _anchorKey,
      onTap: _handleTap,
      onDoubleTap: _handleDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: canvasWidth,
            height: canvasHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: avatarLeft,
                  top: avatarTop,
                  child: SizedBox(
                    width: avatarAreaSize,
                    height: avatarAreaSize,
                    child: Center(
                      child: Transform.rotate(
                        angle: frameRotation,
                        child: Container(
                          width: frameSize,
                          height: frameSize,
                          padding: const EdgeInsets.all(3.5),
                          decoration: BoxDecoration(
                            color: frameColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.ink,
                              width: 2.8,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.ink,
                                blurRadius: 0,
                                offset: Offset(3, 4),
                              ),
                            ],
                          ),
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.cream,
                              border: Border.all(
                                color: AppColors.ink,
                                width: 1.8,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: _AvatarFace(
                              avatarUrl: avatarUrl,
                              letter: avatarLetter,
                              compact: widget.compact,
                              letterColor: nameColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: _HudBadge(
                    text: '${player.score}',
                    minWidth: widget.compact ? 28 : 30,
                    backgroundColor: AppColors.cartoonCoral,
                    compact: widget.compact,
                  ),
                ),
                if (widget.isActive && widget.turnSecondsLeft != null)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: _HudBadge(
                      text: '${widget.turnSecondsLeft}',
                      minWidth: widget.compact ? 31 : 34,
                      backgroundColor: AppColors.lime,
                      compact: widget.compact,
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
                      ? 0
                      : null,
                  right: widget.giftPlacement == PlayerGiftPlacement.right
                      ? 0
                      : null,
                  top: widget.compact ? 25 : 29,
                  child: SizedBox(
                    width: 30,
                    height: 30,
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
          if (widget.showName) ...[
            const SizedBox(height: 2),
            Transform.rotate(
              angle: player.id.isEven ? -0.018 : 0.018,
              child: Container(
                constraints: const BoxConstraints(minWidth: 56),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isActive ? AppColors.lime : AppColors.cream,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: AppColors.ink,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.ink,
                      blurRadius: 0,
                      offset: Offset(2, 3),
                    ),
                  ],
                ),
                child: Text(
                  player.isMe
                      ? '${player.name} (${_isAzerbaijani ? 'Sən' : 'Ты'})'
                      : player.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: nameColor,
                    fontSize: 13.5,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvatarFace extends StatelessWidget {
  final String? avatarUrl;
  final String letter;
  final bool compact;
  final Color letterColor;

  const _AvatarFace({
    required this.avatarUrl,
    required this.letter,
    required this.compact,
    required this.letterColor,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = avatarUrl?.trim();

    Widget fallback() {
      return Container(
        alignment: Alignment.center,
        color: AppColors.cream,
        child: Text(
          letter,
          style: TextStyle(
            color: letterColor,
            fontSize: compact ? 21 : 23,
            fontWeight: FontWeight.w900,
            shadows: const [
              Shadow(
                color: Colors.white,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      );
    }

    if (normalizedUrl == null || normalizedUrl.isEmpty) {
      return fallback();
    }

    return Image.network(
      normalizedUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => fallback(),
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
    final fallbackName =
        context.appLanguage.code == 'az' ? 'Hədiyyə' : 'Подарок';

    return Tooltip(
      message:
          widget.name?.trim().isNotEmpty == true ? widget.name! : fallbackName,
      child: AnimatedBuilder(
        animation: _controller,
        child: SizedBox(
          width: 24,
          height: 24,
          child: widget.imageUrl?.trim().isNotEmpty == true
              ? Image.network(
                  widget.imageUrl!,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.card_giftcard_rounded,
                      color: AppColors.cartoonCoral,
                      size: 20,
                    );
                  },
                )
              : const Icon(
                  Icons.card_giftcard_rounded,
                  color: AppColors.cartoonCoral,
                  size: 20,
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
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.ink,
          width: 1.8,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            blurRadius: 0,
            offset: Offset(2, 2),
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
              color: AppColors.ink,
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
  final bool compact;

  const _HudBadge({
    required this.text,
    required this.minWidth,
    required this.backgroundColor,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 28 : 30,
      constraints: BoxConstraints(minWidth: minWidth),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.ink,
          width: 1.9,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            blurRadius: 0,
            offset: Offset(2, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.ink,
          fontSize: compact ? 11 : 11.5,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: AppColors.ink, width: 1),
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
