import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/social.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';
import '../widgets/cartoon_page_background.dart';

class ChatScreen extends StatefulWidget {
  final int currentUserId;
  final SocialUser user;

  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.user,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  static const SocialService _service = SocialService();

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;
  DirectMessageThread? _thread;
  bool _loading = true;
  bool _sending = false;
  bool _polling = false;
  bool _socialActionBusy = false;
  String? _error;

  bool get _isAz => context.appLanguage.code == 'az';
  SocialUser get _currentUser => _thread?.user ?? widget.user;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _load(initial: false);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load({required bool initial}) async {
    if (_polling) return;
    _polling = true;
    if (initial && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final thread = await _service.fetchMessages(widget.user.id);
      if (!mounted) return;
      final oldLastId = _thread?.messages.isEmpty == false
          ? _thread!.messages.last.id
          : null;
      final newLastId = thread.messages.isEmpty ? null : thread.messages.last.id;
      setState(() {
        _thread = thread;
        _error = null;
      });
      if (initial || oldLastId != newLastId) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      }
    } on ApiException catch (error) {
      if (!mounted || !initial) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted || !initial) return;
      setState(() {
        _error = _isAz
            ? 'Mesajları yükləmək mümkün olmadı.'
            : 'Не удалось загрузить сообщения.';
      });
    } finally {
      _polling = false;
      if (mounted && initial) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (_sending || body.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    _controller.clear();
    try {
      final message = await _service.sendMessage(
        userId: widget.user.id,
        body: body,
      );
      if (!mounted) return;
      final current = _thread;
      if (current != null) {
        setState(() {
          _thread = DirectMessageThread(
            user: current.user,
            messages: [...current.messages, message],
          );
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      } else {
        await _load(initial: true);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      _controller.text = body;
      _controller.selection = TextSelection.collapsed(offset: body.length);
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      _controller.text = body;
      _controller.selection = TextSelection.collapsed(offset: body.length);
      setState(() {
        _error = _isAz
            ? 'Mesajı göndərmək mümkün olmadı.'
            : 'Не удалось отправить сообщение.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<bool> _confirmSocialAction({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _ChatPalette.cream,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _ChatPalette.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: _ChatPalette.ink,
                blurRadius: 0,
                offset: Offset(5, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _ChatPalette.ink, width: 3),
                ),
                child: Icon(icon, color: _ChatPalette.ink, size: 31),
              ),
              const SizedBox(height: 13),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ChatPalette.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ChatPalette.inkSoft,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: _isAz ? 'Ləğv et' : 'Отмена',
                      color: _ChatPalette.cream,
                      onTap: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _DialogButton(
                      label: confirmLabel,
                      color: color,
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
    return result == true;
  }

  Future<void> _removeFriend() async {
    final user = _currentUser;
    final friendshipId = user.friendshipId;
    if (_socialActionBusy || friendshipId == null || !user.isFriend) return;

    final confirmed = await _confirmSocialAction(
      icon: Icons.person_remove_rounded,
      color: _ChatPalette.coral,
      title: _isAz ? 'Dostlardan silinsin?' : 'Удалить из друзей?',
      subtitle: _isAz
          ? '${user.displayName} artıq dostlar siyahısında olmayacaq.'
          : '${user.displayName} будет удалён из списка друзей.',
      confirmLabel: _isAz ? 'Sil' : 'Удалить',
    );
    if (!confirmed || !mounted) return;

    setState(() => _socialActionBusy = true);
    try {
      await _service.removeFriendship(friendshipId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _isAz
            ? 'Dostlardan silmək mümkün olmadı.'
            : 'Не удалось удалить из друзей.';
      });
    } finally {
      if (mounted) setState(() => _socialActionBusy = false);
    }
  }

  Future<void> _blockUser() async {
    final user = _currentUser;
    if (_socialActionBusy) return;

    final confirmed = await _confirmSocialAction(
      icon: Icons.block_rounded,
      color: _ChatPalette.yellow,
      title: _isAz ? 'Qara siyahıya əlavə edilsin?' : 'Добавить в чёрный список?',
      subtitle: _isAz
          ? '${user.displayName} sizə yaza, dostluq sorğusu və oyun dəvəti göndərə bilməyəcək.'
          : '${user.displayName} больше не сможет писать тебе, добавляться в друзья и приглашать за стол.',
      confirmLabel: _isAz ? 'Blokla' : 'В ЧС',
    );
    if (!confirmed || !mounted) return;

    setState(() => _socialActionBusy = true);
    try {
      await _service.blockUser(user.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _isAz
            ? 'İstifadəçini bloklamaq mümkün olmadı.'
            : 'Не удалось добавить пользователя в чёрный список.';
      });
    } finally {
      if (mounted) setState(() => _socialActionBusy = false);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    return CartoonPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: 70,
          leadingWidth: 64,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _TopButton(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => Navigator.maybePop(context),
            ),
          ),
          titleSpacing: 6,
          title: Row(
            children: [
              _Avatar(user: user, size: 42),
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
                        color: Colors.white,
                        fontSize: 18,
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
                    Text(
                      user.isOnline
                          ? (_isAz ? 'Onlayn' : 'Онлайн')
                          : '@${user.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFFE9B9),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (user.isFriend && user.friendshipId != null)
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: _HeaderAction(
                  icon: Icons.close_rounded,
                  color: _ChatPalette.coral,
                  busy: _socialActionBusy,
                  tooltip: _isAz ? 'Dostlardan sil' : 'Удалить из друзей',
                  onTap: _removeFriend,
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _HeaderAction(
                icon: Icons.block_rounded,
                color: _ChatPalette.yellow,
                busy: _socialActionBusy,
                tooltip: _isAz ? 'Qara siyahı' : 'В чёрный список',
                onTap: _blockUser,
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                  child: _ErrorBox(text: _error!),
                ),
              Expanded(child: _buildMessages()),
              _Composer(
                controller: _controller,
                sending: _sending,
                isAz: _isAz,
                onSend: _send,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessages() {
    if (_loading && _thread == null) {
      return const Center(
        child: CircularProgressIndicator(color: _ChatPalette.ink),
      );
    }
    final messages = _thread?.messages ?? const <DirectMessageItem>[];
    if (messages.isEmpty) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(28),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: _ChatPalette.sky,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _ChatPalette.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: _ChatPalette.ink,
                blurRadius: 0,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 48,
                color: _ChatPalette.ink,
              ),
              const SizedBox(height: 10),
              Text(
                _isAz
                    ? 'Söhbətə ilk mesajla başla.'
                    : 'Начни разговор с первого сообщения.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _ChatPalette.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final mine = message.senderId == widget.currentUserId;
        return Align(
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.76,
            ),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: mine ? _ChatPalette.lime : _ChatPalette.cream,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(mine ? 18 : 5),
                bottomRight: Radius.circular(mine ? 5 : 18),
              ),
              border: Border.all(color: _ChatPalette.ink, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: _ChatPalette.ink,
                  blurRadius: 0,
                  offset: Offset(2, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    message.body,
                    style: const TextStyle(
                      color: _ChatPalette.ink,
                      fontSize: 15,
                      height: 1.28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(message.createdAt),
                  style: const TextStyle(
                    color: _ChatPalette.inkSoft,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final bool isAz;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.sending,
    required this.isAz,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF4CF7A),
        border: Border(top: BorderSide(color: _ChatPalette.ink, width: 3)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: !sending,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                cursorColor: _ChatPalette.ink,
                style: const TextStyle(
                  color: _ChatPalette.ink,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: isAz ? 'Mesaj...' : 'Сообщение...',
                  hintStyle: const TextStyle(
                    color: _ChatPalette.inkSoft,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  filled: true,
                  fillColor: _ChatPalette.cream,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: _ChatPalette.ink,
                      width: 2.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: _ChatPalette.ink,
                      width: 3,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: const BorderSide(
                      color: _ChatPalette.ink,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 9),
            GestureDetector(
              onTap: sending ? null : onSend,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _ChatPalette.coral,
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: _ChatPalette.ink, width: 2.8),
                  boxShadow: const [
                    BoxShadow(
                      color: _ChatPalette.ink,
                      blurRadius: 0,
                      offset: Offset(2, 3),
                    ),
                  ],
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _ChatPalette.ink,
                        ),
                      )
                    : const Icon(
                        Icons.send_rounded,
                        size: 25,
                        color: _ChatPalette.ink,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final SocialUser user;
  final double size;

  const _Avatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    final letter = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim().substring(0, 1).toUpperCase();
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _ChatPalette.yellow,
        shape: BoxShape.circle,
        border: Border.all(color: _ChatPalette.ink, width: 2.4),
      ),
      child: ClipOval(
        child: user.avatarUrl != null
            ? Image.network(
                user.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _AvatarLetter(letter: letter),
              )
            : _AvatarLetter(letter: letter),
      ),
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  final String letter;

  const _AvatarLetter({required this.letter});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _ChatPalette.cream,
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: _ChatPalette.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _TopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 43,
        height: 43,
        decoration: BoxDecoration(
          color: _ChatPalette.cream,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _ChatPalette.ink, width: 2.6),
          boxShadow: const [
            BoxShadow(
              color: _ChatPalette.ink,
              blurRadius: 0,
              offset: Offset(2, 3),
            ),
          ],
        ),
        child: Icon(icon, color: _ChatPalette.ink, size: 21),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool busy;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.color,
    required this.busy,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        child: Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _ChatPalette.ink, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: _ChatPalette.ink,
                blurRadius: 0,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: _ChatPalette.ink,
                  ),
                )
              : Icon(icon, color: _ChatPalette.ink, size: 21),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DialogButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _ChatPalette.ink, width: 2.4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _ChatPalette.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String text;

  const _ErrorBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _ChatPalette.coral,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ChatPalette.ink, width: 2.4),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ChatPalette.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ChatPalette {
  static const ink = Color(0xFF111111);
  static const inkSoft = Color(0xFF5B4A3B);
  static const cream = Color(0xFFFFF3D6);
  static const lime = Color(0xFF79FA00);
  static const yellow = Color(0xFFFFD65C);
  static const coral = Color(0xFFFF8175);
  static const sky = Color(0xFF79CDF1);
}
