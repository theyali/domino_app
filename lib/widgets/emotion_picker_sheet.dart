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
      showDragHandle: true,
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
      heightFactor: 0.48,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isAzerbaijani ? 'Emosiyalar' : 'Эмоции',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isAzerbaijani
                  ? 'Emosiyanı seçin — menyu bağlanacaq və effekt avatarın yanında görünəcək.'
                  : 'Выбери эмоцию — меню закроется и эффект появится у аватара.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _emotionAssets,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final assets = snapshot.data ?? const <String>[];
                  if (assets.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          isAzerbaijani
                              ? 'assets/emotions qovluğunda hələ şəkil yoxdur.\nPNG, JPG, WEBP və ya GIF əlavə edin — menyu onları avtomatik göstərəcək.'
                              : 'В assets/emotions пока нет изображений.\nДобавь PNG, JPG, WEBP или GIF — меню подхватит их автоматически.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                    ),
                    itemCount: assets.length,
                    itemBuilder: (context, index) {
                      final asset = assets[index];

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.of(context).pop(asset),
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(7),
                            child: Image.asset(
                              asset,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.broken_image_outlined);
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
    );
  }
}
