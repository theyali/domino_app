import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../localization/app_localizations.dart';
import '../models/gift.dart';
import '../services/api_service.dart';
import '../services/gift_service.dart';
import '../widgets/cartoon_page_background.dart';
import '../widgets/site_image_panel.dart';

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
      barrierColor: Colors.black.withValues(alpha: 0.72),
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
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('received_gifts'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.55,
                        ),
                      ),
                    ),
                    _SiteIconButton(
                      onTap: _isLoading ? null : _load,
                      icon: Icons.refresh_rounded,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: _InventoryPalette.blue,
                  backgroundColor: _InventoryPalette.surface,
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
              color: _InventoryPalette.blue,
              strokeWidth: 3,
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 92, 18, 140),
        children: [
          SiteImagePanel(
            assetPath: 'assets/ui/long_5.webp',
            overlayColor: const Color(0xC0121212),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            child: Column(
              children: [
                const _StateIcon(
                  icon: Icons.cloud_off_rounded,
                  color: _InventoryPalette.danger,
                ),
                const SizedBox(height: 18),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _SiteActionButton(
                  onTap: _load,
                  icon: Icons.refresh_rounded,
                  label: context.tr('retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 84, 18, 140),
        children: [
          SiteImagePanel(
            assetPath: 'assets/ui/long_5.webp',
            overlayColor: const Color(0xB8121212),
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
            child: Column(
              children: [
                const _StateIcon(
                  icon: Icons.card_giftcard_rounded,
                  color: _InventoryPalette.blue,
                ),
                const SizedBox(height: 20),
                Text(
                  context.tr('received_gifts_empty'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr('received_gifts_empty_description'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _InventoryPalette.muted,
                    fontSize: 13.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
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
      separatorBuilder: (context, index) => const SizedBox(height: 13),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _GiftCard(
          item: item,
          index: index,
          onTap: () => _showGift(item),
        );
      },
    );
  }
}

class _GiftCard extends StatefulWidget {
  final InventoryGift item;
  final int index;
  final VoidCallback onTap;

  const _GiftCard({
    required this.item,
    required this.index,
    required this.onTap,
  });

  @override
  State<_GiftCard> createState() => _GiftCardState();
}

class _GiftCardState extends State<_GiftCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final redeemed = item.status == 'redeemed';
    final assetIndex = (widget.index % 5) + 1;

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
        child: SiteImagePanel(
          assetPath: 'assets/ui/long_$assetIndex.webp',
          borderRadius: 24,
          overlayColor: redeemed
              ? const Color(0xD0121212)
              : const Color(0xA5121212),
          borderColor: redeemed
              ? const Color(0x2AFFFFFF)
              : const Color(0x55106CFF),
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              _GiftArtworkBox(
                imageUrl: item.gift.imageUrl,
                size: 78,
              ),
              const SizedBox(width: 13),
              Expanded(child: _GiftInfo(item: item)),
              const SizedBox(width: 9),
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
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(
              Icons.restaurant_rounded,
              size: 14,
              color: Colors.white,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                gift.restaurantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _InventoryPalette.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
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
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (item.giftedAt != null) ...[
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: _InventoryPalette.surfaceRaised,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _InventoryPalette.border),
            ),
            child: Text(
              _formatDate(item.giftedAt!),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
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
            opacity: redeemed ? 0.42 : 1,
            child: Container(
              width: 68,
              height: 68,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0x22000000)),
              ),
              child: QrImageView(
                data: qrCode,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: redeemed
                  ? _InventoryPalette.surfaceRaised
                  : _InventoryPalette.blue,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22000000)),
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
      color: _InventoryPalette.blue,
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
    final status = context.tr(
      redeemed ? 'gift_redeemed' : 'gift_available',
    );

    return FractionallySizedBox(
      heightFactor: 0.76,
      child: Container(
        decoration: const BoxDecoration(
          color: _InventoryPalette.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(
            top: BorderSide(color: _InventoryPalette.border),
            left: BorderSide(color: _InventoryPalette.border),
            right: BorderSide(color: _InventoryPalette.border),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: _InventoryPalette.muted,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      SiteImagePanel(
                        assetPath: 'assets/ui/long_2.webp',
                        borderRadius: 26,
                        overlayColor: const Color(0xB8121212),
                        borderColor: const Color(0x66106CFF),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _GiftArtworkBox(
                                  imageUrl: gift.imageUrl,
                                  size: 78,
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        gift.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 22,
                                          height: 1.05,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.restaurant_rounded,
                                            color: _InventoryPalette.muted,
                                            size: 15,
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              gift.restaurantName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: _InventoryPalette.muted,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 9),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: redeemed
                                                ? _InventoryPalette.surfaceRaised
                                                : _InventoryPalette.blue,
                                            borderRadius: BorderRadius.circular(99),
                                          ),
                                          child: Text(
                                            status,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            Opacity(
                              opacity: redeemed ? 0.42 : 1,
                              child: Container(
                                width: 184,
                                height: 184,
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: const Color(0x22000000),
                                  ),
                                ),
                                child: QrImageView(
                                  data: item.qrCode,
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Colors.black,
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xD9262628),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: _InventoryPalette.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _InventoryPalette.surfaceRaised,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      context.tr(
                                        'gift_from',
                                        arguments: {'name': item.senderLabel},
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (item.giftedAt != null) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatDate(item.giftedAt!),
                                      style: const TextStyle(
                                        color: _InventoryPalette.muted,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 13),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        decoration: BoxDecoration(
                          color: _InventoryPalette.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _InventoryPalette.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.qr_code_2_rounded,
                              color: _InventoryPalette.blue,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr(
                                  redeemed
                                      ? 'gift_redeemed_description'
                                      : 'gift_qr_description',
                                ),
                                style: const TextStyle(
                                  color: _InventoryPalette.muted,
                                  fontSize: 12.5,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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

class _SiteIconButton extends StatelessWidget {
  final Future<void> Function()? onTap;
  final IconData icon;

  const _SiteIconButton({
    required this.onTap,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.45 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null ? null : () => onTap!(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _InventoryPalette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _InventoryPalette.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _SiteActionButton extends StatelessWidget {
  final Future<void> Function() onTap;
  final IconData icon;
  final String label;

  const _SiteActionButton({
    required this.onTap,
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
          color: _InventoryPalette.blue,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
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

class _StateIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StateIcon({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: _InventoryPalette.surface,
        shape: BoxShape.circle,
        border: Border.all(color: _InventoryPalette.border),
      ),
      child: Icon(icon, color: color, size: 39),
    );
  }
}

abstract final class _InventoryPalette {
  static const background = Color(0xFF121212);
  static const surface = Color(0xFF262628);
  static const surfaceRaised = Color(0xFF303033);
  static const border = Color(0xFF3A3A3E);
  static const blue = Color(0xFF106CFF);
  static const muted = Color(0xFFA7A7AD);
  static const danger = Color(0xFFFF6F6F);
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}
