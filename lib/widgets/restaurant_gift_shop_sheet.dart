import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
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
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
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
      if (mounted) {
        _showMessage(error.message);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context.tr('gift_add_failed'));
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
    return FractionallySizedBox(
      heightFactor: 0.90,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _GiftShopPalette.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
            border: Border(
              top: BorderSide(color: _GiftShopPalette.ink, width: 3),
              left: BorderSide(color: _GiftShopPalette.ink, width: 3),
              right: BorderSide(color: _GiftShopPalette.ink, width: 3),
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
                        color: _GiftShopPalette.ink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 17),
                  _GiftShopHeader(
                    restaurantName: widget.restaurantName,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                    decoration: BoxDecoration(
                      color: _GiftShopPalette.paper,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: _GiftShopPalette.ink,
                        width: 2.5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: _GiftShopPalette.ink,
                          blurRadius: 0,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          context.tr('gift_shop_description'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _GiftShopPalette.inkSoft,
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 9),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _GiftShopPalette.mint,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: _GiftShopPalette.ink,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            context.tr('gift_shop_test_mode'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _GiftShopPalette.ink,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(child: _buildBody()),
                  const SizedBox(height: 12),
                  _CartoonBottomButton(
                    label: context.tr('done'),
                    icon: Icons.check_circle_rounded,
                    color: _GiftShopPalette.lime,
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
          color: _GiftShopPalette.ink,
          strokeWidth: 3,
        ),
      );
    }

    if (_errorMessage != null) {
      return _GiftShopMessage(
        color: _GiftShopPalette.coral,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 42,
              color: _GiftShopPalette.ink,
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _GiftShopPalette.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            _SmallCartoonButton(
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
        color: _GiftShopPalette.skyBlue,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.card_giftcard_rounded,
              size: 44,
              color: _GiftShopPalette.ink,
            ),
            const SizedBox(height: 10),
            Text(
              context.tr('gift_shop_empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _GiftShopPalette.ink,
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
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.76,
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
        Transform.rotate(
          angle: -0.08,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: _GiftShopPalette.yellow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _GiftShopPalette.ink, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: _GiftShopPalette.ink,
                  blurRadius: 0,
                  offset: Offset(3, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: _GiftShopPalette.ink,
              size: 28,
            ),
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
              color: _GiftShopPalette.ink,
              fontSize: 23,
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onClose,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _GiftShopPalette.coral,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _GiftShopPalette.ink, width: 2.6),
              boxShadow: const [
                BoxShadow(
                  color: _GiftShopPalette.ink,
                  blurRadius: 0,
                  offset: Offset(2, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.close_rounded,
              color: _GiftShopPalette.ink,
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

  Color get _cardColor {
    const colors = [
      _GiftShopPalette.skyBlue,
      _GiftShopPalette.yellow,
      _GiftShopPalette.mint,
      _GiftShopPalette.coral,
      _GiftShopPalette.lavender,
    ];
    return colors[gift.id.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _GiftShopPalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _GiftShopPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 6),
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
                color: _GiftShopPalette.paper,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _GiftShopPalette.ink, width: 2.4),
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
                          color: _GiftShopPalette.ink,
                        ),
                      )
                    : const Icon(
                        Icons.card_giftcard_rounded,
                        size: 52,
                        color: _GiftShopPalette.ink,
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
              color: _GiftShopPalette.ink,
              fontSize: 15.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _GiftShopPalette.ink, width: 1.8),
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
                color: _GiftShopPalette.inkSoft,
                fontSize: 11,
                height: 1.15,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 9),
          GestureDetector(
            onTap: isBuying ? null : onBuy,
            child: Opacity(
              opacity: isBuying ? 0.65 : 1,
              child: Container(
                width: double.infinity,
                height: 42,
                decoration: BoxDecoration(
                  color: _GiftShopPalette.lime,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _GiftShopPalette.ink, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: _GiftShopPalette.ink,
                      blurRadius: 0,
                      offset: Offset(0, 4),
                    ),
                  ],
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
                          color: _GiftShopPalette.ink,
                        ),
                      )
                    else
                      const Icon(
                        Icons.add_shopping_cart_rounded,
                        color: _GiftShopPalette.ink,
                        size: 19,
                      ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        context.tr('add'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _GiftShopPalette.ink,
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
  final Color color;

  const _GiftShopMessage({
    required this.child,
    this.color = _GiftShopPalette.paper,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _GiftShopPalette.ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: _GiftShopPalette.ink,
              blurRadius: 0,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _SmallCartoonButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SmallCartoonButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _GiftShopPalette.lime,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _GiftShopPalette.ink, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: _GiftShopPalette.ink,
              blurRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _GiftShopPalette.ink, size: 19),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: _GiftShopPalette.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartoonBottomButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CartoonBottomButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(color: _GiftShopPalette.ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: _GiftShopPalette.ink,
              blurRadius: 0,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _GiftShopPalette.ink, size: 23),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: _GiftShopPalette.ink,
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
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF574C42);
  static const Color cream = Color(0xFFFFE8B6);
  static const Color paper = Color(0xFFFFF8E8);
  static const Color lime = Color(0xFF7CFC00);
  static const Color yellow = Color(0xFFFFD65C);
  static const Color skyBlue = Color(0xFF79CDF1);
  static const Color mint = Color(0xFF8CDD79);
  static const Color coral = Color(0xFFFF8A79);
  static const Color lavender = Color(0xFFC7A7FF);
}
