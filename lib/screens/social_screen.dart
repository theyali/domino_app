import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/social.dart';
import '../models/user_account.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';
import '../theme/gender_style.dart';
import '../widgets/cartoon_page_background.dart';
import 'chat_screen.dart';
import 'room_lobby_screen.dart';

class SocialScreen extends StatefulWidget {
  final UserAccount currentUser;
  final ValueChanged<int>? onBadgeChanged;

  const SocialScreen({
    super.key,
    required this.currentUser,
    this.onBadgeChanged,
  });

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  static const SocialService _service = SocialService();

  Timer? _pollTimer;
  SocialOverview? _overview;
  bool _loading = true;
  bool _refreshing = false;
  final Set<String> _busyActions = <String>{};
  String? _error;

  bool get _isAz => context.appLanguage.code == 'az';

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _load(initial: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({required bool initial}) async {
    if (_refreshing) return;
    _refreshing = true;
    if (initial && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final overview = await _service.fetchOverview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _error = null;
      });
      final badgeCount = overview.invitations.length +
          overview.incomingRequests.length +
          overview.unreadMessages;
      widget.onBadgeChanged?.call(badgeCount);
    } on ApiException catch (error) {
      if (!mounted || !initial) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted || !initial) return;
      setState(() {
        _error = _isAz
            ? 'Dostları və mesajları yükləmək mümkün olmadı.'
            : 'Не удалось загрузить друзей и сообщения.';
      });
    } finally {
      _refreshing = false;
      if (mounted && initial) setState(() => _loading = false);
    }
  }

  Future<void> _runAction(String key, Future<void> Function() action) async {
    if (_busyActions.contains(key)) return;
    setState(() => _busyActions.add(key));
    try {
      await action();
      await _load(initial: false);
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage(_isAz ? 'Əməliyyat alınmadı.' : 'Не удалось выполнить действие.');
    } finally {
      if (mounted) setState(() => _busyActions.remove(key));
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
    if (mounted) await _load(initial: false);
  }

  Future<void> _removeFriend(SocialUser user) async {
    final friendshipId = user.friendshipId;
    if (friendshipId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _SocialPalette.cream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _SocialPalette.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: _SocialPalette.ink,
                blurRadius: 0,
                offset: Offset(5, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _SocialPalette.coral,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _SocialPalette.ink, width: 3),
                ),
                child: const Icon(
                  Icons.person_remove_rounded,
                  color: _SocialPalette.ink,
                  size: 30,
                ),
              ),
              const SizedBox(height: 13),
              Text(
                _isAz ? 'Dostlardan silinsin?' : 'Удалить из друзей?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _SocialPalette.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                user.displayName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: GenderStyle.colorFor(
                    user.gender,
                    fallback: _SocialPalette.inkSoft,
                  ),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _WideAction(
                      label: _isAz ? 'Ləğv et' : 'Отмена',
                      icon: Icons.arrow_back_rounded,
                      color: _SocialPalette.cream,
                      busy: false,
                      onTap: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _WideAction(
                      label: _isAz ? 'Sil' : 'Удалить',
                      icon: Icons.close_rounded,
                      color: _SocialPalette.coral,
                      busy: false,
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

    if (confirmed != true || !mounted) return;
    await _runAction(
      'friend-remove-$friendshipId',
      () => _service.removeFriendship(friendshipId),
    );
  }

  Future<void> _acceptInvitation(RoomInvitationItem invitation) async {
    final key = 'invite-accept-${invitation.id}';
    await _runAction(key, () async {
      final result = await _service.acceptInvitation(invitation.id);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CartoonPageBackground(
            child: RoomLobbyScreen(
              restaurant: result.restaurant,
              initialRoom: result.room,
              localPlayer: result.player,
            ),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CartoonPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 70,
          centerTitle: true,
          title: Text(
            _isAz ? 'Dostlar və söhbətlər' : 'Друзья и общение',
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
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _TopButton(
                icon: Icons.refresh_rounded,
                color: _SocialPalette.sky,
                onTap: _refreshing ? null : () => _load(initial: false),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: _SocialPalette.ink,
            backgroundColor: _SocialPalette.cream,
            onRefresh: () => _load(initial: false),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _overview == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator(color: _SocialPalette.ink)),
        ],
      );
    }

    if (_error != null && _overview == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 40, 18, 40),
        children: [
          _EmptyPanel(
            color: _SocialPalette.coral,
            icon: Icons.cloud_off_rounded,
            title: _isAz ? 'Yükləmək alınmadı' : 'Не удалось загрузить',
            subtitle: _error!,
          ),
        ],
      );
    }

    final overview = _overview ??
        const SocialOverview(
          friends: [],
          incomingRequests: [],
          outgoingRequests: [],
          recentPlayers: [],
          conversations: [],
          invitations: [],
        );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        if (overview.invitations.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.mark_email_unread_rounded,
            title: _isAz ? 'Masa dəvətləri' : 'Приглашения за стол',
            count: overview.invitations.length,
            color: _SocialPalette.yellow,
          ),
          const SizedBox(height: 10),
          for (final invitation in overview.invitations) ...[
            _InvitationCard(
              item: invitation,
              isAz: _isAz,
              acceptBusy: _busyActions.contains('invite-accept-${invitation.id}'),
              declineBusy: _busyActions.contains('invite-decline-${invitation.id}'),
              onAccept: () => _acceptInvitation(invitation),
              onDecline: () => _runAction(
                'invite-decline-${invitation.id}',
                () => _service.declineInvitation(invitation.id),
              ),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
        ],
        if (overview.incomingRequests.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.person_add_alt_1_rounded,
            title: _isAz ? 'Dostluq sorğuları' : 'Заявки в друзья',
            count: overview.incomingRequests.length,
            color: _SocialPalette.coral,
          ),
          const SizedBox(height: 10),
          for (final request in overview.incomingRequests) ...[
            _PersonCard(
              user: request.user,
              accent: _SocialPalette.coral,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniAction(
                    icon: Icons.check_rounded,
                    color: _SocialPalette.lime,
                    busy: _busyActions.contains('friend-accept-${request.id}'),
                    onTap: () => _runAction(
                      'friend-accept-${request.id}',
                      () => _service.acceptFriendRequest(request.id),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _MiniAction(
                    icon: Icons.close_rounded,
                    color: _SocialPalette.cream,
                    busy: _busyActions.contains('friend-remove-${request.id}'),
                    onTap: () => _runAction(
                      'friend-remove-${request.id}',
                      () => _service.declineFriendRequest(request.id),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
        ],
        if (overview.outgoingRequests.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.send_rounded,
            title: _isAz ? 'Göndərilən sorğular' : 'Отправленные заявки',
            count: overview.outgoingRequests.length,
            color: _SocialPalette.yellow,
          ),
          const SizedBox(height: 10),
          for (final request in overview.outgoingRequests) ...[
            _PersonCard(
              user: request.user,
              accent: _SocialPalette.yellow,
              trailing: _MiniAction(
                icon: Icons.person_remove_alt_1_rounded,
                color: _SocialPalette.coral,
                busy: _busyActions.contains('friend-cancel-${request.id}'),
                onTap: () => _runAction(
                  'friend-cancel-${request.id}',
                  () => _service.cancelFriendRequest(request.id),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
        ],
        _SectionHeader(
          icon: Icons.people_alt_rounded,
          title: _isAz ? 'Dostlarım' : 'Мои друзья',
          count: overview.friends.length,
          color: _SocialPalette.mint,
        ),
        const SizedBox(height: 10),
        if (overview.friends.isEmpty)
          _EmptyPanel(
            color: _SocialPalette.mint,
            icon: Icons.people_outline_rounded,
            title: _isAz ? 'Hələ dost yoxdur' : 'Пока нет друзей',
            subtitle: _isAz
                ? 'Birlikdə oynadığınız insanları aşağıdan dostlara əlavə edin.'
                : 'Добавляй в друзья людей, с которыми пересекался в играх.',
          )
        else
          for (final user in overview.friends) ...[
            _PersonCard(
              user: user,
              accent: _SocialPalette.mint,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MessageButton(
                    unread: 0,
                    onTap: () => _openChat(user),
                  ),
                  const SizedBox(width: 7),
                  _MiniAction(
                    icon: Icons.close_rounded,
                    color: _SocialPalette.coral,
                    busy: user.friendshipId != null &&
                        _busyActions.contains('friend-remove-${user.friendshipId}'),
                    onTap: user.friendshipId == null
                        ? null
                        : () => _removeFriend(user),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        _SectionHeader(
          icon: Icons.history_rounded,
          title: _isAz ? 'Birlikdə oynadıqlarım' : 'Встречались в играх',
          count: overview.recentPlayers.length,
          color: _SocialPalette.sky,
        ),
        const SizedBox(height: 10),
        if (overview.recentPlayers.isEmpty)
          _EmptyPanel(
            color: _SocialPalette.sky,
            icon: Icons.sports_esports_rounded,
            title: _isAz ? 'Hələ heç kim yoxdur' : 'Пока никого',
            subtitle: _isAz
                ? 'Başqa oyunçularla oynadıqdan sonra onlar burada görünəcək.'
                : 'После игр с другими людьми они появятся здесь.',
          )
        else
          for (final user in overview.recentPlayers) ...[
            _RecentPlayerCard(
              user: user,
              busy: _busyActions.contains('friend-send-${user.id}') ||
                  (user.friendshipId != null &&
                      _busyActions.contains('friend-cancel-${user.friendshipId}')),
              onMessage: () => _openChat(user),
              onAddFriend: user.friendshipStatus == 'none'
                  ? () => _runAction(
                        'friend-send-${user.id}',
                        () => _service.sendFriendRequest(user.id),
                      )
                  : null,
              onAccept: user.requestIncoming && user.friendshipId != null
                  ? () => _runAction(
                        'friend-accept-${user.friendshipId}',
                        () => _service.acceptFriendRequest(user.friendshipId!),
                      )
                  : null,
              onCancel: user.requestOutgoing && user.friendshipId != null
                  ? () => _runAction(
                        'friend-cancel-${user.friendshipId}',
                        () => _service.cancelFriendRequest(user.friendshipId!),
                      )
                  : null,
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        _SectionHeader(
          icon: Icons.forum_rounded,
          title: _isAz ? 'Şəxsi mesajlar' : 'Личные сообщения',
          count: overview.conversations.length,
          color: _SocialPalette.yellow,
        ),
        const SizedBox(height: 10),
        if (overview.conversations.isEmpty)
          _EmptyPanel(
            color: _SocialPalette.yellow,
            icon: Icons.chat_bubble_outline_rounded,
            title: _isAz ? 'Söhbət yoxdur' : 'Диалогов пока нет',
            subtitle: _isAz
                ? 'Dosta və ya birlikdə oynadığınız oyunçuya yazın.'
                : 'Напиши другу или игроку, с которым вы уже играли.',
          )
        else
          for (final chat in overview.conversations) ...[
            _ConversationCard(
              chat: chat,
              onTap: () => _openChat(chat.user),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _SocialPalette.ink, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: _SocialPalette.ink,
                blurRadius: 0,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: Icon(icon, color: _SocialPalette.ink, size: 24),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  color: Colors.black87,
                  offset: Offset(2, 2),
                  blurRadius: 0,
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _SocialPalette.cream,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _SocialPalette.ink, width: 2.2),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: _SocialPalette.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  final SocialUser user;
  final Color accent;
  final Widget trailing;

  const _PersonCard({
    required this.user,
    required this.accent,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _SocialPalette.ink, width: 2.8),
        boxShadow: const [
          BoxShadow(
            color: _SocialPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _Avatar(user: user, size: 52),
          const SizedBox(width: 11),
          Expanded(child: _UserText(user: user)),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _RecentPlayerCard extends StatelessWidget {
  final SocialUser user;
  final bool busy;
  final VoidCallback onMessage;
  final VoidCallback? onAddFriend;
  final VoidCallback? onAccept;
  final VoidCallback? onCancel;

  const _RecentPlayerCard({
    required this.user,
    required this.busy,
    required this.onMessage,
    required this.onAddFriend,
    required this.onAccept,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return _PersonCard(
      user: user,
      accent: _SocialPalette.sky,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniAction(
            icon: Icons.chat_bubble_rounded,
            color: _SocialPalette.cream,
            onTap: onMessage,
          ),
          const SizedBox(width: 7),
          if (user.isFriend)
            const _StatusChip(icon: Icons.people_alt_rounded, label: '✓')
          else if (user.requestOutgoing && onCancel != null)
            _MiniAction(
              icon: Icons.person_remove_alt_1_rounded,
              color: _SocialPalette.coral,
              busy: busy,
              onTap: onCancel,
            )
          else if (user.requestOutgoing)
            const _StatusChip(icon: Icons.schedule_rounded, label: '…')
          else if (onAccept != null)
            _MiniAction(
              icon: Icons.person_add_alt_1_rounded,
              color: _SocialPalette.lime,
              busy: busy,
              onTap: onAccept,
            )
          else
            _MiniAction(
              icon: Icons.person_add_alt_1_rounded,
              color: _SocialPalette.lime,
              busy: busy,
              onTap: onAddFriend,
            ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  final ChatPreview chat;
  final VoidCallback onTap;

  const _ConversationCard({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nameColor = GenderStyle.colorFor(
      chat.user.gender,
      fallback: _SocialPalette.ink,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _SocialPalette.cream,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: _SocialPalette.ink, width: 2.8),
          boxShadow: const [
            BoxShadow(
              color: _SocialPalette.ink,
              blurRadius: 0,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _Avatar(user: chat.user, size: 52),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat.user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: nameColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _SocialPalette.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (chat.unreadCount > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 30),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: _SocialPalette.coral,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _SocialPalette.ink, width: 2),
                ),
                child: Text(
                  '${chat.unreadCount}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _SocialPalette.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded, size: 28),
          ],
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  final RoomInvitationItem item;
  final bool isAz;
  final bool acceptBusy;
  final bool declineBusy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _InvitationCard({
    required this.item,
    required this.isAz,
    required this.acceptBusy,
    required this.declineBusy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final nameColor = GenderStyle.colorFor(
      item.sender.gender,
      fallback: _SocialPalette.ink,
    );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _SocialPalette.yellow,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _SocialPalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _SocialPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _Avatar(user: item.sender, size: 54),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.sender.displayName,
                      style: TextStyle(
                        color: nameColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      isAz
                          ? '${item.restaurantName} · ${item.roomName} masasına dəvət edir'
                          : 'Зовёт в ${item.restaurantName} · ${item.roomName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _SocialPalette.inkSoft,
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _WideAction(
                  label: isAz ? 'Qəbul et' : 'Принять',
                  icon: Icons.check_rounded,
                  color: _SocialPalette.lime,
                  busy: acceptBusy,
                  onTap: onAccept,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _WideAction(
                  label: isAz ? 'Rədd et' : 'Отклонить',
                  icon: Icons.close_rounded,
                  color: _SocialPalette.cream,
                  busy: declineBusy,
                  onTap: onDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UserText extends StatelessWidget {
  final SocialUser user;

  const _UserText({required this.user});

  @override
  Widget build(BuildContext context) {
    final genderColor = GenderStyle.colorFor(
      user.gender,
      fallback: _SocialPalette.ink,
    );
    return Column(
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
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (user.isOnline) ...[
              const SizedBox(width: 6),
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFF1FC968),
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
          style: TextStyle(
            color: genderColor,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  final SocialUser user;
  final double size;

  const _Avatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    final letterColor = GenderStyle.colorFor(
      user.gender,
      fallback: _SocialPalette.ink,
    );
    final letter = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim().substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _SocialPalette.yellow,
        shape: BoxShape.circle,
        border: Border.all(color: _SocialPalette.ink, width: 2.5),
      ),
      child: ClipOval(
        child: user.avatarUrl != null
            ? Image.network(
                user.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    _AvatarLetter(letter: letter, color: letterColor),
              )
            : _AvatarLetter(letter: letter, color: letterColor),
      ),
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  final String letter;
  final Color color;

  const _AvatarLetter({required this.letter, required this.color});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _SocialPalette.cream,
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MiniAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final bool busy;

  const _MiniAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _SocialPalette.ink, width: 2.4),
          boxShadow: const [
            BoxShadow(
              color: _SocialPalette.ink,
              blurRadius: 0,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: busy
            ? const Padding(
                padding: EdgeInsets.all(11),
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _SocialPalette.ink,
                ),
              )
            : Icon(icon, color: _SocialPalette.ink, size: 21),
      ),
    );
  }
}

class _WideAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool busy;

  const _WideAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _SocialPalette.ink, width: 2.4),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: _SocialPalette.ink,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _SocialPalette.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MessageButton extends StatelessWidget {
  final int unread;
  final VoidCallback onTap;

  const _MessageButton({required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _MiniAction(
      icon: Icons.chat_bubble_rounded,
      color: unread > 0 ? _SocialPalette.coral : _SocialPalette.cream,
      onTap: onTap,
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _SocialPalette.cream,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _SocialPalette.ink, width: 2.4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 20),
          Positioned(
            right: 4,
            bottom: 2,
            child: Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyPanel({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _SocialPalette.ink, width: 2.8),
        boxShadow: const [
          BoxShadow(
            color: _SocialPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 38, color: _SocialPalette.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _SocialPalette.ink,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _SocialPalette.inkSoft,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
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

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;

  const _TopButton({
    required this.icon,
    required this.onTap,
    this.color = _SocialPalette.cream,
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
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _SocialPalette.ink, width: 2.6),
            boxShadow: const [
              BoxShadow(
                color: _SocialPalette.ink,
                blurRadius: 0,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: Icon(icon, color: _SocialPalette.ink, size: 21),
        ),
      ),
    );
  }
}

class _SocialPalette {
  static const ink = Color(0xFF111111);
  static const inkSoft = Color(0xFF58483B);
  static const cream = Color(0xFFFFF3D6);
  static const lime = Color(0xFF79FA00);
  static const yellow = Color(0xFFFFD65C);
  static const mint = Color(0xFF8CDD79);
  static const coral = Color(0xFFFF8175);
  static const sky = Color(0xFF79CDF1);
}
