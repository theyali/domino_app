import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/social.dart';
import '../models/user_account.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';
import '../services/sound_effects_service.dart';
import '../theme/gender_style.dart';
import '../widgets/cartoon_page_background.dart';
import 'chat_screen.dart';

class SocialManageScreen extends StatefulWidget {
  final UserAccount currentUser;

  const SocialManageScreen({
    super.key,
    required this.currentUser,
  });

  @override
  State<SocialManageScreen> createState() => _SocialManageScreenState();
}

class _SocialManageScreenState extends State<SocialManageScreen> {
  static const SocialService _service = SocialService();

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _busy = <String>{};
  Timer? _searchTimer;

  SocialOverview? _overview;
  List<SocialUser> _blocked = const <SocialUser>[];
  List<SocialUser> _searchResults = const <SocialUser>[];
  NotificationPreferences? _preferences;
  bool _loading = true;
  bool _searching = false;
  String? _error;

  bool get _isAz => context.appLanguage.code == 'az';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final overview = await _service.fetchOverview();
      final blocked = await _service.fetchBlockedUsers();
      final preferences = await _service.fetchNotificationPreferences();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _blocked = blocked;
        _preferences = preferences;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _isAz
            ? 'Sosial parametrləri yükləmək mümkün olmadı.'
            : 'Не удалось загрузить социальные настройки.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      _search(value);
    });
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.replaceFirst(RegExp(r'^@'), '').length < 2) {
      if (mounted) {
        setState(() {
          _searchResults = const <SocialUser>[];
          _searching = false;
        });
      }
      return;
    }

    setState(() => _searching = true);
    try {
      final results = await _service.searchUsers(query);
      if (!mounted || query != _searchController.text.trim()) return;
      setState(() => _searchResults = results);
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _run(String key, Future<void> Function() action) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    try {
      await action();
      final overview = await _service.fetchOverview();
      final blocked = await _service.fetchBlockedUsers();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _blocked = blocked;
      });
      if (_searchController.text.trim().length >= 2) {
        await _search(_searchController.text);
      }
    } on ApiException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) {
        _showMessage(_isAz ? 'Əməliyyat alınmadı.' : 'Не удалось выполнить действие.');
      }
    } finally {
      if (mounted) setState(() => _busy.remove(key));
    }
  }

  Future<bool> _confirm({
    required String title,
    required String text,
    required String action,
    Color actionColor = _Palette.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _Palette.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _Palette.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Palette.muted,
                  fontSize: 13.5,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _WideButton(
                      label: _isAz ? 'Ləğv et' : 'Отмена',
                      color: _Palette.surfaceRaised,
                      onTap: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WideButton(
                      label: action,
                      color: actionColor,
                      onTap: () => Navigator.pop(dialogContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Future<void> _removeFriend(SocialUser user) async {
    final friendshipId = user.friendshipId;
    if (friendshipId == null) return;
    final confirmed = await _confirm(
      title: _isAz ? 'Dostlardan silinsin?' : 'Удалить из друзей?',
      text: _isAz
          ? '@${user.username} artıq dostlar siyahısında olmayacaq.'
          : '@${user.username} больше не будет в списке друзей.',
      action: _isAz ? 'Sil' : 'Удалить',
    );
    if (!confirmed) return;
    await _run(
      'remove-$friendshipId',
      () => _service.removeFriendship(friendshipId),
    );
  }

  Future<void> _blockUser(SocialUser user) async {
    final confirmed = await _confirm(
      title: _isAz ? 'İstifadəçi bloklansın?' : 'Добавить в чёрный список?',
      text: _isAz
          ? '@${user.username} sənə yaza, dostluq sorğusu və masa dəvəti göndərə bilməyəcək.'
          : '@${user.username} не сможет писать тебе, добавляться в друзья и звать за стол.',
      action: _isAz ? 'Blokla' : 'Заблокировать',
      actionColor: _Palette.orange,
    );
    if (!confirmed) return;
    await _run('block-${user.id}', () => _service.blockUser(user.id));
  }

  Future<void> _openChat(SocialUser user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          currentUserId: widget.currentUser.id,
          user: user,
        ),
      ),
    );
  }

  Future<void> _savePreferences(NotificationPreferences value) async {
    final old = _preferences;
    setState(() => _preferences = value);
    try {
      final saved = await _service.updateNotificationPreferences(value);
      if (mounted) setState(() => _preferences = saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _preferences = old);
      _showMessage(error.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
          toolbarHeight: 70,
          leadingWidth: 66,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _TopButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.maybePop(context),
            ),
          ),
          title: Text(
            _isAz ? 'Dostları idarə et' : 'Друзья и настройки',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _TopButton(
                icon: Icons.refresh_rounded,
                primary: true,
                onTap: _loading ? null : _load,
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _loading && _overview == null
              ? const Center(
                  child: CircularProgressIndicator(color: _Palette.blue),
                )
              : _error != null && _overview == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _SitePanel(
                          assetPath: 'assets/ui/long_5.webp',
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _Palette.blue,
                      backgroundColor: _Palette.surface,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 36),
                        children: [
                          _buildSearch(),
                          const SizedBox(height: 14),
                          _buildFriends(),
                          const SizedBox(height: 14),
                          _buildBlocked(),
                          const SizedBox(height: 14),
                          _buildNotifications(),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return _Section(
      title: _isAz ? 'İstifadəçi axtarışı' : 'Поиск игроков',
      icon: Icons.person_search_rounded,
      assetPath: 'assets/ui/long_1.webp',
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            cursorColor: _Palette.blue,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              hintText: _isAz ? '@login yaz' : 'Введи @логин',
              hintStyle: const TextStyle(color: _Palette.muted),
              prefixIcon: const Icon(
                Icons.alternate_email_rounded,
                color: _Palette.blue,
              ),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: _Palette.blue,
                        ),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: _Palette.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _Palette.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: _Palette.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: _Palette.blue,
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (_searchController.text.trim().length >= 2 &&
              !_searching &&
              _searchResults.isEmpty) ...[
            const SizedBox(height: 12),
            Text(
              _isAz ? 'Heç kim tapılmadı' : 'Никого не нашли',
              style: const TextStyle(
                color: _Palette.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          for (final user in _searchResults) ...[
            const SizedBox(height: 10),
            _SocialPersonRow(
              user: user,
              actions: _searchActions(user),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _searchActions(SocialUser user) {
    final widgets = <Widget>[];
    if (user.isFriend) {
      widgets.add(
        _ActionIcon(
          icon: Icons.chat_bubble_rounded,
          color: _Palette.blue,
          onTap: () => _openChat(user),
        ),
      );
    } else if (user.requestIncoming && user.friendshipId != null) {
      widgets.add(
        _ActionIcon(
          icon: Icons.check_rounded,
          color: _Palette.blue,
          busy: _busy.contains('accept-${user.friendshipId}'),
          onTap: () => _run(
            'accept-${user.friendshipId}',
            () => _service.acceptFriendRequest(user.friendshipId!),
          ),
        ),
      );
    } else if (user.requestOutgoing && user.friendshipId != null) {
      widgets.add(
        _ActionIcon(
          icon: Icons.person_remove_alt_1_rounded,
          color: _Palette.surfaceRaised,
          busy: _busy.contains('cancel-${user.friendshipId}'),
          onTap: () => _run(
            'cancel-${user.friendshipId}',
            () => _service.cancelFriendRequest(user.friendshipId!),
          ),
        ),
      );
    } else {
      widgets.add(
        _ActionIcon(
          icon: Icons.person_add_alt_1_rounded,
          color: _Palette.blue,
          busy: _busy.contains('add-${user.id}'),
          onTap: () => _run(
            'add-${user.id}',
            () => _service.sendFriendRequest(user.id),
          ),
        ),
      );
    }
    widgets.add(const SizedBox(width: 7));
    widgets.add(
      _ActionIcon(
        icon: Icons.block_rounded,
        color: _Palette.surfaceRaised,
        busy: _busy.contains('block-${user.id}'),
        onTap: () => _blockUser(user),
      ),
    );
    return widgets;
  }

  Widget _buildFriends() {
    final friends = _overview?.friends ?? const <SocialUser>[];
    return _Section(
      title: _isAz ? 'Dostlarım' : 'Мои друзья',
      icon: Icons.people_alt_rounded,
      assetPath: 'assets/ui/long_2.webp',
      count: friends.length,
      child: friends.isEmpty
          ? Text(
              _isAz
                  ? 'Dostlar hələ yoxdur. Yuxarıdakı axtarışdan istifadə et.'
                  : 'Друзей пока нет. Найди игрока по логину выше.',
              style: const TextStyle(
                color: _Palette.muted,
                fontWeight: FontWeight.w700,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < friends.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _SocialPersonRow(
                    user: friends[i],
                    actions: [
                      _ActionIcon(
                        icon: Icons.chat_bubble_rounded,
                        color: _Palette.blue,
                        onTap: () => _openChat(friends[i]),
                      ),
                      const SizedBox(width: 7),
                      _ActionIcon(
                        icon: Icons.person_remove_rounded,
                        color: _Palette.surfaceRaised,
                        busy: friends[i].friendshipId != null &&
                            _busy.contains('remove-${friends[i].friendshipId}'),
                        onTap: () => _removeFriend(friends[i]),
                      ),
                      const SizedBox(width: 7),
                      _ActionIcon(
                        icon: Icons.block_rounded,
                        color: _Palette.surfaceRaised,
                        busy: _busy.contains('block-${friends[i].id}'),
                        onTap: () => _blockUser(friends[i]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildBlocked() {
    return _Section(
      title: _isAz ? 'Qara siyahı' : 'Чёрный список',
      icon: Icons.block_rounded,
      assetPath: 'assets/ui/long_3.webp',
      count: _blocked.length,
      child: _blocked.isEmpty
          ? Text(
              _isAz ? 'Bloklanmış istifadəçi yoxdur.' : 'Чёрный список пуст.',
              style: const TextStyle(
                color: _Palette.muted,
                fontWeight: FontWeight.w700,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < _blocked.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _SocialPersonRow(
                    user: _blocked[i],
                    actions: [
                      _ActionIcon(
                        icon: Icons.lock_open_rounded,
                        color: _Palette.blue,
                        busy: _busy.contains('unblock-${_blocked[i].id}'),
                        onTap: () => _run(
                          'unblock-${_blocked[i].id}',
                          () => _service.unblockUser(_blocked[i].id),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildNotifications() {
    final prefs = _preferences;
    if (prefs == null) return const SizedBox.shrink();

    return _Section(
      title: _isAz ? 'Bildirişlər' : 'Уведомления',
      icon: Icons.notifications_active_rounded,
      assetPath: 'assets/ui/long_4.webp',
      child: Column(
        children: [
          _SiteSwitchTile(
            title: _isAz ? 'Push bildirişləri' : 'Push-уведомления',
            subtitle: _isAz
                ? 'Bütün oyun və sosial bildirişlərini söndürür.'
                : 'Главный выключатель всех игровых и социальных push.',
            value: prefs.enabled,
            onChanged: (value) => _savePreferences(
              prefs.copyWith(enabled: value),
            ),
          ),
          const SizedBox(height: 9),
          _SiteSwitchTile(
            title: _isAz ? 'Masa dəvətləri' : 'Приглашения за стол',
            subtitle: _isAz
                ? 'Kimsə səni oyuna çağıranda.'
                : 'Когда кто-то зовёт тебя в игру.',
            value: prefs.roomInvites,
            enabled: prefs.enabled,
            onChanged: (value) => _savePreferences(
              prefs.copyWith(roomInvites: value),
            ),
          ),
          const SizedBox(height: 9),
          _SiteSwitchTile(
            title: _isAz ? 'Dostluq sorğuları' : 'Заявки в друзья',
            subtitle: _isAz
                ? 'Yeni sorğu və qəbul edilən dostluq.'
                : 'Новая заявка и принятие твоей заявки.',
            value: prefs.friendRequests,
            enabled: prefs.enabled,
            onChanged: (value) => _savePreferences(
              prefs.copyWith(friendRequests: value),
            ),
          ),
          const SizedBox(height: 9),
          _SiteSwitchTile(
            title: _isAz ? 'Şəxsi mesajlar' : 'Личные сообщения',
            subtitle: _isAz
                ? 'Yeni şəxsi mesaj gələndə.'
                : 'Когда приходит новое личное сообщение.',
            value: prefs.directMessages,
            enabled: prefs.enabled,
            onChanged: (value) => _savePreferences(
              prefs.copyWith(directMessages: value),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final String assetPath;
  final int? count;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.assetPath,
    required this.child,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return _SitePanel(
      assetPath: assetPath,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _Palette.surface,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _Palette.border),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  constraints: const BoxConstraints(minWidth: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
                  decoration: BoxDecoration(
                    color: _Palette.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _Palette.border),
                  ),
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SitePanel extends StatelessWidget {
  final String assetPath;
  final Widget child;

  const _SitePanel({required this.assetPath, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Palette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: _Palette.surface),
            ),
          ),
          const Positioned.fill(
            child: ColoredBox(color: Color(0xB8121212)),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _SocialPersonRow extends StatelessWidget {
  final SocialUser user;
  final List<Widget> actions;

  const _SocialPersonRow({
    required this.user,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final genderColor = GenderStyle.colorFor(
      user.gender,
      fallback: Colors.white,
    );
    final letter = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim().substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _Palette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: _Palette.blue,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: user.avatarUrl == null
                  ? ColoredBox(
                      color: _Palette.surfaceRaised,
                      child: Center(
                        child: Text(
                          letter,
                          style: TextStyle(
                            color: genderColor,
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                  : Image.network(
                      user.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: _Palette.surfaceRaised,
                        child: Center(
                          child: Text(
                            letter,
                            style: TextStyle(
                              color: genderColor,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: genderColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (user.isOnline) ...[
                      const SizedBox(width: 6),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF5FE2A0),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Palette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;

  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy || onTap == null
          ? null
          : () {
              SoundEffectsService.button(alternate: true);
              onTap!();
            },
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: color == _Palette.surfaceRaised
                ? Border.all(color: _Palette.border)
                : null,
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _SiteSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SiteSwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 140),
      opacity: enabled ? 1 : 0.45,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 7, 10),
        decoration: BoxDecoration(
          color: _Palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Palette.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _Palette.muted,
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: Colors.white,
              activeTrackColor: _Palette.blue,
              inactiveThumbColor: _Palette.muted,
              inactiveTrackColor: _Palette.surfaceRaised,
            ),
          ],
        ),
      ),
    );
  }
}

class _WideButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WideButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SoundEffectsService.button(alternate: true);
        onTap();
      },
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: color == _Palette.surfaceRaised
              ? Border.all(color: _Palette.border)
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool primary;

  const _TopButton({
    required this.icon,
    required this.onTap,
    this.primary = false,
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
          decoration: BoxDecoration(
            color: primary ? _Palette.blue : _Palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: primary ? null : Border.all(color: _Palette.border),
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

abstract final class _Palette {
  static const surface = Color(0xFF262628);
  static const surfaceRaised = Color(0xFF303033);
  static const border = Color(0xFF3A3A3E);
  static const blue = Color(0xFF106CFF);
  static const muted = Color(0xFFA7A7AD);
  static const red = Color(0xFFE6535F);
  static const orange = Color(0xFFD98B32);
}
