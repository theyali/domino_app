import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../localization/app_localizations.dart';
import '../models/gift.dart';
import '../services/api_service.dart';
import '../services/gift_service.dart';

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
      showDragHandle: true,
      builder: (context) => _InventoryGiftDetails(item: item),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('received_gifts')),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            tooltip: context.tr('refresh'),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
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
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_errorMessage != null && _items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 180),
          const Icon(Icons.cloud_off_rounded, size: 64),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.tr('retry')),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 180),
          Icon(
            Icons.card_giftcard_rounded,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 18),
          Text(
            context.tr('received_gifts_empty'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 9),
          Text(
            context.tr('received_gifts_empty_description'),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      itemCount: _items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
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

class _ReceivedGiftCard extends StatelessWidget {
  final InventoryGift item;
  final VoidCallback onTap;

  const _ReceivedGiftCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gift = item.gift;
    final redeemed = item.status == 'redeemed';

    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: gift.imageUrl?.trim().isNotEmpty == true
                    ? Image.network(
                        gift.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.card_giftcard_rounded, size: 46),
                      )
                    : const Icon(Icons.card_giftcard_rounded, size: 46),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gift.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      gift.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 7),
                    Text(
                      context.tr(
                        'gift_from',
                        arguments: {'name': item.senderLabel},
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (item.giftedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(item.giftedAt!),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Icon(
                    Icons.qr_code_2_rounded,
                    size: 34,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context.tr(
                      redeemed ? 'gift_redeemed' : 'gift_available',
                    ),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: redeemed
                          ? theme.colorScheme.outline
                          : theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryGiftDetails extends StatelessWidget {
  final InventoryGift item;

  const _InventoryGiftDetails({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gift = item.gift;
    final redeemed = item.status == 'redeemed';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(
        children: [
          Text(
            gift.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(gift.restaurantName, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 18),
          SizedBox(
            width: 110,
            height: 110,
            child: gift.imageUrl?.trim().isNotEmpty == true
                ? Image.network(
                    gift.imageUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.card_giftcard_rounded, size: 72),
                  )
                : const Icon(Icons.card_giftcard_rounded, size: 72),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr(
              'gift_from',
              arguments: {'name': item.senderLabel},
            ),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (item.giftedAt != null) ...[
            const SizedBox(height: 4),
            Text(_formatDate(item.giftedAt!)),
          ],
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: QrImageView(
              data: item.qrCode,
              size: 220,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.tr(
              redeemed
                  ? 'gift_redeemed_description'
                  : 'gift_qr_description',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
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
