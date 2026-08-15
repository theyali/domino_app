import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/social.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';

class InvitePlayersSheet extends StatefulWidget {
  final int roomId;

  const InvitePlayersSheet({
    super.key,
    required this.roomId,
  });

  static Future<int?> show(
    BuildContext context, {
    required int roomId,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) => InvitePlayersSheet(roomId: roomId),
    );
  }

  @override
  State<InvitePlayersSheet> createState() => _InvitePlayersSheetState();
}

class _InvitePlayersSheetState extends State<InvitePlayersSheet> {
  static const SocialService _service = SocialService();

  final Set<int> _selected = <int>{};
  List<SocialUser> _users = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  bool get _isAz => context.appLanguage.code == 'az';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _service.fetchOnlineUsers(roomId: widget.roomId);
      if (!mounted) return;
      setState(() {
        _users = users;
        _selected.removeWhere((id) => !users.any((item) => item.id == id));
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _isAz
            ? 'Onlayn oyunçuları yükləmək mümkün olmadı.'
            : 'Не удалось загрузить игроков онлайн.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _selected.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final sent = await _service.sendRoomInvitations(
        roomId: widget.roomId,
        userIds: _selected.toList(growable: false),
      );
      if (!mounted) return;
      Navigator.pop(context, sent);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = _isAz
            ? 'Dəvətləri göndərmək mümkün olmadı.'
            : 'Не удалось отправить приглашения.';
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: FractionallySizedBox(
        heightFactor: 0.86,
        child: Container(
          decoration: const BoxDecoration(
            color: _InvitePalette.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(color: _InvitePalette.ink, width: 3),
              left: BorderSide(color: _InvitePalette.ink, width: 3),
              right: BorderSide(color: _InvitePalette.ink, width: 3),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 58,
                height: 7,
                decoration: BoxDecoration(
                  color: _InvitePalette.ink,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isAz ? 'Masaya dəvət et' : 'Пригласить за стол',
                            style: const TextStyle(
                              color: _InvitePalette.ink,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isAz
                                ? 'Onlayn oyunçuları soldakı işarə ilə seçin.'
                                : 'Отметь галочкой слева игроков, которых хочешь позвать.',
                            style: const TextStyle(
                              color: _InvitePalette.inkSoft,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SmallButton(
                      icon: Icons.refresh_rounded,
                      color: _InvitePalette.sky,
                      onTap: _loading ? null : _load,
                    ),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
                  child: _ErrorBox(text: _error!),
                ),
              Expanded(child: _buildList()),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                child: SafeArea(
                  top: false,
                  child: GestureDetector(
                    onTap: _selected.isEmpty || _sending ? null : _send,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 140),
                      opacity: _selected.isEmpty || _sending ? 0.55 : 1,
                      child: Container(
                        width: double.infinity,
                        height: 58,
                        decoration: BoxDecoration(
                          color: _InvitePalette.lime,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _InvitePalette.ink, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: _InvitePalette.ink,
                              blurRadius: 0,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: _sending
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.8,
                                  color: _InvitePalette.ink,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded, size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isAz
                                        ? 'Dəvət göndər (${_selected.length})'
                                        : 'Отправить приглашение (${_selected.length})',
                                    style: const TextStyle(
                                      color: _InvitePalette.ink,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_loading && _users.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: _InvitePalette.ink),
      );
    }
    if (_users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_outline_rounded, size: 58),
              const SizedBox(height: 12),
              Text(
                _isAz
                    ? 'Hazırda dəvət ediləcək onlayn oyunçu yoxdur.'
                    : 'Сейчас нет онлайн-игроков, которых можно пригласить.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _InvitePalette.inkSoft,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = _users[index];
        final selected = _selected.contains(user.id);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() {
              selected ? _selected.remove(user.id) : _selected.add(user.id);
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? _InvitePalette.yellow : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _InvitePalette.ink, width: 2.6),
              boxShadow: const [
                BoxShadow(
                  color: _InvitePalette.ink,
                  blurRadius: 0,
                  offset: Offset(2, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? _InvitePalette.lime : _InvitePalette.cream,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: _InvitePalette.ink, width: 2.4),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded, size: 23)
                      : null,
                ),
                const SizedBox(width: 11),
                _Avatar(user: user),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _InvitePalette.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '@${user.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _InvitePalette.inkSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: _InvitePalette.mint,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _InvitePalette.ink, width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF25C868),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isAz ? 'Onlayn' : 'Онлайн',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final SocialUser user;

  const _Avatar({required this.user});

  @override
  Widget build(BuildContext context) {
    final letter = user.displayName.trim().isEmpty
        ? '?'
        : user.displayName.trim().substring(0, 1).toUpperCase();
    return Container(
      width: 50,
      height: 50,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: _InvitePalette.yellow,
        shape: BoxShape.circle,
        border: Border.all(color: _InvitePalette.ink, width: 2.6),
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
      color: _InvitePalette.cream,
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: _InvitePalette.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _SmallButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _InvitePalette.ink, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: _InvitePalette.ink,
                blurRadius: 0,
                offset: Offset(2, 3),
              ),
            ],
          ),
          child: Icon(icon, color: _InvitePalette.ink),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _InvitePalette.coral,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _InvitePalette.ink, width: 2.4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _InvitePalette.ink,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InvitePalette {
  static const ink = Color(0xFF111111);
  static const inkSoft = Color(0xFF5A493C);
  static const cream = Color(0xFFFFF3D6);
  static const lime = Color(0xFF79FA00);
  static const yellow = Color(0xFFFFD65C);
  static const mint = Color(0xFF8CDD79);
  static const coral = Color(0xFFFF8175);
  static const sky = Color(0xFF79CDF1);
}
