import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/gift.dart';
import '../services/api_service.dart';
import '../services/gift_service.dart';
import '../theme/play_palette.dart';

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
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.62),
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
        _errorMessage = context.tr('gift_shop_load_failed');
        _isLoading = false;
      });
    }
  }

  Future<void> _buy(Gift gift) async {
    if (_buyingGiftId != null) return;

    setState(() => _buyingGiftId = gift.id);

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
              context.tr(
                'gift_added',
                arguments: {
                  'gift': gift.name,
                  'count': count,
                },
              ),
            ),
          ),
        );
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage(context.tr('gift_add_failed'));
    } finally {
      if (mounted) setState(() => _buyingGiftId = null);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.90,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _GiftShopPalette.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(
              top: BorderSide(color: _GiftShopPalette.border),
              left: BorderSide(color: _GiftShopPalette.border),
              right: BorderSide(color: _GiftShopPalette.border),
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
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: _GiftShopPalette.handle,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _GiftShopHeader(
                    restaurantName: widget.restaurantName,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: PlayPalette.navy,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _GiftShopPalette.border),
                    ),
                    child: Column(
                      children: [
                        Text(
                          context.tr('gift_shop_description'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: PlayPalette.muted,
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D3C72),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF28559C),
                            ),
                          ),
                          child: Text(
                            context.tr('gift_shop_test_mode'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildBody()),
                  const SizedBox(height: 12),
                  _SiteBottomButton(
                    label: context.tr('done'),
                    icon: Icons.check_circle_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const _GiftShopMessage(
        child: CircularProgressIndicator(
          color: PlayPalette.blue,
          strokeWidth: 3,
        ),
      );
    }

    if (_errorMessage != null) {
      return _GiftShopMessage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: PlayPalette.coral,
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _SmallSiteButton(
              label: context.tr('retry'),
              icon: Icons.refresh_rounded,
              onTap: _load,
            ),
          ],
        ),
      );
    }

    if (_gifts.isEmpty) {
      return _GiftShopMessage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              size: 44,
              color: PlayPalette.blue,
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('gift_shop_empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(1, 1, 1, 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.76,
      ),
      itemCount: _gifts.length,
      itemBuilder: (context, index) {
        final gift = _gifts[index];
        return _GiftShopCard(
          gift: gift,
          isBuying: _buyingGiftId == gift.id,
          onBuy: () => _buy(gift),
        );
      },
    );
  }
}

class _GiftShopHeader extends StatelessWidget {
  final String restaurantName;
  final VoidCallback onClose;

  const _GiftShopHeader({
    required this.restaurantName,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: PlayPalette.blue,
            borderRadius: BorderRadius.circular(17),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 16,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: const Icon(
            Icons.card_giftcard_rounded,
            color: Colors.white,
            size: 27,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Text(
            context.tr(
              'gift_shop_title',
              arguments: {'restaurant': restaurantName},
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onClose,
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PlayPalette.navy,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _GiftShopPalette.border),
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ],
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
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      decoration: BoxDecoration(
        color: PlayPalette.navy,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _GiftShopPalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1B1D),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _GiftShopPalette.border),
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
                          size: 52,
                          color: PlayPalette.blue,
                        ),
                      )
                    : const Icon(
                        Icons.card_giftcard_rounded,
                        size: 52,
                        color: PlayPalette.blue,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Text(
            gift.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF323234),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              context.tr(
                'gift_price_count',
                arguments: {
                  'price': gift.price,
                  'count': gift.giftableCount,
                },
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: PlayPalette.muted,
                fontSize: 11,
                height: 1.15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 9),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isBuying ? null : onBuy,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 140),
              opacity: isBuying ? 0.62 : 1,
              child: Container(
                width: double.infinity,
                height: 42,
                decoration: BoxDecoration(
                  color: PlayPalette.blue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isBuying)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(
                        Icons.add_shopping_cart_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        context.tr('add'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftShopMessage extends StatelessWidget {
  final Widget child;

  const _GiftShopMessage({required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: PlayPalette.navy,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _GiftShopPalette.border),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _SmallSiteButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SmallSiteButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: PlayPalette.blue,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 19),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteBottomButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SiteBottomButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: PlayPalette.blue,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GiftShopPalette {
  static const Color background = Color(0xFF121212);
  static const Color border = Color(0xFF353538);
  static const Color handle = Color(0xFF55555A);
}
