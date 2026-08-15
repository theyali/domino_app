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
      barrierColor: Colors.black.withValues(alpha: 0.72),
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
          const _InventoryMessageIcon(
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
            child: _CartoonActionButton(
              onPressed: _load,
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 122),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 13),
      itemBuilder: (context, index) {
        final item = _items[index];
        return _ReceivedGiftCard(
          item: item,
          onTap: () => _showGift(item),
        );
      },
    );
  }
}

class _ReceivedGiftCard extends StatefulWidget {
  final InventoryGift item;
  final VoidCallback onTap;

  const _ReceivedGiftCard({required this.item, required this.onTap});

  @override
  State<_ReceivedGiftCard> createState() => _ReceivedGiftCardState();
}

class _ReceivedGiftCardState extends State<_ReceivedGiftCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final gift = item.gift;
    final redeemed = item.status == 'redeemed';
    final accent = redeemed ? AppColors.brass : AppColors.lime;

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
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          constraints: const BoxConstraints(minHeight: 154),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF23382E),
                Color(0xFF151F1B),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: AppColors.brass.withValues(alpha: 0.48),
              width: 1.35,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black45,
                blurRadius: 16,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                const Positioned(
                  top: -34,
                  left: -24,
                  child: _SoftCardDecoration(),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15, 17, 10, 17),
                      child: _GiftShowcase(
                        imageUrl: gift.imageUrl,
                        size: 92,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(3, 19, 9, 17),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gift.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.cream,
                                fontSize: 18.5,
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
                                  color: AppColors.brassLight,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    gift.restaurantName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 11),
                            Text(
                              context.tr(
                                'gift_from',
                                arguments: {'name': item.senderLabel},
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (item.giftedAt != null) ...[
                              const SizedBox(height: 5),
                              _DateChip(value: _formatDate(item.giftedAt!)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    _VoucherStub(
                      status: context.tr(
                        redeemed ? 'gift_redeemed' : 'gift_available',
                      ),
                      accent: accent,
                      redeemed: redeemed,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VoucherStub extends StatelessWidget {
  final String status;
  final Color accent;
  final bool redeemed;

  const _VoucherStub({
    required this.status,
    required this.accent,
    required this.redeemed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        border: const Border(
          left: BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -4,
            top: 13,
            bottom: 13,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(
                10,
                (index) => Container(
                  width: 2,
                  height: 5,
                  color: AppColors.brass.withValues(alpha: 0.42),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 17),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: AppColors.brass,
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black38,
                        blurRadius: 7,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    redeemed
                        ? Icons.check_circle_rounded
                        : Icons.qr_code_2_rounded,
                    color: AppColors.ink,
                    size: 31,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: accent,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
    final accent = redeemed ? AppColors.brass : AppColors.lime;

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.panelTop, AppColors.background],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
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
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                  child: Column(
                    children: [
                      _GiftShowcase(
                        imageUrl: gift.imageUrl,
                        size: 126,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        gift.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        gift.restaurantName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.brassLight,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _StatusRibbon(
                        text: context.tr(
                          redeemed ? 'gift_redeemed' : 'gift_available',
                        ),
                        color: accent,
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.17),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.brass.withValues(alpha: 0.2),
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
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (item.giftedAt != null)
                              Text(
                                _formatDate(item.giftedAt!),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _QrVoucher(
                        qrCode: item.qrCode,
                        redeemed: redeemed,
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
                          color: Colors.white54,
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
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

class _QrVoucher extends StatelessWidget {
  final String qrCode;
  final bool redeemed;

  const _QrVoucher({required this.qrCode, required this.redeemed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 264,
      padding: const EdgeInsets.fromLTRB(15, 15, 15, 16),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.brass, width: 2.3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 18,
            offset: Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const _VoucherHole(),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Divider(color: AppColors.brass, thickness: 1),
                ),
              ),
              const Icon(
                Icons.confirmation_number_rounded,
                color: AppColors.brassDark,
                size: 20,
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Divider(color: AppColors.brass, thickness: 1),
                ),
              ),
              const _VoucherHole(),
            ],
          ),
          const SizedBox(height: 10),
          Opacity(
            opacity: redeemed ? 0.42 : 1,
            child: QrImageView(
              data: qrCode,
              size: 210,
              backgroundColor: AppColors.cream,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppColors.ink,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftShowcase extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const _GiftShowcase({required this.imageUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.84,
            height: size * 0.84,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFFFE7A0), AppColors.brassDark],
              ),
              border: Border.all(
                color: AppColors.brassLight,
                width: 1.6,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 11,
                  offset: Offset(0, 6),
                ),
              ],
            ),
          ),
          SizedBox(
            width: size * 0.79,
            height: size * 0.79,
            child: Padding(
              padding: EdgeInsets.all(size * 0.08),
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
          ),
        ],
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
      color: AppColors.ink,
      size: 42,
    );
  }
}

class _StatusRibbon extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusRibbon({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String value;

  const _DateChip({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InventoryMessageIcon extends StatelessWidget {
  final IconData icon;
  final Color accent;

  const _InventoryMessageIcon({required this.icon, required this.accent});

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
            BoxShadow(color: Colors.black38, blurRadius: 13, offset: Offset(0, 7)),
          ],
        ),
        child: Icon(icon, color: accent, size: 42),
      ),
    );
  }
}

class _CartoonActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;

  const _CartoonActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.lime,
        foregroundColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
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
                    colors: [AppColors.rackWoodLight, AppColors.rackWoodDark],
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

class _SoftCardDecoration extends StatelessWidget {
  const _SoftCardDecoration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brass.withValues(alpha: 0.055),
      ),
    );
  }
}

class _VoucherHole extends StatelessWidget {
  const _VoucherHole();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brass,
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
