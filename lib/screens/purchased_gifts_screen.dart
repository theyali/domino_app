import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/gift.dart';
import '../services/api_service.dart';
import '../services/gift_service.dart';
import '../widgets/cartoon_page_background.dart';

class PurchasedGiftsScreen extends StatefulWidget {
  const PurchasedGiftsScreen({super.key});

  @override
  State<PurchasedGiftsScreen> createState() => _PurchasedGiftsScreenState();
}

class _PurchasedGiftsScreenState extends State<PurchasedGiftsScreen> {
  static const GiftService _giftService = GiftService();

  GiftPurchaseSummary? _summary;
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isAz => context.appLanguage.code == 'az';

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
      final summary = await _giftService.fetchPurchaseSummary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _isAz
            ? 'Alış tarixçəsini yükləmək mümkün olmadı.'
            : 'Не удалось загрузить историю покупок.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CartoonPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          toolbarHeight: 68,
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _TopButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.maybePop(context),
            ),
          ),
          title: Text(
            _isAz ? 'Alınmış hədiyyələr' : 'Купленные подарки',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  offset: Offset(2, 3),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
          actions: [
            _TopButton(
              icon: Icons.refresh_rounded,
              color: _Palette.sky,
              onTap: _isLoading ? null : _load,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: _Palette.ink,
            backgroundColor: _Palette.cream,
            onRefresh: _load,
            child: _body(),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading && _summary == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 220),
          Center(child: CircularProgressIndicator(color: _Palette.ink)),
        ],
      );
    }

    if (_errorMessage != null && _summary == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 40, 18, 40),
        children: [
          _Panel(
            color: _Palette.coral,
            child: Column(
              children: [
                const Icon(Icons.cloud_off_rounded, size: 42),
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: _Palette.ink,
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _load,
                  child: const _SmallButton(label: 'Повторить'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final summary = _summary ??
        const GiftPurchaseSummary(
          totalSpent: '0.00',
          availableCount: 0,
          ownedGifts: [],
          history: [],
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 42),
      children: [
        _SummaryCard(summary: summary, isAz: _isAz),
        const SizedBox(height: 20),
        _SectionTitle(
          icon: Icons.card_giftcard_rounded,
          label: _isAz ? 'Hazırda səndə olanlar' : 'Сейчас у тебя',
          color: _Palette.lime,
        ),
        const SizedBox(height: 11),
        if (summary.ownedGifts.isEmpty)
          _Panel(
            color: _Palette.cream,
            child: Text(
              _isAz
                  ? 'Hədiyyə etmək üçün alınmış hədiyyə qalmayıb.'
                  : 'Купленных подарков для отправки сейчас нет.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _Palette.inkSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        else
          ...summary.ownedGifts.map(
            (gift) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _OwnedGiftCard(gift: gift, isAz: _isAz),
            ),
          ),
        const SizedBox(height: 9),
        _SectionTitle(
          icon: Icons.receipt_long_rounded,
          label: _isAz ? 'Alış tarixçəsi' : 'История покупок',
          color: _Palette.yellow,
        ),
        const SizedBox(height: 11),
        if (summary.history.isEmpty)
          _Panel(
            color: _Palette.cream,
            child: Text(
              _isAz
                  ? 'Hələ heç bir hədiyyə almamısan.'
                  : 'Ты пока не покупал подарки.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _Palette.inkSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        else
          ...summary.history.map(
            (purchase) => Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _HistoryCard(purchase: purchase),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final GiftPurchaseSummary summary;
  final bool isAz;

  const _SummaryCard({required this.summary, required this.isAz});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: _Palette.sky,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAz ? 'Hədiyyə alışların' : 'Твои покупки подарков',
            style: const TextStyle(
              color: _Palette.ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isAz
                ? 'Nə vaxt və nəyə pul xərclədiyini burada görə bilərsən.'
                : 'Здесь видно, когда и на какие подарки ты тратился.',
            style: const TextStyle(
              color: _Palette.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: summary.totalSpent,
                  label: isAz ? 'Cəmi xərclənib' : 'Всего потрачено',
                  icon: Icons.payments_rounded,
                  color: _Palette.yellow,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _Metric(
                  value: '${summary.availableCount}',
                  label: isAz ? 'Hədiyyə etmək olar' : 'Можно подарить',
                  icon: Icons.inventory_2_rounded,
                  color: _Palette.lime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _Palette.ink, width: 2.5),
        boxShadow: const [
          BoxShadow(color: _Palette.ink, blurRadius: 0, offset: Offset(2, 3)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 21, color: _Palette.ink),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _Palette.ink,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _Palette.inkSoft,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnedGiftCard extends StatelessWidget {
  final Gift gift;
  final bool isAz;

  const _OwnedGiftCard({required this.gift, required this.isAz});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: _Palette.cream,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _GiftImage(gift: gift),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gift.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Palette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  gift.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Palette.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${gift.price} · ${isAz ? 'qalıb' : 'осталось'} ${gift.giftableCount}',
                  style: const TextStyle(
                    color: _Palette.inkSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: _Palette.lime,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _Palette.ink, width: 2.3),
            ),
            child: Text(
              '×${gift.giftableCount}',
              style: const TextStyle(
                color: _Palette.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final GiftPurchase purchase;

  const _HistoryCard({required this.purchase});

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: _Palette.paper,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _GiftImage(gift: purchase.gift, size: 56),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  purchase.gift.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Palette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  purchase.gift.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Palette.inkSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _date(purchase.purchasedAt),
                  style: const TextStyle(
                    color: _Palette.inkSoft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: _Palette.yellow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _Palette.ink, width: 2.1),
                ),
                child: Text(
                  purchase.totalPrice,
                  style: const TextStyle(
                    color: _Palette.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${purchase.quantity} × ${purchase.unitPrice}',
                style: const TextStyle(
                  color: _Palette.inkSoft,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _date(DateTime? value) {
    if (value == null) return '—';
    final date = value.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year} · '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _GiftImage extends StatelessWidget {
  final Gift gift;
  final double size;

  const _GiftImage({required this.gift, this.size = 62});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _Palette.ink, width: 2.4),
      ),
      child: gift.imageUrl?.trim().isNotEmpty == true
          ? Image.network(
              gift.imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.card_giftcard_rounded,
                color: _Palette.ink,
              ),
            )
          : const Icon(Icons.card_giftcard_rounded, color: _Palette.ink),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Palette.ink, width: 2.6),
          boxShadow: const [
            BoxShadow(color: _Palette.ink, blurRadius: 0, offset: Offset(2, 3)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _Palette.ink, size: 20),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: _Palette.ink,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Panel({
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.all(17),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _Palette.ink, width: 3),
        boxShadow: const [
          BoxShadow(color: _Palette.ink, blurRadius: 0, offset: Offset(0, 5)),
        ],
      ),
      child: child,
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;

  const _SmallButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
      decoration: BoxDecoration(
        color: _Palette.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.ink, width: 2.4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _Palette.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _TopButton({
    required this.icon,
    required this.onTap,
    this.color = _Palette.cream,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: 43,
          height: 43,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _Palette.ink, width: 2.7),
            boxShadow: const [
              BoxShadow(color: _Palette.ink, blurRadius: 0, offset: Offset(2, 3)),
            ],
          ),
          child: Icon(icon, color: _Palette.ink, size: 21),
        ),
      ),
    );
  }
}

class _Palette {
  static const ink = Color(0xFF111111);
  static const inkSoft = Color(0xFF51453C);
  static const cream = Color(0xFFFFF5D9);
  static const paper = Color(0xFFFFE8B6);
  static const sky = Color(0xFF79CDF1);
  static const yellow = Color(0xFFFFD65C);
  static const coral = Color(0xFFFF7E70);
  static const lime = Color(0xFF7CFC00);
}
