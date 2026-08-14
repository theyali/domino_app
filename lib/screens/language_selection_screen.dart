import 'package:flutter/material.dart';

import '../localization/app_language.dart';

class LanguageSelectionScreen extends StatelessWidget {
  final Future<void> Function(AppLanguage language) onSelected;

  const LanguageSelectionScreen({
    super.key,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Icon(
                      Icons.casino_rounded,
                      size: 48,
                      color: Colors.greenAccent,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Domino APP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Dil seçin',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Выберите язык приложения',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _LanguageButton(
                    language: AppLanguage.az,
                    subtitle: 'Azərbaycan dili',
                    isDefault: true,
                    onTap: () => onSelected(AppLanguage.az),
                  ),
                  const SizedBox(height: 12),
                  _LanguageButton(
                    language: AppLanguage.ru,
                    subtitle: 'Русский язык',
                    onTap: () => onSelected(AppLanguage.ru),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Dili daha sonra profildə dəyişə bilərsiniz.\n'
                    'Язык можно изменить позже в профиле.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 12,
                      height: 1.45,
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

class _LanguageButton extends StatelessWidget {
  final AppLanguage language;
  final String subtitle;
  final bool isDefault;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.language,
    required this.subtitle,
    required this.onTap,
    this.isDefault = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF142638),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDefault ? Colors.greenAccent : Colors.white12,
              width: isDefault ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(
                language.flag,
                style: const TextStyle(fontSize: 38),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white54,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
