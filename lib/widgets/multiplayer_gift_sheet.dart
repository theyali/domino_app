import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/gift.dart';
import '../models/multiplayer_game_state.dart';
import '../services/api_service.dart';
import '../services/gift_service.dart';

class GiftSendRequest {
  final int giftId;
  final List<int> recipientPlayerIds;

  const GiftSendRequest({
    required this.giftId,
    required this.recipientPlayerIds,
  });
}

class MultiplayerGiftSheet extends StatefulWidget {
  final int restaurantId;
  final int myPlayerId;
  final int initialRecipientPlayerId;
  final List<MultiplayerPlayerState> players;

  const MultiplayerGiftSheet({
    super.key,
    required this.restaurantId,
    required this.myPlayerId,
    required this.initialRecipientPlayerId,
    required this.players,
  });

  static Future<GiftSendRequest?> show(
    BuildContext context, {
    required int restaurantId,
    required int myPlayerId,
    required int initialRecipientPlayerId,
    required List<MultiplayerPlayerState> players,
  }) {
    return showModalBottomSheet<GiftSendRequest>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      builder: (context) => MultiplayerGiftSheet(
        restaurantId: restaurantId,
        myPlayerId: myPlayerId,
        initialRecipientPlayerId: initialRecipientPlayerId,
        players: players,
      ),
    );
  }

  @override
  State<MultiplayerGiftSheet> createState() => _MultiplayerGiftSheetState();
}

class _MultiplayerGiftSheetState extends State<MultiplayerGiftSheet> {
  static const GiftService _giftService = GiftService();

  bool _isLoading = true;
  bool _isPreparingGift = false;
  String? _errorMessage;
  List<Gift> _gifts = const [];
  int? _selectedGiftId;
  final Set<int> _recipientIds = <int>{};

  bool get _isAzerbaijani => context.appLanguage.code == 'az';

  @override
  void initState() {
    super.initState();

    for (final player in widget.players) {
      if (player.id == widget.initialRecipientPlayerId &&
          player.id != widget.myPlayerId &&
          player.isActive &&
          player.userId != null) {
        _recipientIds.add(player.id);
        break;
      }
    }

    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final gifts = await _giftService.fetchRestaurantGifts(widget.restaurantId);
      if (!mounted) return;

      setState(() {
        _gifts = gifts;
        _selectedGiftId = gifts.isEmpty ? null : gifts.first.id;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr('gift_shop_load_failed');
        _isLoading = false;
      });
    }
  }

  List<MultiplayerPlayerState> get _availableRecipients => widget.players
      .where(
        (player) =>
            player.id != widget.myPlayerId &&
            player.isActive &&
            player.userId != null,
      )
      .toList(growable: false);

  Gift? get _selectedGift {
    final selectedId = _selectedGiftId;
    if (selectedId == null) return null;

    for (final gift in _gifts) {
      if (gift.id == selectedId) return gift;
    }
    return null;
  }

  int get _missingCount {
    final gift = _selectedGift;
    if (gift == null || _recipientIds.isEmpty) return 0;
    final missing = _recipientIds.length - gift.giftableCount;
    return missing > 0 ? missing : 0;
  }

  void _toggleRecipient(int playerId) {
    if (playerId == widget.myPlayerId) return;

    setState(() {
      if (_recipientIds.contains(playerId)) {
        _recipientIds.remove(playerId);
      } else {
        _recipientIds.add(playerId);
      }
    });
  }

  Future<void> _submit() async {
    final gift = _selectedGift;
    if (gift == null || _recipientIds.isEmpty || _isPreparingGift) return;

    if (_recipientIds.contains(widget.myPlayerId)) {
      _recipientIds.remove(widget.myPlayerId);
      if (_recipientIds.isEmpty) return;
    }

    final missing = _missingCount;

    if (missing > 0) {
      setState(() {
        _isPreparingGift = true;
      });

      try {
        final newCount = await _giftService.purchaseGift(
          restaurantId: widget.restaurantId,
          giftId: gift.id,
          quantity: missing,
        );

        if (!mounted) return;
        setState(() {
          _gifts = _gifts
              .map(
                (item) => item.id == gift.id
                    ? item.copyWith(giftableCount: newCount)
                    : item,
              )
              .toList(growable: false);
        });
      } on ApiException catch (error) {
        if (mounted) _showMessage(error.message);
        return;
      } catch (_) {
        if (mounted) {
          _showMessage(
            _isAzerbaijani
                ? 'Hədiyyəni hazırlamaq mümkün olmadı.'
                : 'Не удалось подготовить подарок.',
          );
        }
        return;
      } finally {
        if (mounted) {
          setState(() {
            _isPreparingGift = false;
          });
        }
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(
      GiftSendRequest(
        giftId: gift.id,
        recipientPlayerIds: _recipientIds.toList(growable: false),
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final recipients = _availableRecipients;
    final selectedGift = _selectedGift;
    final canContinue = selectedGift != null && _recipientIds.isNotEmpty;
    final missing = _missingCount;

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _GiftPalette.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
            border: Border(
              top: BorderSide(color: _GiftPalette.ink, width: 3),
              left: BorderSide(color: _GiftPalette.ink, width: 3),
              right: BorderSide(color: _GiftPalette.ink, width: 3),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 54,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _GiftPalette.ink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.rotate(
                        angle: -0.06,
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: _GiftPalette.yellow,
                            borderRadius: BorderRadius.circular(17),
                            border: Border.all(
                              color: _GiftPalette.ink,
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: _GiftPalette.ink,
                                blurRadius: 0,
                                offset: Offset(3, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.card_giftcard_rounded,
                            color: _GiftPalette.ink,
                            size: 30,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isAzerbaijani
                                  ? 'Hədiyyə göndər'
                                  : 'Отправить подарок',
                              style: const TextStyle(
                                color: _GiftPalette.ink,
                                fontSize: 27,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              _isAzerbaijani
                                  ? 'Bir və ya bir neçə başqa oyunçu seçin.'
                                  : 'Выбери одного или нескольких других игроков.',
                              style: const TextStyle(
                                color: _GiftPalette.inkSoft,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 33,
                        height: 33,
                        decoration: BoxDecoration(
                          color: _GiftPalette.skyBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _GiftPalette.ink,
                            width: 2.3,
                          ),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: _GiftPalette.ink,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        _isAzerbaijani ? 'Qəbul edənlər' : 'Получатели',
                        style: const TextStyle(
                          color: _GiftPalette.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (recipients.isEmpty)
                    _InfoCard(
                      color: _GiftPalette.skyBlue,
                      text: _isAzerbaijani
                          ? 'Hədiyyə göndərmək üçün başqa oyunçu yoxdur.'
                          : 'Сейчас нет другого игрока, которому можно отправить подарок.',
                    )
                  else
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: [
                          for (var index = 0;
                              index < recipients.length;
                              index++) ...[
                            if (index != 0) const SizedBox(width: 9),
                            _RecipientChip(
                              player: recipients[index],
                              selected:
                                  _recipientIds.contains(recipients[index].id),
                              onTap: () => _toggleRecipient(recipients[index].id),
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 33,
                              height: 33,
                              decoration: BoxDecoration(
                                color: _GiftPalette.coral,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _GiftPalette.ink,
                                  width: 2.3,
                                ),
                              ),
                              child: const Icon(
                                Icons.redeem_rounded,
                                color: _GiftPalette.ink,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Flexible(
                              child: Text(
                                context.tr('restaurant_gifts'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _GiftPalette.ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _GiftPalette.mint,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: _GiftPalette.ink,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          _isAzerbaijani ? 'ödənişsiz · test' : 'без оплаты · тест',
                          style: const TextStyle(
                            color: _GiftPalette.ink,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Expanded(child: _buildGiftList()),
                  if (selectedGift != null && _recipientIds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _InfoCard(
                      color: missing == 0
                          ? _GiftPalette.mint
                          : _GiftPalette.yellow,
                      text: missing == 0
                          ? (_isAzerbaijani
                              ? 'Göndərməyə hazırdır: ${selectedGift.giftableCount} əd.'
                              : 'Готово к отправке: ${selectedGift.giftableCount} шт.')
                          : (_isAzerbaijani
                              ? 'Daha $missing əd. «${selectedGift.name}» lazımdır. Onlar avtomatik əlavə ediləcək.'
                              : 'Нужно ещё $missing шт. «${selectedGift.name}». Они будут добавлены автоматически.'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _CartoonSendButton(
                    enabled: canContinue && !_isPreparingGift,
                    loading: _isPreparingGift,
                    missing: missing,
                    recipientCount: _recipientIds.length,
                    isAzerbaijani: _isAzerbaijani,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGiftList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _GiftPalette.ink,
          strokeWidth: 3,
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _GiftPalette.coral,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _GiftPalette.ink, width: 2.8),
            boxShadow: const [
              BoxShadow(
                color: _GiftPalette.ink,
                blurRadius: 0,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _GiftPalette.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _loadCatalog,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _GiftPalette.paper,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _GiftPalette.ink,
                      width: 2.3,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        color: _GiftPalette.ink,
                        size: 19,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.tr('retry'),
                        style: const TextStyle(
                          color: _GiftPalette.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_gifts.isEmpty) {
      return Center(
        child: _InfoCard(
          color: _GiftPalette.skyBlue,
          text: context.tr('gift_shop_empty'),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 11,
        crossAxisSpacing: 11,
        childAspectRatio: 0.76,
      ),
      itemCount: _gifts.length,
      itemBuilder: (context, index) {
        final gift = _gifts[index];
        final selected = _selectedGiftId == gift.id;
        final color = selected
            ? _GiftPalette.lime
            : _giftCardColors[index % _giftCardColors.length];

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              _selectedGiftId = gift.id;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(0, selected ? -2 : 0, 0),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: _GiftPalette.ink,
                width: selected ? 3.2 : 2.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: _GiftPalette.ink,
                  blurRadius: 0,
                  offset: Offset(0, selected ? 6 : 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _GiftPalette.paper,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: _GiftPalette.ink,
                        width: 1.8,
                      ),
                    ),
                    child: Center(
                      child: gift.imageUrl?.trim().isNotEmpty == true
                          ? Image.network(
                              gift.imageUrl!,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                Icons.card_giftcard_rounded,
                                color: _GiftPalette.ink,
                                size: 42,
                              ),
                            )
                          : const Icon(
                              Icons.card_giftcard_rounded,
                              color: _GiftPalette.ink,
                              size: 42,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  gift.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _GiftPalette.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  gift.price,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _GiftPalette.inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _isAzerbaijani
                      ? 'var ${gift.giftableCount}'
                      : 'есть ${gift.giftableCount}',
                  style: const TextStyle(
                    color: _GiftPalette.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RecipientChip extends StatelessWidget {
  final MultiplayerPlayerState player;
  final bool selected;
  final VoidCallback onTap;

  const _RecipientChip({
    required this.player,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final trimmedName = player.name.trim();
    final letter = trimmedName.isEmpty ? '?' : trimmedName[0].toUpperCase();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.fromLTRB(7, 6, 11, 6),
        decoration: BoxDecoration(
          color: selected ? _GiftPalette.lime : _GiftPalette.paper,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: _GiftPalette.ink,
            width: selected ? 2.8 : 2.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: _GiftPalette.ink,
              blurRadius: 0,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 31,
              height: 31,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? _GiftPalette.mint : _GiftPalette.skyBlue,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _GiftPalette.ink,
                  width: 2,
                ),
              ),
              child: Text(
                letter,
                style: const TextStyle(
                  color: _GiftPalette.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 7),
            if (selected) ...[
              const Icon(
                Icons.check_circle_rounded,
                color: _GiftPalette.ink,
                size: 18,
              ),
              const SizedBox(width: 5),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: Text(
                player.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _GiftPalette.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Color color;
  final String text;

  const _InfoCard({
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _GiftPalette.ink,
          width: 2.2,
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _GiftPalette.ink,
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CartoonSendButton extends StatelessWidget {
  final bool enabled;
  final bool loading;
  final int missing;
  final int recipientCount;
  final bool isAzerbaijani;
  final VoidCallback onTap;

  const _CartoonSendButton({
    required this.enabled,
    required this.loading,
    required this.missing,
    required this.recipientCount,
    required this.isAzerbaijani,
    required this.onTap,
  });

  String get _label {
    if (missing > 0) {
      return isAzerbaijani
          ? '$missing əlavə et və göndər'
          : 'Добавить $missing и отправить';
    }
    if (recipientCount <= 1) {
      return isAzerbaijani ? 'Hədiyyəni göndər' : 'Отправить подарок';
    }
    return isAzerbaijani
        ? '$recipientCount hədiyyə göndər'
        : 'Отправить $recipientCount подарка';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: enabled || loading ? 1 : 0.45,
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: _GiftPalette.lime,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _GiftPalette.ink,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: _GiftPalette.ink,
                blurRadius: 0,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _GiftPalette.ink,
                  ),
                )
              else
                Icon(
                  missing > 0
                      ? Icons.add_shopping_cart_rounded
                      : Icons.card_giftcard_rounded,
                  color: _GiftPalette.ink,
                  size: 24,
                ),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  _label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _GiftPalette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _giftCardColors = <Color>[
  _GiftPalette.yellow,
  _GiftPalette.skyBlue,
  _GiftPalette.coral,
  _GiftPalette.mint,
  _GiftPalette.lavender,
];

class _GiftPalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF574C42);
  static const Color cream = Color(0xFFFFE8B6);
  static const Color paper = Color(0xFFFFF8E8);
  static const Color lime = Color(0xFF7CFC00);
  static const Color yellow = Color(0xFFFFD65C);
  static const Color skyBlue = Color(0xFF79CDF1);
  static const Color coral = Color(0xFFFF8A79);
  static const Color mint = Color(0xFF8CDD79);
  static const Color lavender = Color(0xFFC7A7FF);
}
