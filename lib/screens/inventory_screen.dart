import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../localization/app_localizations.dart';
import '../models/gift.dart';
import '../services/api_service.dart';
import '../services/gift_service.dart';
import '../widgets/cartoon_page_background.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  static const GiftService _giftService = GiftService();

  bool _isLoading = true;
  String? _errorMessage;
  List<InventoryGift> _items = const [];

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
      final items = await _giftService.fetchInventory();
      if (!mounted) return;
      setState(() {
        _items = items;
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
        _errorMessage = context.tr('inventory_load_failed');
        _isLoading = false;
      });
    }
  }

  Future<void> _showGift(InventoryGift item) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (context) => _InventoryGiftDetails(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CartoonPageBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('received_gifts'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black54,
                              offset: Offset(0, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                      ),
                    ),
                    _CartoonIconButton(
                      onTap: _isLoading ? null : _load,
                      icon: Icons.refresh_rounded,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: _InventoryPalette.ink,
                  backgroundColor: _InventoryPalette.cream,
                  onRefresh: _load,
                  child: _buildBody(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 250),
          Center(
            child: CircularProgressIndicator(
              color: _InventoryPalette.ink,
              strokeWidth: 3,
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(26, 120, 26, 140),
        children: [
          const _InventoryStateIcon(
            icon: Icons.cloud_off_rounded,
            accent: _InventoryPalette.coral,
          ),
          const SizedBox(height: 20),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(0, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: _CartoonButton(
              onTap: _load,
              color: _InventoryPalette.yellow,
              icon: Icons.refresh_rounded,
              label: context.tr('retry'),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 100, 28, 140),
        children: [
          const _EmptyGiftBox(),
          const SizedBox(height: 22),
          Text(
            context.tr('received_gifts_empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  offset: Offset(0, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          Text(
            context.tr('received_gifts_empty_description'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w700,
              shadows: [
                Shadow(
                  color: Colors.black45,
                  offset: Offset(0, 1),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 124),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _CartoonGiftCard(
          item: item,
          colorIndex: index,
          onTap: () => _showGift(item),
        );
      },
    );
  }
}

class _CartoonGiftCard extends StatefulWidget {
  final InventoryGift item;
  final int colorIndex;
  final VoidCallback onTap;

  const _CartoonGiftCard({
    required this.item,
    required this.colorIndex,
    required this.onTap,
  });

  @override
  State<_CartoonGiftCard> createState() => _CartoonGiftCardState();
}

class _CartoonGiftCardState extends State<_CartoonGiftCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final gift = item.gift;
    final redeemed = item.status == 'redeemed';
    final cardColor = _InventoryPalette.cardColor(widget.colorIndex);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          constraints: const BoxConstraints(minHeight: 138),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _InventoryPalette.ink,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x77000000),
                blurRadius: 0,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _GiftArtworkBox(
                imageUrl: gift.imageUrl,
                size: 76,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _GiftInfo(item: item),
              ),
              const SizedBox(width: 10),
              _QrPanel(
                qrCode: item.qrCode,
                redeemed: redeemed,
                status: context.tr(
                  redeemed ? 'gift_redeemed' : 'gift_available',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GiftInfo extends StatelessWidget {
  final InventoryGift item;

  const _GiftInfo({required this.item});

  @override
  Widget build(BuildContext context) {
    final gift = item.gift;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          gift.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _InventoryPalette.ink,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.restaurant_rounded,
              size: 14,
              color: _InventoryPalette.ink,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                gift.restaurantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _InventoryPalette.inkSoft,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          context.tr(
            'gift_from',
            arguments: {'name': item.senderLabel},
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _InventoryPalette.ink,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (item.giftedAt != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _InventoryPalette.cream,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: _InventoryPalette.ink,
                width: 2,
              ),
            ),
            child: Text(
              _formatDate(item.giftedAt!),
              style: const TextStyle(
                color: _InventoryPalette.ink,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _QrPanel extends StatelessWidget {
  final String qrCode;
  final bool redeemed;
  final String status;

  const _QrPanel({
    required this.qrCode,
    required this.redeemed,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: redeemed ? 0.45 : 1,
            child: Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: _InventoryPalette.ink,
                  width: 3,
                ),
              ),
              child: QrImageView(
                data: qrCode,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: _InventoryPalette.ink,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: _InventoryPalette.ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
            decoration: BoxDecoration(
              color: redeemed
                  ? _InventoryPalette.gray
                  : _InventoryPalette.lime,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: _InventoryPalette.ink,
                width: 2,
              ),
            ),
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _InventoryPalette.ink,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftArtworkBox extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _GiftArtworkBox({
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: _InventoryPalette.cream,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _InventoryPalette.ink,
          width: 3,
        ),
      ),
      child: imageUrl?.trim().isNotEmpty == true
          ? Image.network(
              imageUrl!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) =>
                  const _GiftFallback(),
            )
          : const _GiftFallback(),
    );
  }
}

class _GiftFallback extends StatelessWidget {
  const _GiftFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.card_giftcard_rounded,
      color: _InventoryPalette.ink,
      size: 42,
    );
  }
}

class _InventoryGiftDetails extends StatelessWidget {
  final InventoryGift item;

  const _InventoryGiftDetails({required this.item});

  @override
  Widget build(BuildContext context) {
    final gift = item.gift;
    final redeemed = item.status == 'redeemed';

    return FractionallySizedBox(
      heightFactor: 0.80,
      child: Container(
        decoration: const BoxDecoration(
          color: _InventoryPalette.yellow,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(
            top: BorderSide(
              color: _InventoryPalette.ink,
              width: 3,
            ),
            left: BorderSide(
              color: _InventoryPalette.ink,
              width: 3,
            ),
            right: BorderSide(
              color: _InventoryPalette.ink,
              width: 3,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 56,
                height: 6,
                decoration: BoxDecoration(
                  color: _InventoryPalette.ink,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _InventoryPalette.skyBlue,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(
                            color: _InventoryPalette.ink,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x77000000),
                              blurRadius: 0,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            _GiftArtworkBox(
                              imageUrl: gift.imageUrl,
                              size: 112,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              gift.name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _InventoryPalette.ink,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              gift.restaurantName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _InventoryPalette.inkSoft,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _InventoryPalette.ink,
                                  width: 3,
                                ),
                              ),
                              child: Opacity(
                                opacity: redeemed ? 0.45 : 1,
                                child: QrImageView(
                                  data: item.qrCode,
                                  size: 190,
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: _InventoryPalette.ink,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: _InventoryPalette.ink,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: redeemed
                                    ? _InventoryPalette.gray
                                    : _InventoryPalette.lime,
                                borderRadius: BorderRadius.circular(99),
                                border: Border.all(
                                  color: _InventoryPalette.ink,
                                  width: 2.5,
                                ),
                              ),
                              child: Text(
                                context.tr(
                                  redeemed
                                      ? 'gift_redeemed'
                                      : 'gift_available',
                                ),
                                style: const TextStyle(
                                  color: _InventoryPalette.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _InventoryPalette.cream,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _InventoryPalette.ink,
                            width: 3,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              color: _InventoryPalette.ink,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr(
                                  'gift_from',
                                  arguments: {'name': item.senderLabel},
                                ),
                                style: const TextStyle(
                                  color: _InventoryPalette.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (item.giftedAt != null)
                              Text(
                                _formatDate(item.giftedAt!),
                                style: const TextStyle(
                                  color: _InventoryPalette.inkSoft,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        context.tr(
                          redeemed
                              ? 'gift_redeemed_description'
                              : 'gift_qr_description',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _InventoryPalette.ink,
                          fontSize: 12.5,
                          height: 1.45,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

class _CartoonIconButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;

  const _CartoonIconButton({
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _InventoryPalette.cream,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _InventoryPalette.ink,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x77000000),
                blurRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: _InventoryPalette.ink,
            size: 25,
          ),
        ),
      ),
    );
  }
}

class _CartoonButton extends StatelessWidget {
  final Future<void> Function() onTap;
  final Color color;
  final IconData icon;
  final String label;

  const _CartoonButton({
    required this.onTap,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _InventoryPalette.ink,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77000000),
              blurRadius: 0,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _InventoryPalette.ink),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: _InventoryPalette.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryStateIcon extends StatelessWidget {
  final IconData icon;
  final Color accent;

  const _InventoryStateIcon({
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: accent,
          border: Border.all(
            color: _InventoryPalette.ink,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77000000),
              blurRadius: 0,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: _InventoryPalette.ink,
          size: 42,
        ),
      ),
    );
  }
}

class _EmptyGiftBox extends StatelessWidget {
  const _EmptyGiftBox();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 138,
        height: 118,
        decoration: BoxDecoration(
          color: _InventoryPalette.yellow,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: _InventoryPalette.ink,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77000000),
              blurRadius: 0,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: const Icon(
          Icons.card_giftcard_rounded,
          size: 66,
          color: _InventoryPalette.ink,
        ),
      ),
    );
  }
}

class _InventoryPalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF3F3F3F);
  static const Color cream = Color(0xFFFFF7E6);
  static const Color yellow = Color(0xFFFFD65A);
  static const Color skyBlue = Color(0xFF72CEF2);
  static const Color mint = Color(0xFF88D978);
  static const Color coral = Color(0xFFFF7E70);
  static const Color lavender = Color(0xFFCDB7FF);
  static const Color lime = Color(0xFF7CFC00);
  static const Color gray = Color(0xFFD8D8D8);

  static Color cardColor(int index) {
    const colors = [
      skyBlue,
      yellow,
      mint,
      coral,
      lavender,
    ];
    return colors[index % colors.length];
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}
