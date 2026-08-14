import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/app_localizations.dart';
import '../models/user_account.dart';

class ProfileScreen extends StatelessWidget {
  final UserAccount user;
  final Future<void> Function() onLogout;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final languageController = LanguageScope.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile'))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Text(
                user.displayName.isEmpty
                    ? '?'
                    : user.displayName.substring(0, 1).toUpperCase(),
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            user.displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 4),
          Text(
            '@${user.username}',
            textAlign: TextAlign.center,
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          if (user.email.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              user.email,
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('language'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('language_description'),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _LanguageChoiceButton(
                          language: AppLanguage.az,
                          selected:
                              languageController.language == AppLanguage.az,
                          onPressed: () => languageController.setLanguage(
                            AppLanguage.az,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LanguageChoiceButton(
                          language: AppLanguage.ru,
                          selected:
                              languageController.language == AppLanguage.ru,
                          onPressed: () => languageController.setLanguage(
                            AppLanguage.ru,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.card_giftcard_rounded),
              title: Text(context.tr('my_gifts')),
              subtitle: Text(context.tr('inventory_bottom_menu')),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.tr('logout')),
          ),
        ],
      ),
    );
  }
}

class _LanguageChoiceButton extends StatelessWidget {
  final AppLanguage language;
  final bool selected;
  final Future<void> Function() onPressed;

  const _LanguageChoiceButton({
    required this.language,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(language.flag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            language.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 5),
          const Icon(Icons.check_rounded, size: 18),
        ],
      ],
    );

    if (selected) {
      return FilledButton.tonal(
        onPressed: onPressed,
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      child: child,
    );
  }
}
