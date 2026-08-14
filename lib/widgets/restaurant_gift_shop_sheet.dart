import 'package:flutter/material.dart';

import '../models/gift.dart';
import '../services/api_service.dart';
import '../services/gift_service.dart';

class RestaurantGiftShopSheet extends StatefulWidget {
  final int restaurantId;
  final String restaurantName;

  const RestaurantGiftShopSheet({
    super.key,
    required this.restaurantId,
    required this.restaurantName,
  });

  static Future<void> show(
    BuildContext context, {
    required int restaurantId,
    required String restaurantName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => RestaurantGiftShopSheet(
        restaurantId: restaurantId,
        restaurantName: restaurantName,
      ),
    );
  }

  @override
  State<RestaurantGiftShopSheet> createState() =>
      _RestaurantGiftShopSheetState();
}

class _RestaurantGiftShopSheetState extends State<RestaurantGiftShopSheet> {
  static const GiftService _giftService = GiftService();

  bool _isLoading = true;
  String? _errorMessage;
  int? _buyingGiftId;
  List<Gift> _gifts = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final gifts = await _giftService.fetchRestaurantGifts(widget.restaurantId);
      if (!mounted) return;
      setState(() {
        _gifts = gifts;
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
        _errorMessage = 'Не удалось загрузить подарки ресторана.';
        _isLoading = false;
      });
    }
  }

  Future<void> _buy(Gift gift) async {
    if (_buyingGiftId != null) return;

    setState(() {
      _buyingGiftId = gift.id;
    });

    try {
      final count = await _giftService.purchaseGift(
        restaurantId: widget.restaurantId,
        giftId: gift.id,
      );
      if (!mounted) return;

      setState(() {
        _gifts = _gifts
            .map(
              (item) => item.id == gift.id
                  ? item.copyWith(giftableCount: count)
                  : item,
            )
            .toList(growable: false);
      });

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '«${gift.name}» добавлен для дарения. Доступно: $count.',
            ),
          ),
        );
    } on ApiException catch (error) {
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage('Не удалось добавить подарок.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _buyingGiftId = null;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Подарки · ${widget.restaurantName}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              'Подготовь подарки заранее или добавь их прямо во время игры. '
              'В Инвентаре они не показываются — там хранятся только подарки, '
              'которые подарили тебе.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 7),
            Text(
              'Тестовый режим: оплата пока не списывается.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildBody()),
            const SizedBox(height: 12),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Готово'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_gifts.isEmpty) {
      return const Center(
        child: Text(
          'У этого ресторана пока нет активных подарков.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemCount: _gifts.length,
      itemBuilder: (context, index) {
        final gift = _gifts[index];
        final isBuying = _buyingGiftId == gift.id;

        return _GiftShopCard(
          gift: gift,
          isBuying: isBuying,
          onBuy: () => _buy(gift),
        );
      },
    );
  }
}

class _GiftShopCard extends StatelessWidget {
  final Gift gift;
  final bool isBuying;
  final VoidCallback onBuy;

  const _GiftShopCard({
    required this.gift,
    required this.isBuying,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
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
                          const Icon(Icons.card_giftcard_rounded, size: 54),
                    )
                  : const Icon(Icons.card_giftcard_rounded, size: 54),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            gift.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            '${gift.price} · для дарения: ${gift.giftableCount}',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: FilledButton.tonalIcon(
              onPressed: isBuying ? null : onBuy,
              icon: isBuying
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: const Text('Добавить'),
            ),
          ),
        ],
      ),
    );
  }
}
