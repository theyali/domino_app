import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../localization/app_localizations.dart';
import '../models/gift.dart';
import '../services/api_service.dart';
import '../services/gift_service.dart';
import '../theme/app_colors.dart';

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
      barrierColor: Colors.black.withValues(alpha: 0.76),
      builder: (context) => _InventoryGiftDetails(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(
          context.tr('received_gifts'),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            tooltip: context.tr('refresh'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.lime,
        backgroundColor: AppColors.surfaceRaised,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 280),
          Center(
            child: CircularProgressIndicator(color: AppColors.lime),
          ),
        ],
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 150),
          const _InventoryStateIcon(
            icon: Icons.cloud_off_rounded,
            accent: Color(0xFFFF655B),
          ),
          const SizedBox(height: 18),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.ink,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                context.tr('retry'),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(28, 120, 28, 140),
        children: [
          const _EmptyGiftChest(),
          const SizedBox(height: 22),
          Text(
            context.tr('received_gifts_empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            context.tr('received_gifts_empty_description'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 124),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _VoucherGiftCard(
          item: item,
          onTap: () => _showGift(item),
        );
      },
    );
  }
}

class _VoucherGiftCard extends StatefulWidget {
  final InventoryGift item;
  final VoidCallback onTap;

  const _VoucherGiftCard({
    required this.item,
    required this.onTap,
  });

  @override
  State<_VoucherGiftCard> createState() => _VoucherGiftCardState();
}

class _VoucherGiftCardState extends State<_VoucherGiftCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final gift = item.gift;
    final redeemed = item.status == 'redeemed';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.982 : 1,
        duration: const Duration(milliseconds: 105),
        curve: Curves.easeOut,
        child: Container(
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 15,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: AspectRatio(
            aspectRatio: 2.62,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/texture/voucher.png',
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 13, 15, 13),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 76,
                        child: Row(
                          children: [
                            _GiftArtwork(
                              imageUrl: gift.imageUrl,
                              size: 72,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _VoucherGiftInfo(
                                item: item,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 24,
                        child: _VoucherQrStub(
                          qrCode: item.qrCode,
                          redeemed: redeemed,
                          status: context.tr(
                            redeemed ? 'gift_redeemed' : 'gift_available',
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
      ),
    );
  }
}

class _VoucherGiftInfo extends StatelessWidget {
  final InventoryGift item;

  const _VoucherGiftInfo({required this.item});

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
            color: Color(0xFF18211D),
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.25,
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            const Icon(
              Icons.restaurant_rounded,
              size: 13,
              color: Color(0xFF9A6726),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                gift.restaurantName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF5E625E),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.tr(
            'gift_from',
            arguments: {'name': item.senderLabel},
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF242A27),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (item.giftedAt != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1D2C25).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              _formatDate(item.giftedAt!),
              style: const TextStyle(
                color: Color(0xFF6A6D69),
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _VoucherQrStub extends StatelessWidget {
  final String qrCode;
  final bool redeemed;
  final String status;

  const _VoucherQrStub({
    required this.qrCode,
    required this.redeemed,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final accent = redeemed ? const Color(0xFF8B7350) : const Color(0xFF4E7E24);

    return LayoutBuilder(
      builder: (context, constraints) {
        final qrSize = constraints.maxHeight * 0.42;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: redeemed ? 0.42 : 1,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: const Color(0xFFC8943E),
                    width: 1.4,
                  ),
                ),
                child: QrImageView(
                  data: qrCode,
                  size: qrSize.clamp(40.0, 58.0).toDouble(),
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF171B19),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF171B19),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GiftArtwork extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _GiftArtwork({
    required this.imageUrl,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: imageUrl?.trim().isNotEmpty == true
            ? Image.network(
                imageUrl!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) =>
                    const _GiftFallback(),
              )
            : const _GiftFallback(),
      ),
    );
  }
}

class _GiftFallback extends StatelessWidget {
  const _GiftFallback();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.card_giftcard_rounded,
      color: Color(0xFF9A6726),
      size: 44,
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
      heightFactor: 0.82,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.panelTop, AppColors.background],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: AppColors.brass, width: 2),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 52,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.brass.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
                  child: Column(
                    children: [
                      _LargeVoucher(
                        item: item,
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.brass.withValues(alpha: 0.28),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.person_rounded,
                              color: AppColors.brassLight,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                context.tr(
                                  'gift_from',
                                  arguments: {'name': item.senderLabel},
                                ),
                                style: const TextStyle(
                                  color: AppColors.cream,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (item.giftedAt != null)
                              Text(
                                _formatDate(item.giftedAt!),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        context.tr(
                          redeemed
                              ? 'gift_redeemed_description'
                              : 'gift_qr_description',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        gift.restaurantName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.brassLight,
                          fontSize: 13,
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

class _LargeVoucher extends StatelessWidget {
  final InventoryGift item;

  const _LargeVoucher({required this.item});

  @override
  Widget build(BuildContext context) {
    final gift = item.gift;
    final redeemed = item.status == 'redeemed';

    return Container(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: AspectRatio(
        aspectRatio: 2.25,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/texture/voucher.png',
              fit: BoxFit.fill,
              filterQuality: FilterQuality.high,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(21, 17, 18, 17),
              child: Row(
                children: [
                  Expanded(
                    flex: 75,
                    child: Row(
                      children: [
                        _GiftArtwork(
                          imageUrl: gift.imageUrl,
                          size: 92,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                gift.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF18211D),
                                  fontSize: 21,
                                  fontWeight: FontWeight.w900,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                gift.restaurantName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF62645F),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 25,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final qrSize = constraints.maxWidth * 0.72;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Opacity(
                              opacity: redeemed ? 0.42 : 1,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: const Color(0xFFC8943E),
                                    width: 1.6,
                                  ),
                                ),
                                child: QrImageView(
                                  data: item.qrCode,
                                  size: qrSize.clamp(54.0, 82.0).toDouble(),
                                  padding: EdgeInsets.zero,
                                  backgroundColor: Colors.white,
                                  eyeStyle: const QrEyeStyle(
                                    eyeShape: QrEyeShape.square,
                                    color: Color(0xFF171B19),
                                  ),
                                  dataModuleStyle: const QrDataModuleStyle(
                                    dataModuleShape: QrDataModuleShape.square,
                                    color: Color(0xFF171B19),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              context.tr(
                                redeemed ? 'gift_redeemed' : 'gift_available',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: redeemed
                                    ? const Color(0xFF8B7350)
                                    : const Color(0xFF4E7E24),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
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
        width: 82,
        height: 82,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceRaised,
          border: Border.all(color: AppColors.brass, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black38,
              blurRadius: 13,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Icon(icon, color: accent, size: 42),
      ),
    );
  }
}

class _EmptyGiftChest extends StatelessWidget {
  const _EmptyGiftChest();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 140,
        height: 120,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 7,
              child: Container(
                width: 120,
                height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.rackWoodLight,
                      AppColors.rackWoodDark,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.brass, width: 2.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 15,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 15,
              child: Transform.rotate(
                angle: -0.10,
                child: Container(
                  width: 106,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.rackWoodLight, AppColors.rackWood],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.brass, width: 2.5),
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 28,
              child: Icon(
                Icons.card_giftcard_rounded,
                size: 42,
                color: AppColors.lime,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day.$month.${local.year}';
}
