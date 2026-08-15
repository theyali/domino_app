import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/app_localizations.dart';
import '../localization/statistics_strings.dart';
import '../models/user_account.dart';
import '../services/push_notification_service.dart';
import '../services/social_service.dart';
import '../services/sound_effects_service.dart';
import '../widgets/cartoon_page_background.dart';
import 'inventory_screen.dart';
import 'profile_screen.dart';
import 'restaurants_screen.dart';
import 'social_manage_screen.dart';
import 'social_screen.dart';
import 'statistics_screen.dart';

class MainShellScreen extends StatefulWidget {
  final UserAccount user;
  final Future<void> Function() onLogout;

  const MainShellScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen>
    with WidgetsBindingObserver {
  static const SocialService _socialService = SocialService();

  final PushNotificationService _pushNotifications = PushNotificationService();

  int _index = 0;
  int _statisticsRefreshToken = 0;
  int _socialBadgeCount = 0;
  late UserAccount _user;
  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    WidgetsBinding.instance.addObserver(this);
    _startHeartbeat();
    unawaited(_initializePushNotifications());
  }

  @override
  void didUpdateWidget(covariant MainShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _user = widget.user;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startHeartbeat();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    }
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _pushNotifications.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    unawaited(_heartbeat());
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_heartbeat());
    });
  }

  Future<void> _heartbeat() async {
    try {
      await _socialService.heartbeat();
    } catch (_) {
      // Presence не должен мешать основной игре. Следующий heartbeat
      // автоматически повторит попытку.
    }
  }

  Future<void> _initializePushNotifications() async {
    await _pushNotifications.initialize(
      onTap: (_) => _openSocialFromPush(),
      onForeground: (title, body, _) => _showForegroundPush(title, body),
    );
  }

  void _openSocialFromPush() {
    if (!mounted) return;
    setState(() => _index = 3);
  }

  void _showForegroundPush(String title, String body) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(body.isEmpty ? title : '$title\n$body'),
          action: SnackBarAction(
            label: context.appLanguage.code == 'az' ? 'Aç' : 'Открыть',
            onPressed: _openSocialFromPush,
          ),
        ),
      );
  }

  Future<void> _handleLogout() async {
    await _pushNotifications.unregisterCurrentDevice();
    await widget.onLogout();
  }

  void _handleUserUpdated(UserAccount user) {
    setState(() {
      _user = user;
    });
  }

  void _handleSocialBadgeChanged(int count) {
    if (!mounted || count == _socialBadgeCount) return;
    setState(() {
      _socialBadgeCount = count;
    });
  }

  void _selectTab(int index) {
    if (_index == index && index != 1) return;

    setState(() {
      _index = index;
      if (index == 1) {
        _statisticsRefreshToken += 1;
      }
    });
  }

  Future<void> _openSocialManage() async {
    SoundEffectsService.button(alternate: true);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SocialManageScreen(currentUser: _user),
      ),
    );
  }

  Future<void> _openLanguagePicker() async {
    SoundEffectsService.button(alternate: true);
    final controller = LanguageScope.of(context);
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (sheetContext) => _LanguagePickerSheet(
        current: controller.language,
      ),
    );
    if (selected == null || selected == controller.language) return;
    await controller.setLanguage(selected);
  }

  @override
  Widget build(BuildContext context) {
    final statsStrings = StatisticsStrings.of(context);
    final isAz = context.appLanguage.code == 'az';
    final screens = [
      const RestaurantsScreen(),
      StatisticsScreen(key: ValueKey(_statisticsRefreshToken)),
      const InventoryScreen(),
      const IconTheme(
        data: IconThemeData(color: Color(0xFF111111)),
        child: SizedBox.shrink(),
      ),
      ProfileScreen(
        user: _user,
        onUserUpdated: _handleUserUpdated,
        onLogout: _handleLogout,
      ),
    ];
    screens[3] = IconTheme(
      data: const IconThemeData(color: Color(0xFF111111)),
      child: SocialScreen(
        currentUser: _user,
        onBadgeChanged: _handleSocialBadgeChanged,
      ),
    );

    final items = [
      _NavItemData(
        assetPath: 'assets/icons/domino.png',
        label: statsStrings.play,
        accent: const Color(0xFF66C7F0),
      ),
      _NavItemData(
        assetPath: 'assets/icons/leagues.png',
        label: statsStrings.title,
        accent: const Color(0xFFFFD85A),
      ),
      _NavItemData(
        assetPath: 'assets/icons/gift.png',
        label: context.tr('inventory'),
        accent: const Color(0xFF82D66E),
      ),
      _NavItemData(
        icon: Icons.groups_rounded,
        label: isAz ? 'Dostlar' : 'Друзья',
        accent: const Color(0xFFC7A7FF),
        badgeCount: _socialBadgeCount,
      ),
      _NavItemData(
        assetPath: 'assets/icons/profile.png',
        label: context.tr('profile'),
        accent: const Color(0xFFFF806F),
      ),
    ];

    return CartoonPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            IndexedStack(
              index: _index,
              children: screens,
            ),
            if (_index == 0)
              Positioned(
                left: 12,
                top: MediaQuery.paddingOf(context).top + 7,
                child: _LanguageButton(
                  language: context.appLanguage,
                  onTap: _openLanguagePicker,
                ),
              ),
          ],
        ),
        floatingActionButton: _index == 3
            ? _SocialManageButton(
                label: isAz ? 'Axtarış və ayarlar' : 'Поиск и настройки',
                onTap: _openSocialManage,
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: _CartoonGameDock(
          selectedIndex: _index,
          items: items,
          onSelected: _selectTab,
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  static const _ink = Color(0xFF17120D);
  static const _cream = Color(0xFFFFF3CC);

  final AppLanguage language;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.language,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _cream,
          shape: BoxShape.circle,
          border: Border.all(color: _ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: _ink,
              blurRadius: 0,
              offset: Offset(3, 4),
            ),
          ],
        ),
        child: Text(
          language.flag,
          style: const TextStyle(fontSize: 24, height: 1),
        ),
      ),
    );
  }
}

class _LanguagePickerSheet extends StatelessWidget {
  static const _ink = Color(0xFF17120D);
  static const _cream = Color(0xFFFFF3CC);
  static const _yellow = Color(0xFFFFD85A);
  static const _lime = Color(0xFF79FA00);

  final AppLanguage current;

  const _LanguagePickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: _yellow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: _ink,
              blurRadius: 0,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: _ink,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              current == AppLanguage.az ? 'Dili seç' : 'Выбери язык',
              style: const TextStyle(
                color: _ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            for (final language in AppLanguage.values) ...[
              GestureDetector(
                onTap: () {
                  SoundEffectsService.button(alternate: true);
                  Navigator.pop(context, language);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: language == current ? _lime : _cream,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _ink, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: _ink,
                        blurRadius: 0,
                        offset: Offset(3, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(language.flag, style: const TextStyle(fontSize: 27)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          language.label,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (language == current)
                        const Icon(Icons.check_circle_rounded, color: _ink, size: 25),
                    ],
                  ),
                ),
              ),
              if (language != AppLanguage.values.last) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _SocialManageButton extends StatelessWidget {
  static const _ink = Color(0xFF17120D);
  static const _lime = Color(0xFF79FA00);

  final String label;
  final VoidCallback onTap;

  const _SocialManageButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: _lime,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: _ink,
              blurRadius: 0,
              offset: Offset(4, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.manage_accounts_rounded, color: _ink),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: _ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartoonGameDock extends StatelessWidget {
  static const _dockColor = Color(0xFFF5CE79);
  static const _ink = Color(0xFF17120D);

  final int selectedIndex;
  final List<_NavItemData> items;
  final ValueChanged<int> onSelected;

  const _CartoonGameDock({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _dockColor,
        border: Border(
          top: BorderSide(color: _ink, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 0,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(6, 7, 6, 5),
        child: SizedBox(
          height: 78,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _CartoonNavItem(
                    data: items[index],
                    selected: selectedIndex == index,
                    onTap: () => onSelected(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartoonNavItem extends StatelessWidget {
  static const _ink = Color(0xFF17120D);
  static const _cream = Color(0xFFFFF3CC);
  static const _badge = Color(0xFFFF6B62);

  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _CartoonNavItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          SoundEffectsService.button(alternate: true);
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
          padding: const EdgeInsets.fromLTRB(3, 5, 3, 3),
          decoration: BoxDecoration(
            color: selected ? data.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? _ink : Colors.transparent,
              width: selected ? 2.5 : 0,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: _ink,
                      blurRadius: 0,
                      offset: Offset(3, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: selected ? 42 : 37,
                    height: selected ? 37 : 33,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: selected ? _cream : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _ink,
                        width: 2.3,
                      ),
                      boxShadow: selected
                          ? const [
                              BoxShadow(
                                color: _ink,
                                blurRadius: 0,
                                offset: Offset(2, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: data.assetPath != null
                        ? Image.asset(
                            data.assetPath!,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.high,
                          )
                        : Icon(
                            data.icon,
                            size: 21,
                            color: _ink,
                          ),
                  ),
                  if (data.badgeCount > 0)
                    Positioned(
                      top: -8,
                      right: -11,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 23,
                          minHeight: 23,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _badge,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: _ink, width: 2.1),
                          boxShadow: const [
                            BoxShadow(
                              color: _ink,
                              blurRadius: 0,
                              offset: Offset(1.5, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          data.badgeCount > 99 ? '99+' : '${data.badgeCount}',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _ink,
                  fontSize: 9.2,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData? icon;
  final String? assetPath;
  final String label;
  final Color accent;
  final int badgeCount;

  const _NavItemData({
    this.icon,
    this.assetPath,
    required this.label,
    required this.accent,
    this.badgeCount = 0,
  }) : assert(icon != null || assetPath != null);
}
