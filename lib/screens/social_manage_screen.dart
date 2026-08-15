import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/social.dart';
import '../models/user_account.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';
import '../services/sound_effects_service.dart';
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
    Color actionColor = _Palette.coral,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _Palette.cream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _Palette.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: _Palette.ink,
                blurRadius: 0,
                offset: Offset(5, 6),
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
                  color: _Palette.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _Palette.inkSoft,
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _WideButton(
                      label: _isAz ? 'Ləğv et' : 'Отмена',
                      color: Colors.white,
                      onTap: () => Navigator.pop(context, false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _WideButton(
                      label: action,
                      color: actionColor,
                      onTap: () => Navigator.pop(context, true),
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
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(
            _isAz ? 'Dostları idarə et' : 'Друзья и настройки',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(color: Colors.black87, offset: Offset(2, 3)),
              ],
            ),
          ),
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _loading && _overview == null
              ? const Center(
                  child: CircularProgressIndicator(color: _Palette.cream),
                )
              : _error != null && _overview == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: _Panel(
                          color: _Palette.coral,
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _Palette.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _Palette.ink,
                      backgroundColor: _Palette.cream,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 36),
                        children: [
                          _buildSearch(),
                          const SizedBox(height: 16),
                          _buildFriends(),
                          const SizedBox(height: 16),
                          _buildBlocked(),
                          const SizedBox(height: 16),
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
      color: _Palette.sky,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              color: _Palette.ink,
              fontWeight: FontWeight.w900,
            ),
            decoration: InputDecoration(
              hintText: _isAz ? '@login yaz' : 'Введи @логин',
              hintStyle: const TextStyle(color: _Palette.inkSoft),
              prefixIcon: const Icon(Icons.alternate_email_rounded),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: _Palette.ink,
                        ),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: _Palette.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _Palette.ink, width: 2.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _Palette.ink, width: 2.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: _Palette.ink, width: 3.2),
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
                color: _Palette.inkSoft,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          for (final user in _searchResults) ...[
            const SizedBox(height: 10),
            _SocialPersonRow(
              user: user,
              accent: _Palette.cream,
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
          color: _Palette.mint,
          onTap: () => _openChat(user),
        ),
      );
    } else if (user.requestIncoming && user.friendshipId != null) {
      widgets.add(
        _ActionIcon(
          icon: Icons.check_rounded,
          color: _Palette.lime,
          busy: _busy.contains('accept-${user.friendshipId}'),
          onTap: () => _run(
            'accept-${user.friendshipId}',
            () => _service.acceptFriendRequest(user.friendshipId!),
          ),
        ),
      );
    } else if (user.requestOutgoing) {
      widgets.add(
        const _ActionIcon(
          icon: Icons.schedule_rounded,
          color: _Palette.yellow,
          onTap: null,
        ),
      );
    } else {
      widgets.add(
        _ActionIcon(
          icon: Icons.person_add_alt_1_rounded,
          color: _Palette.lime,
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
        color: _Palette.coral,
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
      color: _Palette.mint,
      count: friends.length,
      child: friends.isEmpty
          ? Text(
              _isAz
                  ? 'Dostlar hələ yoxdur. Yuxarıdakı axtarışdan istifadə et.'
                  : 'Друзей пока нет. Найди игрока по логину выше.',
              style: const TextStyle(
                color: _Palette.inkSoft,
                fontWeight: FontWeight.w800,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < friends.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _SocialPersonRow(
                    user: friends[i],
                    accent: _Palette.cream,
                    actions: [
                      _ActionIcon(
                        icon: Icons.chat_bubble_rounded,
                        color: _Palette.sky,
                        onTap: () => _openChat(friends[i]),
                      ),
                      const SizedBox(width: 7),
                      _ActionIcon(
                        icon: Icons.person_remove_rounded,
                        color: _Palette.yellow,
                        busy: friends[i].friendshipId != null &&
                            _busy.contains('remove-${friends[i].friendshipId}'),
                        onTap: () => _removeFriend(friends[i]),
                      ),
                      const SizedBox(width: 7),
                      _ActionIcon(
                        icon: Icons.block_rounded,
                        color: _Palette.coral,
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
      color: _Palette.coral,
      count: _blocked.length,
      child: _blocked.isEmpty
          ? Text(
              _isAz ? 'Bloklanmış istifadəçi yoxdur.' : 'Чёрный список пуст.',
              style: const TextStyle(
                color: _Palette.inkSoft,
                fontWeight: FontWeight.w800,
              ),
            )
          : Column(
              children: [
                for (var i = 0; i < _blocked.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _SocialPersonRow(
                    user: _blocked[i],
                    accent: _Palette.cream,
                    actions: [
                      _ActionIcon(
                        icon: Icons.lock_open_rounded,
                        color: _Palette.mint,
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
      color: _Palette.yellow,
      child: Column(
        children: [
          _CartoonSwitchTile(
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
          _CartoonSwitchTile(
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
          _CartoonSwitchTile(
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
          _CartoonSwitchTile(
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
  final Color color;
  final int? count;
  final Widget child;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _Palette.cream,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _Palette.ink, width: 2.5),
                ),
                child: Icon(icon, color: _Palette.ink),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: _Palette.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _Palette.cream,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _Palette.ink, width: 2),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: _Palette.ink,
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

class _Panel extends StatelessWidget {
  final Color color;
  final Widget child;

  const _Panel({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _Palette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _Palette.ink,
            blurRadius: 0,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SocialPersonRow extends StatelessWidget {
  final SocialUser user;
  final Color accent;
  final List<Widget> actions;

  const _SocialPersonRow({
    required this.user,
    required this.accent,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final letter = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim().substring(0, 1).toUpperCase();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Palette.ink, width: 2.4),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: _Palette.yellow,
              shape: BoxShape.circle,
              border: Border.all(color: _Palette.ink, width: 2.3),
            ),
            child: ClipOval(
              child: user.avatarUrl == null
                  ? ColoredBox(
                      color: Colors.white,
                      child: Center(
                        child: Text(
                          letter,
                          style: const TextStyle(
                            color: _Palette.ink,
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
                        color: Colors.white,
                        child: Center(
                          child: Text(
                            letter,
                            style: const TextStyle(
                              color: _Palette.ink,
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
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Palette.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '@${user.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _Palette.inkSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
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
        opacity: onTap == null ? 0.58 : 1,
        child: Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _Palette.ink, width: 2.2),
            boxShadow: const [
              BoxShadow(
                color: _Palette.ink,
                blurRadius: 0,
                offset: Offset(2, 2),
              ),
            ],
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _Palette.ink,
                  ),
                )
              : Icon(icon, color: _Palette.ink, size: 20),
        ),
      ),
    );
  }
}

class _CartoonSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _CartoonSwitchTile({
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
      opacity: enabled ? 1 : 0.48,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 9, 7, 9),
        decoration: BoxDecoration(
          color: _Palette.cream,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _Palette.ink, width: 2.2),
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
                      color: _Palette.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _Palette.inkSoft,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: _Palette.ink,
              activeTrackColor: _Palette.lime,
              inactiveThumbColor: _Palette.ink,
              inactiveTrackColor: Colors.white,
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
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _Palette.ink, width: 2.5),
          boxShadow: const [
            BoxShadow(
              color: _Palette.ink,
              blurRadius: 0,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _Palette.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _Palette {
  static const ink = Color(0xFF16120E);
  static const inkSoft = Color(0xFF5B493B);
  static const cream = Color(0xFFFFF2D2);
  static const lime = Color(0xFF79FA00);
  static const yellow = Color(0xFFFFD55D);
  static const mint = Color(0xFF8BDD78);
  static const coral = Color(0xFFFF8175);
  static const sky = Color(0xFF79CDF1);
}
