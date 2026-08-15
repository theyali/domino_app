import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';

class EmotionPickerSheet extends StatefulWidget {
  const EmotionPickerSheet({super.key});

  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.58),
      builder: (context) => const EmotionPickerSheet(),
    );
  }

  @override
  State<EmotionPickerSheet> createState() => _EmotionPickerSheetState();
}

class _EmotionPickerSheetState extends State<EmotionPickerSheet> {
  late final Future<List<String>> _emotionAssets = _loadEmotionAssets();

  Future<List<String>> _loadEmotionAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where(_isEmotionAsset)
        .toList(growable: false)
      ..sort();
    return assets;
  }

  bool _isEmotionAsset(String path) {
    final lower = path.toLowerCase();
    if (!lower.startsWith('assets/emotions/')) {
      return false;
    }

    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  @override
  Widget build(BuildContext context) {
    final isAzerbaijani = context.appLanguage.code == 'az';

    return FractionallySizedBox(
      heightFactor: 0.50,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _EmotionPalette.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
            border: Border(
              top: BorderSide(color: _EmotionPalette.ink, width: 3),
              left: BorderSide(color: _EmotionPalette.ink, width: 3),
              right: BorderSide(color: _EmotionPalette.ink, width: 3),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 54,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _EmotionPalette.ink,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Transform.rotate(
                        angle: -0.06,
                        child: Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: _EmotionPalette.yellow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _EmotionPalette.ink,
                              width: 3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: _EmotionPalette.ink,
                                blurRadius: 0,
                                offset: Offset(3, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.sentiment_very_satisfied_rounded,
                            color: _EmotionPalette.ink,
                            size: 29,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAzerbaijani ? 'Emosiyalar' : 'Эмоции',
                              style: const TextStyle(
                                color: _EmotionPalette.ink,
                                fontSize: 27,
                                height: 1,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              isAzerbaijani
                                  ? 'Emosiyanı seçin — menyu bağlanacaq və effekt avatarın yanında görünəcək.'
                                  : 'Выбери эмоцию — меню закроется и эффект появится у аватара.',
                              style: const TextStyle(
                                color: _EmotionPalette.inkSoft,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Expanded(
                    child: FutureBuilder<List<String>>(
                      future: _emotionAssets,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: _EmotionPalette.ink,
                              strokeWidth: 3,
                            ),
                          );
                        }

                        final assets = snapshot.data ?? const <String>[];
                        if (assets.isEmpty) {
                          return Center(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: _EmotionPalette.skyBlue,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: _EmotionPalette.ink,
                                  width: 2.8,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: _EmotionPalette.ink,
                                    blurRadius: 0,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Text(
                                isAzerbaijani
                                    ? 'assets/emotions qovluğunda hələ şəkil yoxdur.\nPNG, JPG, WEBP və ya GIF əlavə edin — menyu onları avtomatik göstərəcək.'
                                    : 'В assets/emotions пока нет изображений.\nДобавь PNG, JPG, WEBP или GIF — меню подхватит их автоматически.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _EmotionPalette.ink,
                                  fontWeight: FontWeight.w800,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          );
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.fromLTRB(2, 2, 2, 8),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 11,
                            crossAxisSpacing: 11,
                          ),
                          itemCount: assets.length,
                          itemBuilder: (context, index) {
                            final asset = assets[index];
                            final cardColor = _emotionCardColors[
                                index % _emotionCardColors.length];

                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => Navigator.of(context).pop(asset),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(17),
                                  border: Border.all(
                                    color: _EmotionPalette.ink,
                                    width: 2.4,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: _EmotionPalette.ink,
                                      blurRadius: 0,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: _EmotionPalette.paper,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _EmotionPalette.ink,
                                      width: 1.8,
                                    ),
                                  ),
                                  child: Image.asset(
                                    asset,
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return const Icon(
                                        Icons.broken_image_outlined,
                                        color: _EmotionPalette.ink,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _emotionCardColors = <Color>[
  _EmotionPalette.coral,
  _EmotionPalette.skyBlue,
  _EmotionPalette.yellow,
  _EmotionPalette.mint,
  _EmotionPalette.lavender,
];

class _EmotionPalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF574C42);
  static const Color cream = Color(0xFFFFE8B6);
  static const Color paper = Color(0xFFFFF8E8);
  static const Color yellow = Color(0xFFFFD65C);
  static const Color skyBlue = Color(0xFF79CDF1);
  static const Color coral = Color(0xFFFF8A79);
  static const Color mint = Color(0xFF8CDD79);
  static const Color lavender = Color(0xFFC7A7FF);
}
