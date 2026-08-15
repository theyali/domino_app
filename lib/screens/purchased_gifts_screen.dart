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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final summary = await _giftService.fetchPurchaseSummary();
      if (!mounted) return;
      setState(() {
        _summary = summary;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _isAz
            ? 'Alış tarixçəsini yükləmək mümkün olmadı.'
            : 'Не удалось загрузить историю покупок.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
              color: _PurchasePalette.skyBlue,
              onTap: _isLoading ? null : _load,
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: _PurchasePalette.ink,
            backgroundColor: _PurchasePalette.cream,
            onRefresh: _load,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _summary == null) {
      return const ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 220),
          Center(
            child: CircularProgressIndicator(color: _PurchasePalette.ink),
          ),
        ],
      );
    }

    if (_errorMessage != null && _summary == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 36, 18, 40),
        children: [
          _MessagePanel(
            icon: Icons.cloud_off_rounded,
            color: _PurchasePalette.coral,
            title: _isAz ? 'Yükləmək alınmadı' : 'Не удалось загрузить',
            text: _errorMessage!,
            buttonText: _isAz ? 'Yenidən' : 'Повторить',
            onTap: _load,
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
        _SummaryPanel(
          totalSpent: summary.totalSpent,
          availableCount: summary.availableCount,
          isAz: _isAz,
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          icon: Icons.card_giftcard_rounded,
          text: _isAz ? 'Hazırda səndə olanlar' : 'Сейчас у тебя',
          color: _PurchasePalette.lime,
        ),
        const SizedBox(height: 12),
        if (summary.ownedGifts.isEmpty)
          _SimplePanel(
            color: _PurchasePalette.cream,
            child: Text(
              _isAz
                  ? 'Hədiyyə üçün alınmış hədiyyə qalmayıb.'
                  : 'Купленных подарков для отправки сейчас нет.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _PurchasePalette.inkSoft,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          )
        else
          for (final gift in summary.ownedGifts) ...[
            _OwnedGiftCard(gift: gift, isAz: _isAz),
            const SizedBox(height: 11),
          ],
        const SizedBox(height: 9),
        _SectionTitle(
          icon: Icons.receipt_long_rounded,
          text: _isAz ? 'Alış tarixçəsi' : 'История покупок',
          color: _PurchasePalette.yellow,
        ),
        const SizedBox(height: 12),
        if (summary.history.isEmpty)
          _SimplePanel(
            color: _PurchasePalette.cream,
            child: Text(
              _isAz
                  ? 'Hələ heç bir hədiyyə almamısan.'
                  : 'Ты пока не покупал подарки.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _PurchasePalette.inkSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          )
        else
          for (final purchase in summary.history) ...[
            _PurchaseHistoryCard(purchase: purchase, isAz: _isAz),
            const SizedBox(height: 11),
          ],
      ],
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  final String totalSpent;
  final int availableCount;
  final bool isAz;

  const _SummaryPanel({
    required this.totalSpent,
    required this.availableCount,
    required this.isAz,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _PurchasePalette.skyBlue,
        borderRadius: BorderRadius.circular(27),
        border: Border.all(color: _PurchasePalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _PurchasePalette.ink,
            blurRadius: 0,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isAz ? 'Hədiyyə alışların' : 'Твои покупки подарков',
            style: const TextStyle(
              color: _PurchasePalette.ink,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            isAz
                ? 'Burada nə vaxt və nəyə pul xərclədiyini görə bilərsən.'
                : 'Здесь видно, когда и на какие подарки ты тратился.',
            style: const TextStyle(
              color: _PurchasePalette.inkSoft,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryChip(
                  icon: Icons.payments_rounded,
                  value: totalSpent,
                  label: isAz ? 'Cəmi xərclənib' : 'Всего потрачено',
                  color: _PurchasePalette.yellow,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SummaryChip(
                  icon: Icons.inventory_2_rounded,
                  value: '$availableCount',
                  label: isAz ? 'Hədiyyə etmək olar' : 'Можно подарить',
                  color: _PurchasePalette.lime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _SummaryChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _PurchasePalette.ink, width: 2.6),
        boxShadow: const [
          BoxShadow(
            color: _PurchasePalette.ink,
            blurRadius: 0,
            offset: Offset(2, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: _PurchasePalette.ink, size: 22),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _PurchasePalette.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              color: _PurchasePalette.inkSoft,
              fontSize: 10.5,
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
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _PurchasePalette.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _PurchasePalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _PurchasePalette.ink,
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          _GiftImage(gift: gift),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gift.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _PurchasePalette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.restaurant_rounded,
                      size: 15,
                      color: _PurchasePalette.inkSoft,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        gift.restaurantName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _PurchasePalette.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${gift.price} · ${isAz ? 'qalıb' : 'осталось'} ${gift.giftableCount}',
                  style: const TextStyle(
                    color: _PurchasePalette.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            constraints: const BoxConstraints(minWidth: 45, minHeight: 45),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _PurchasePalette.lime,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _PurchasePalette.ink, width: 2.4),
            ),
            child: Text(
              '×${gift.giftableCount}',
              style: const TextStyle(
                color: _PurchasePalette.ink,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseHistoryCard extends StatelessWidget {
  final GiftPurchase purchase;
  final bool isAz;

  const _PurchaseHistoryCard({required this.purchase, required this.isAz});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _PurchasePalette.paper,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _PurchasePalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _PurchasePalette.ink,
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GiftImage(gift: purchase.gift, size: 58),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  purchase.gift.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _PurchasePalette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  purchase.gift.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _PurchasePalette.inkSoft,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _formatDate(purchase.purchasedAt, isAz: isAz),
                  style: const TextStyle(
                    color: _PurchasePalette.inkSoft,
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
                  color: _PurchasePalette.yellow,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _PurchasePalette.ink, width: 2.2),
                ),
                child: Text(
                  purchase.totalPrice,
                  style: const TextStyle(
                    color: _PurchasePalette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${purchase.quantity} × ${purchase.unitPrice}',
                style: const TextStyle(
                  color: _PurchasePalette.inkSoft,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _formatDate(DateTime? value, {required bool isAz}) {
    if (value == null) return isAz ? 'Tarix yoxdur' : 'Дата неизвестна';
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)}.${date.year} · '
        '${two(date.hour)}:${two(date.minute)}';
  }
}

class _GiftImage extends StatelessWidget {
  final Gift gift;
  final double size;

  const _GiftImage({required this.gift, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _PurchasePalette.ink, width: 2.5),
      ),
      child: gift.imageUrl?.trim().isNotEmpty == true
          ? Image.network(
              gift.imageUrl!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.card_giftcard_rounded,
                color: _PurchasePalette.ink,
                size: 30,
              ),
            )
          : const Icon(
              Icons.card_giftcard_rounded,
              color: _PurchasePalette.ink,
              size: 30,
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _SectionTitle({
    required this.icon,
    required this.text,
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
          border: Border.all(color: _PurchasePalette.ink, width: 2.7),
          boxShadow: const [
            BoxShadow(
              color: _PurchasePalette.ink,
              blurRadius: 0,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _PurchasePalette.ink, size: 20),
            const SizedBox(width: 7),
            Text(
              text,
              style: const TextStyle(
                color: _PurchasePalette.ink,
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

class _SimplePanel extends StatelessWidget {
  final Color color;
  final Widget child;

  const _SimplePanel({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _PurchasePalette.ink, width: 2.8),
        boxShadow: const [
          BoxShadow(
            color: _PurchasePalette.ink,
            blurRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _MessagePanel extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final String buttonText;
  final Future<void> Function() onTap;

  const _MessagePanel({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _SimplePanel(
      color: color,
      child: Column(
        children: [
          Icon(icon, color: _PurchasePalette.ink, size: 44),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: _PurchasePalette.ink,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _PurchasePalette.inkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: () => onTap(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: _PurchasePalette.cream,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: _PurchasePalette.ink, width: 2.5),
              ),
              child: Text(
                buttonText,
                style: const TextStyle(
                  color: _PurchasePalette.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
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
    this.color = _PurchasePalette.cream,
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
            border: Border.all(color: _PurchasePalette.ink, width: 2.7),
            boxShadow: const [
              BoxShadow(
                color: _PurchasePalette.ink,
                blurRadius: 0,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: Icon(icon, color: _PurchasePalette.ink, size: 21),
        ),
      ),
    );
  }
}

class _PurchasePalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF51453C);
  static const Color cream = Color(0xFFFFF5D9);
  static const Color paper = Color(0xFFFFE8B6);
  static const Color skyBlue = Color(0xFF79CDF1);
  static const Color yellow = Color(0xFFFFD65C);
  static const Color coral = Color(0xFFFF7E70);
  static const Color lime = Color(0xFF7CFC00);
}
