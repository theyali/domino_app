import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/gift.dart';
import '../services/api_service.dart';
import '../services/gift_service.dart';
import '../theme/play_palette.dart';
import '../widgets/cartoon_page_background.dart';
import '../widgets/site_image_panel.dart';

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
          elevation: 0,
          centerTitle: true,
          toolbarHeight: 70,
          leadingWidth: 68,
          leading: Padding(
            padding: const EdgeInsets.only(left: 14),
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
              letterSpacing: -0.35,
            ),
          ),
          actions: [
            _TopButton(
              icon: Icons.refresh_rounded,
              primary: true,
              loading: _isLoading && _summary != null,
              onTap: _isLoading ? null : _load,
            ),
            const SizedBox(width: 14),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: PlayPalette.blue,
            backgroundColor: _PurchasePalette.surface,
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
        padding: const EdgeInsets.fromLTRB(16, 56, 16, 44),
        children: [
          _LoadingPanel(isAz: _isAz),
        ],
      );
    }

    if (_errorMessage != null && _summary == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 42, 16, 44),
        children: [
          _ErrorPanel(
            message: _errorMessage!,
            isAz: _isAz,
            onRetry: _load,
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
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 42),
      children: [
        _SummaryCard(summary: summary, isAz: _isAz),
        const SizedBox(height: 24),
        _SectionHeader(
          icon: Icons.card_giftcard_rounded,
          title: _isAz ? 'Hazırda səndə olanlar' : 'Сейчас у тебя',
          subtitle: _isAz
              ? 'Oyunda və ya restoranda hədiyyə edə biləcəklərin'
              : 'Подарки, которые можно отправить игрокам',
          count: summary.availableCount,
        ),
        const SizedBox(height: 12),
        if (summary.ownedGifts.isEmpty)
          _EmptySection(
            icon: Icons.inventory_2_outlined,
            title: _isAz ? 'Hədiyyə qalmayıb' : 'Подарков пока нет',
            subtitle: _isAz
                ? 'Hədiyyə etmək üçün əvvəlcə restorandan bir hədiyyə al.'
                : 'Купи подарок в ресторане, чтобы потом отправить его игроку.',
          )
        else
          for (final entry in summary.ownedGifts.asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _OwnedGiftCard(
                gift: entry.value,
                isAz: _isAz,
                index: entry.key,
              ),
            ),
        const SizedBox(height: 16),
        _SectionHeader(
          icon: Icons.receipt_long_rounded,
          title: _isAz ? 'Alış tarixçəsi' : 'История покупок',
          subtitle: _isAz
              ? 'Restoran hədiyyələrinə etdiyin xərclər'
              : 'Все покупки ресторанных подарков',
          count: summary.history.length,
        ),
        const SizedBox(height: 12),
        if (summary.history.isEmpty)
          _EmptySection(
            icon: Icons.receipt_long_outlined,
            title: _isAz ? 'Alış yoxdur' : 'Покупок пока нет',
            subtitle: _isAz
                ? 'İlk hədiyyəni aldıqdan sonra əməliyyat burada görünəcək.'
                : 'После первой покупки она появится в этом списке.',
          )
        else
          for (final entry in summary.history.asMap().entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HistoryCard(
                purchase: entry.value,
                index: entry.key,
              ),
            ),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  final bool isAz;

  const _LoadingPanel({required this.isAz});

  @override
  Widget build(BuildContext context) {
    return SiteImagePanel(
      assetPath: 'assets/ui/long_4.webp',
      borderRadius: 28,
      borderColor: const Color(0x55106CFF),
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                color: PlayPalette.blue,
                strokeWidth: 4,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isAz ? 'Hədiyyələr yüklənir' : 'Загружаем подарки',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isAz
                ? 'Alışların və qalan hədiyyələrin hazırlanır.'
                : 'Получаем покупки и доступные для отправки подарки.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xE8FFFFFF),
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final bool isAz;
  final Future<void> Function() onRetry;

  const _ErrorPanel({
    required this.message,
    required this.isAz,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SiteImagePanel(
      assetPath: 'assets/ui/long_5.webp',
      borderRadius: 28,
      borderColor: const Color(0x55FF6F6F),
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 24),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(21),
            ),
            child: const Icon(
              Icons.cloud_off_rounded,
              color: _PurchasePalette.danger,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isAz ? 'Yükləmək alınmadı' : 'Не удалось загрузить',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xE8FFFFFF),
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _PrimaryButton(
            icon: Icons.refresh_rounded,
            label: isAz ? 'Yenidən cəhd et' : 'Повторить',
            onTap: onRetry,
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final GiftPurchaseSummary summary;
  final bool isAz;

  const _SummaryCard({required this.summary, required this.isAz});

  @override
  Widget build(BuildContext context) {
    return SiteImagePanel(
      assetPath: 'assets/ui/long_1.webp',
      borderRadius: 28,
      borderColor: const Color(0x55106CFF),
      padding: const EdgeInsets.fromLTRB(17, 18, 17, 17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.shopping_bag_rounded,
                  color: PlayPalette.blue,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isAz ? 'Hədiyyə alışların' : 'Твои покупки подарков',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isAz
                          ? 'Alışlar və hədiyyə etmək üçün qalanlar'
                          : 'Покупки и подарки, которые ещё можно отправить',
                      style: const TextStyle(
                        color: Color(0xE8FFFFFF),
                        fontSize: 11.5,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: summary.totalSpent,
                  label: isAz ? 'Cəmi xərclənib' : 'Всего потрачено',
                  icon: Icons.payments_rounded,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _Metric(
                  value: '${summary.availableCount}',
                  label: isAz ? 'Hədiyyə etmək olar' : 'Можно подарить',
                  icon: Icons.inventory_2_rounded,
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

  const _Metric({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 19, color: PlayPalette.ink),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: PlayPalette.ink,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xB5121212),
              fontSize: 9.5,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _PurchasePalette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _PurchasePalette.border),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.25,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: PlayPalette.muted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          constraints: const BoxConstraints(minWidth: 38),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PlayPalette.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnedGiftCard extends StatelessWidget {
  final Gift gift;
  final bool isAz;
  final int index;

  const _OwnedGiftCard({
    required this.gift,
    required this.isAz,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final assetIndex = (index % 5) + 1;

    return SiteImagePanel(
      assetPath: 'assets/ui/long_$assetIndex.webp',
      borderRadius: 22,
      borderColor: const Color(0x44106CFF),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          _GiftImage(gift: gift, size: 66),
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
                    color: Colors.white,
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
                    color: Color(0xE8FFFFFF),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _PurchasePalette.surface.withValues(alpha: 0.90),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '${gift.price} · ${isAz ? 'qalıb' : 'осталось'} ${gift.giftableCount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Container(
            constraints: const BoxConstraints(minWidth: 54, minHeight: 46),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '×${gift.giftableCount}',
              style: const TextStyle(
                color: PlayPalette.blue,
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

class _HistoryCard extends StatelessWidget {
  final GiftPurchase purchase;
  final int index;

  const _HistoryCard({required this.purchase, required this.index});

  @override
  Widget build(BuildContext context) {
    final assetIndex = ((index + 2) % 5) + 1;

    return SiteImagePanel(
      assetPath: 'assets/ui/long_$assetIndex.webp',
      borderRadius: 22,
      borderColor: const Color(0x33106CFF),
      padding: const EdgeInsets.all(12),
      child: Row(
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
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  purchase.gift.restaurantName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xE8FFFFFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _date(purchase.purchasedAt),
                  style: const TextStyle(
                    color: Color(0xD8FFFFFF),
                    fontSize: 10,
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  purchase.totalPrice,
                  style: const TextStyle(
                    color: PlayPalette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: _PurchasePalette.surface.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${purchase.quantity} × ${purchase.unitPrice}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                  ),
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: gift.imageUrl?.trim().isNotEmpty == true
          ? Image.network(
              gift.imageUrl!,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.card_giftcard_rounded,
                color: PlayPalette.blue,
              ),
            )
          : const Icon(
              Icons.card_giftcard_rounded,
              color: PlayPalette.blue,
            ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptySection({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _PurchasePalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _PurchasePalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _PurchasePalette.surfaceRaised,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: PlayPalette.blue, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: PlayPalette.muted,
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
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

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        decoration: BoxDecoration(
          color: PlayPalette.blue,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;
  final bool loading;

  const _TopButton({
    required this.icon,
    required this.onTap,
    this.primary = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: onTap == null && !loading ? 0.48 : 1,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? PlayPalette.blue : _PurchasePalette.surface,
            borderRadius: BorderRadius.circular(15),
            border: primary
                ? null
                : Border.all(color: _PurchasePalette.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: loading
              ? const SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.4,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

abstract final class _PurchasePalette {
  static const surface = Color(0xFF262628);
  static const surfaceRaised = Color(0xFF323234);
  static const border = Color(0xFF3A3A3E);
  static const danger = Color(0xFFFF6F6F);
}
