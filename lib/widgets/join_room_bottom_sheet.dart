import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/game_room.dart';

class JoinRoomRequest {
  final String password;

  const JoinRoomRequest({required this.password});
}

class JoinRoomBottomSheet extends StatefulWidget {
  final GameRoom room;

  const JoinRoomBottomSheet({
    super.key,
    required this.room,
  });

  @override
  State<JoinRoomBottomSheet> createState() => _JoinRoomBottomSheetState();
}

class _JoinRoomBottomSheetState extends State<JoinRoomBottomSheet> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();

    // Для открытого стола подтверждение не нужно: сразу возвращаем запрос
    // на вход родительскому экрану. Bottom sheet остаётся только для пароля.
    if (!widget.room.isLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _submit();
      });
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      JoinRoomRequest(password: _passwordController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Открытые столы не показывают окно подтверждения вообще.
    if (!widget.room.isLocked) {
      return const SizedBox.shrink();
    }

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: _JoinRoomPalette.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
          border: Border(
            top: BorderSide(color: _JoinRoomPalette.ink, width: 3),
            left: BorderSide(color: _JoinRoomPalette.ink, width: 3),
            right: BorderSide(color: _JoinRoomPalette.ink, width: 3),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(18, 10, 18, 18 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 54,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _JoinRoomPalette.ink,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Transform.rotate(
                      angle: -0.07,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: _JoinRoomPalette.skyBlue,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: _JoinRoomPalette.ink,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: _JoinRoomPalette.ink,
                              blurRadius: 0,
                              offset: Offset(3, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: _JoinRoomPalette.ink,
                          size: 29,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.room.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _JoinRoomPalette.ink,
                              fontSize: 27,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            context.tr('join_account_description'),
                            style: const TextStyle(
                              color: _JoinRoomPalette.inkSoft,
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _JoinRoomPalette.yellow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _JoinRoomPalette.ink,
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: _JoinRoomPalette.ink,
                        blurRadius: 0,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _JoinRoomPalette.ink,
                            width: 2.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          color: _JoinRoomPalette.ink,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          context.tr(
                            'room_players',
                            arguments: {
                              'current': widget.room.currentPlayers,
                              'max': widget.room.maxPlayers,
                            },
                          ),
                          style: const TextStyle(
                            color: _JoinRoomPalette.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _JoinRoomPalette.coral,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _JoinRoomPalette.ink,
                            width: 2.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: _JoinRoomPalette.ink,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _JoinRoomPalette.coral,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _JoinRoomPalette.ink,
                          width: 2.4,
                        ),
                      ),
                      child: const Icon(
                        Icons.key_rounded,
                        color: _JoinRoomPalette.ink,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      context.tr('room_password'),
                      style: const TextStyle(
                        color: _JoinRoomPalette.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _JoinPasswordField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _submit(),
                  onToggleVisibility: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                const SizedBox(height: 26),
                _JoinButton(
                  label: context.tr('join_table'),
                  onTap: _submit,
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscureText;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onToggleVisibility;

  const _JoinPasswordField({
    required this.controller,
    required this.obscureText,
    required this.onSubmitted,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(19),
      borderSide: const BorderSide(
        color: _JoinRoomPalette.ink,
        width: 2.8,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        boxShadow: const [
          BoxShadow(
            color: _JoinRoomPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        maxLength: 64,
        onSubmitted: onSubmitted,
        cursorColor: _JoinRoomPalette.ink,
        style: const TextStyle(
          color: _JoinRoomPalette.ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: context.tr('room_password'),
          hintStyle: const TextStyle(
            color: _JoinRoomPalette.inkSoft,
            fontWeight: FontWeight.w700,
          ),
          counterText: '',
          filled: true,
          fillColor: _JoinRoomPalette.paper,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 17,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 62,
            minHeight: 58,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: _JoinRoomPalette.coral,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: _JoinRoomPalette.ink,
                  width: 2.2,
                ),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: _JoinRoomPalette.ink,
                size: 22,
              ),
            ),
          ),
          suffixIcon: IconButton(
            onPressed: onToggleVisibility,
            color: _JoinRoomPalette.ink,
            splashRadius: 22,
            icon: Icon(
              obscureText
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
            ),
          ),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(
              color: _JoinRoomPalette.ink,
              width: 3.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _JoinButton({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 62,
        decoration: BoxDecoration(
          color: _JoinRoomPalette.lime,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _JoinRoomPalette.ink,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: _JoinRoomPalette.ink,
              blurRadius: 0,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.login_rounded,
              color: _JoinRoomPalette.ink,
              size: 25,
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _JoinRoomPalette.ink,
                  fontSize: 17,
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

class _JoinRoomPalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF574C42);
  static const Color cream = Color(0xFFFFE8B6);
  static const Color paper = Color(0xFFFFF8E8);
  static const Color lime = Color(0xFF7CFC00);
  static const Color yellow = Color(0xFFFFD65C);
  static const Color skyBlue = Color(0xFF79CDF1);
  static const Color coral = Color(0xFFFF8A79);
}
