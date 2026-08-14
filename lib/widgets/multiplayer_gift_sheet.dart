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
      showDragHandle: true,
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
      heightFactor: 0.78,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isAzerbaijani ? 'Hədiyyə göndər' : 'Отправить подарок',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            Text(
              _isAzerbaijani
                  ? 'Bir və ya bir neçə başqa oyunçu seçin.'
                  : 'Выбери одного или нескольких других игроков.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Text(
              _isAzerbaijani ? 'Qəbul edənlər' : 'Получатели',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final player in recipients)
                  FilterChip(
                    selected: _recipientIds.contains(player.id),
                    onSelected: (_) => _toggleRecipient(player.id),
                    avatar: CircleAvatar(
                      child: Text(
                        player.name.trim().isEmpty
                            ? '?'
                            : player.name.trim()[0].toUpperCase(),
                      ),
                    ),
                    label: Text(player.name),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr('restaurant_gifts'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  _isAzerbaijani ? 'ödənişsiz · test' : 'без оплаты · тест',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildGiftList()),
            if (selectedGift != null && _recipientIds.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                missing == 0
                    ? (_isAzerbaijani
                        ? 'Göndərməyə hazırdır: ${selectedGift.giftableCount} əd.'
                        : 'Готово к отправке: ${selectedGift.giftableCount} шт.')
                    : (_isAzerbaijani
                        ? 'Daha $missing əd. «${selectedGift.name}» lazımdır. Onlar avtomatik əlavə ediləcək.'
                        : 'Нужно ещё $missing шт. «${selectedGift.name}». Они будут добавлены автоматически.'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: canContinue && !_isPreparingGift ? _submit : null,
                icon: _isPreparingGift
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        missing > 0
                            ? Icons.add_shopping_cart_rounded
                            : Icons.card_giftcard_rounded,
                      ),
                label: Text(
                  missing > 0
                      ? (_isAzerbaijani
                          ? '$missing əlavə et və göndər'
                          : 'Добавить $missing и отправить')
                      : _recipientIds.length <= 1
                          ? (_isAzerbaijani
                              ? 'Hədiyyəni göndər'
                              : 'Отправить подарок')
                          : (_isAzerbaijani
                              ? '${_recipientIds.length} hədiyyə göndər'
                              : 'Отправить ${_recipientIds.length} подарка'),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _loadCatalog,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('retry')),
            ),
          ],
        ),
      );
    }

    if (_gifts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            context.tr('gift_shop_empty'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: _gifts.length,
      itemBuilder: (context, index) {
        final gift = _gifts[index];
        final selected = _selectedGiftId == gift.id;

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            setState(() {
              _selectedGiftId = gift.id;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: gift.imageUrl?.trim().isNotEmpty == true
                        ? Image.network(
                            gift.imageUrl!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.card_giftcard_rounded, size: 44),
                          )
                        : const Icon(Icons.card_giftcard_rounded, size: 44),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  gift.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  gift.price,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  _isAzerbaijani
                      ? 'var ${gift.giftableCount}'
                      : 'есть ${gift.giftableCount}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
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
