import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/social.dart';
import '../models/user_account.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';
import '../theme/gender_style.dart';
import '../theme/play_palette.dart';
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
      _showMessage(
        _isAz ? 'Əməliyyat alınmadı.' : 'Не удалось выполнить действие.',
      );
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
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: PlayPalette.navy,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _SocialPalette.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _SocialPalette.surfaceRaised,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.person_remove_rounded,
                  color: Colors.white,
                  size: 29,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                _isAz ? 'Dostlardan silinsin?' : 'Удалить из друзей?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
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
                    fallback: PlayPalette.muted,
                  ),
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: _WideAction(
                      label: _isAz ? 'Ləğv et' : 'Отмена',
                      icon: Icons.arrow_back_rounded,
                      primary: false,
                      busy: false,
                      onTap: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _WideAction(
                      label: _isAz ? 'Sil' : 'Удалить',
                      icon: Icons.delete_outline_rounded,
                      primary: true,
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
          elevation: 0,
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
              letterSpacing: -0.35,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: _TopButton(
                icon: Icons.refresh_rounded,
                onTap: _refreshing ? null : () => _load(initial: false),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            color: PlayPalette.blue,
            backgroundColor: PlayPalette.navy,
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
          Center(child: CircularProgressIndicator(color: PlayPalette.blue)),
        ],
      );
    }

    if (_error != null && _overview == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 40, 14, 40),
        children: [
          _EmptyPanel(
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
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 42),
      children: [
        if (overview.invitations.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.mark_email_unread_rounded,
            title: _isAz ? 'Masa dəvətləri' : 'Приглашения за стол',
            count: overview.invitations.length,
          ),
          const SizedBox(height: 10),
          for (final invitation in overview.invitations) ...[
            _InvitationCard(
              item: invitation,
              isAz: _isAz,
              acceptBusy:
                  _busyActions.contains('invite-accept-${invitation.id}'),
              declineBusy:
                  _busyActions.contains('invite-decline-${invitation.id}'),
              onAccept: () => _acceptInvitation(invitation),
              onDecline: () => _runAction(
                'invite-decline-${invitation.id}',
                () => _service.declineInvitation(invitation.id),
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 12),
        ],
        if (overview.incomingRequests.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.person_add_alt_1_rounded,
            title: _isAz ? 'Dostluq sorğuları' : 'Заявки в друзья',
            count: overview.incomingRequests.length,
          ),
          const SizedBox(height: 10),
          for (final request in overview.incomingRequests) ...[
            _PersonCard(
              user: request.user,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniAction(
                    icon: Icons.check_rounded,
                    primary: true,
                    busy: _busyActions.contains('friend-accept-${request.id}'),
                    onTap: () => _runAction(
                      'friend-accept-${request.id}',
                      () => _service.acceptFriendRequest(request.id),
                    ),
                  ),
                  const SizedBox(width: 7),
                  _MiniAction(
                    icon: Icons.close_rounded,
                    busy: _busyActions.contains('friend-remove-${request.id}'),
                    onTap: () => _runAction(
                      'friend-remove-${request.id}',
                      () => _service.declineFriendRequest(request.id),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 12),
        ],
        if (overview.outgoingRequests.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.send_rounded,
            title: _isAz ? 'Göndərilən sorğular' : 'Отправленные заявки',
            count: overview.outgoingRequests.length,
          ),
          const SizedBox(height: 10),
          for (final request in overview.outgoingRequests) ...[
            _PersonCard(
              user: request.user,
              trailing: _MiniAction(
                icon: Icons.person_remove_alt_1_rounded,
                busy: _busyActions.contains('friend-cancel-${request.id}'),
                onTap: () => _runAction(
                  'friend-cancel-${request.id}',
                  () => _service.cancelFriendRequest(request.id),
                ),
              ),
            ),
            const SizedBox(height: 9),
          ],
          const SizedBox(height: 12),
        ],
        _SectionHeader(
          icon: Icons.people_alt_rounded,
          title: _isAz ? 'Dostlarım' : 'Мои друзья',
          count: overview.friends.length,
        ),
        const SizedBox(height: 10),
        if (overview.friends.isEmpty)
          _EmptyPanel(
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MiniAction(
                    icon: Icons.chat_bubble_rounded,
                    primary: true,
                    onTap: () => _openChat(user),
                  ),
                  const SizedBox(width: 7),
                  _MiniAction(
                    icon: Icons.person_remove_alt_1_rounded,
                    busy: user.friendshipId != null &&
                        _busyActions.contains(
                          'friend-remove-${user.friendshipId}',
                        ),
                    onTap: user.friendshipId == null
                        ? null
                        : () => _removeFriend(user),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
          ],
        const SizedBox(height: 20),
        _SectionHeader(
          icon: Icons.history_rounded,
          title: _isAz ? 'Birlikdə oynadıqlarım' : 'Встречались в играх',
          count: overview.recentPlayers.length,
        ),
        const SizedBox(height: 10),
        if (overview.recentPlayers.isEmpty)
          _EmptyPanel(
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
                      _busyActions.contains(
                        'friend-cancel-${user.friendshipId}',
                      )),
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
            const SizedBox(height: 9),
          ],
        const SizedBox(height: 20),
        _SectionHeader(
          icon: Icons.forum_rounded,
          title: _isAz ? 'Şəxsi mesajlar' : 'Личные сообщения',
          count: overview.conversations.length,
        ),
        const SizedBox(height: 10),
        if (overview.conversations.isEmpty)
          _EmptyPanel(
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
            const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PlayPalette.navy,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _SocialPalette.border),
          ),
          child: const IconTheme(
            data: IconThemeData(color: Colors.white, size: 23),
            child: SizedBox.shrink(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ),
        Container(
          constraints: const BoxConstraints(minWidth: 38),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PlayPalette.navy,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _SocialPalette.border),
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

class _PersonCard extends StatelessWidget {
  final SocialUser user;
  final Widget trailing;

  const _PersonCard({required this.user, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PlayPalette.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _SocialPalette.border),
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MiniAction(
            icon: Icons.chat_bubble_rounded,
            onTap: onMessage,
          ),
          const SizedBox(width: 7),
          if (user.isFriend)
            const _StatusChip(icon: Icons.people_alt_rounded, label: '✓')
          else if (user.requestOutgoing && onCancel != null)
            _MiniAction(
              icon: Icons.person_remove_alt_1_rounded,
              busy: busy,
              onTap: onCancel,
            )
          else if (user.requestOutgoing)
            const _StatusChip(icon: Icons.schedule_rounded, label: '…')
          else if (onAccept != null)
            _MiniAction(
              icon: Icons.person_add_alt_1_rounded,
              primary: true,
              busy: busy,
              onTap: onAccept,
            )
          else
            _MiniAction(
              icon: Icons.person_add_alt_1_rounded,
              primary: true,
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
      fallback: Colors.white,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: PlayPalette.navy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _SocialPalette.border),
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
                      color: PlayPalette.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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
                  color: PlayPalette.blue,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text(
                  '${chat.unreadCount}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            else
              const Icon(
                Icons.chevron_right_rounded,
                color: PlayPalette.muted,
                size: 28,
              ),
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
      fallback: Colors.white,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PlayPalette.navy,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _SocialPalette.border),
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
                    const SizedBox(height: 3),
                    Text(
                      isAz
                          ? '${item.restaurantName} · ${item.roomName} masasına dəvət edir'
                          : 'Зовёт в ${item.restaurantName} · ${item.roomName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PlayPalette.muted,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
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
                  primary: true,
                  busy: acceptBusy,
                  onTap: onAccept,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _WideAction(
                  label: isAz ? 'Rədd et' : 'Отклонить',
                  icon: Icons.close_rounded,
                  primary: false,
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
      fallback: Colors.white,
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
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: PlayPalette.green,
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
            color: PlayPalette.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
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
      fallback: Colors.white,
    );
    final letter = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim().substring(0, 1).toUpperCase();

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _SocialPalette.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: _SocialPalette.border),
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
      color: _SocialPalette.surfaceRaised,
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
  final VoidCallback? onTap;
  final bool busy;
  final bool primary;

  const _MiniAction({
    required this.icon,
    required this.onTap,
    this.busy = false,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? PlayPalette.blue : _SocialPalette.surfaceRaised,
            borderRadius: BorderRadius.circular(13),
            border: primary ? null : Border.all(color: _SocialPalette.border),
          ),
          child: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
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

class _WideAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool busy;
  final bool primary;

  const _WideAction({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.busy,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: busy ? null : onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: primary ? PlayPalette.blue : _SocialPalette.surfaceRaised,
          borderRadius: BorderRadius.circular(14),
          border: primary ? null : Border.all(color: _SocialPalette.border),
        ),
        child: busy
            ? const Center(
                child: SizedBox(
                  width: 19,
                  height: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 19),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
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
        color: _SocialPalette.surfaceRaised,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _SocialPalette.border),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 19),
          Positioned(
            right: 4,
            bottom: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: PlayPalette.navy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _SocialPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _SocialPalette.surfaceRaised,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 27, color: Colors.white),
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
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: PlayPalette.muted,
                    fontSize: 12,
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

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _TopButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PlayPalette.blue,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _SocialPalette {
  static const border = Color(0xFF3A3A3E);
  static const surfaceRaised = Color(0xFF323234);
}
