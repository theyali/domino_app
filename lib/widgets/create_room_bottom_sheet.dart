import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';

class CreateRoomRequest {
  final String roomName;
  final int maxPlayers;
  final String password;

  const CreateRoomRequest({
    required this.roomName,
    required this.maxPlayers,
    required this.password,
  });
}

class CreateRoomBottomSheet extends StatefulWidget {
  const CreateRoomBottomSheet({super.key});

  @override
  State<CreateRoomBottomSheet> createState() =>
      _CreateRoomBottomSheetState();
}

class _CreateRoomBottomSheetState extends State<CreateRoomBottomSheet> {
  final TextEditingController _roomNameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  int _maxPlayers = 2;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      CreateRoomRequest(
        roomName: _roomNameController.text.trim(),
        maxPlayers: _maxPlayers,
        password: _passwordController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: _CreateRoomPalette.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
          border: Border(
            top: BorderSide(color: _CreateRoomPalette.ink, width: 3),
            left: BorderSide(color: _CreateRoomPalette.ink, width: 3),
            right: BorderSide(color: _CreateRoomPalette.ink, width: 3),
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
                      color: _CreateRoomPalette.ink,
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
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: _CreateRoomPalette.yellow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _CreateRoomPalette.ink,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: _CreateRoomPalette.ink,
                              blurRadius: 0,
                              offset: Offset(3, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.table_restaurant_rounded,
                          color: _CreateRoomPalette.ink,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('create_table'),
                            style: const TextStyle(
                              color: _CreateRoomPalette.ink,
                              fontSize: 28,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            context.tr('create_table_account_description'),
                            style: const TextStyle(
                              color: _CreateRoomPalette.inkSoft,
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
                const SizedBox(height: 24),
                _CartoonTextField(
                  controller: _roomNameController,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  hintText: context.tr('table_name_optional'),
                  icon: Icons.edit_rounded,
                  accentColor: _CreateRoomPalette.skyBlue,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _CreateRoomPalette.coral,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _CreateRoomPalette.ink,
                          width: 2.4,
                        ),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: _CreateRoomPalette.ink,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      context.tr('player_count'),
                      style: const TextStyle(
                        color: _CreateRoomPalette.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final count in const [2, 3, 4]) ...[
                      if (count != 2) const SizedBox(width: 10),
                      Expanded(
                        child: _PlayerCountButton(
                          count: count,
                          selected: _maxPlayers == count,
                          onTap: () {
                            setState(() {
                              _maxPlayers = count;
                            });
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 22),
                _CartoonTextField(
                  controller: _passwordController,
                  maxLength: 64,
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _submit(),
                  hintText: context.tr('password_optional'),
                  icon: Icons.lock_rounded,
                  accentColor: _CreateRoomPalette.mint,
                  suffix: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    color: _CreateRoomPalette.ink,
                    splashRadius: 22,
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                _CreateButton(
                  label: context.tr('create_room'),
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

class _CartoonTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final Color accentColor;
  final int maxLength;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _CartoonTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.accentColor,
    required this.maxLength,
    this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(19),
      borderSide: const BorderSide(
        color: _CreateRoomPalette.ink,
        width: 2.8,
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(19),
        boxShadow: const [
          BoxShadow(
            color: _CreateRoomPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        obscureText: obscureText,
        textInputAction: textInputAction,
        onSubmitted: onSubmitted,
        cursorColor: _CreateRoomPalette.ink,
        style: const TextStyle(
          color: _CreateRoomPalette.ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            color: _CreateRoomPalette.inkSoft,
            fontWeight: FontWeight.w700,
          ),
          counterText: '',
          filled: true,
          fillColor: _CreateRoomPalette.paper,
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
                color: accentColor,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: _CreateRoomPalette.ink,
                  width: 2.2,
                ),
              ),
              child: Icon(
                icon,
                color: _CreateRoomPalette.ink,
                size: 22,
              ),
            ),
          ),
          suffixIcon: suffix,
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: const BorderSide(
              color: _CreateRoomPalette.ink,
              width: 3.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerCountButton extends StatelessWidget {
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _PlayerCountButton({
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        height: 58,
        transform: Matrix4.translationValues(0, selected ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: selected
              ? _CreateRoomPalette.lime
              : _CreateRoomPalette.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _CreateRoomPalette.ink,
            width: selected ? 3.2 : 2.6,
          ),
          boxShadow: [
            BoxShadow(
              color: _CreateRoomPalette.ink,
              blurRadius: 0,
              offset: Offset(0, selected ? 6 : 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_circle_rounded,
                color: _CreateRoomPalette.ink,
                size: 20,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              '$count',
              style: const TextStyle(
                color: _CreateRoomPalette.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CreateButton({
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
          color: _CreateRoomPalette.lime,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _CreateRoomPalette.ink,
            width: 3,
          ),
          boxShadow: const [
            BoxShadow(
              color: _CreateRoomPalette.ink,
              blurRadius: 0,
              offset: Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_rounded,
              color: _CreateRoomPalette.ink,
              size: 25,
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _CreateRoomPalette.ink,
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

class _CreateRoomPalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF574C42);
  static const Color cream = Color(0xFFFFE8B6);
  static const Color paper = Color(0xFFFFF8E8);
  static const Color lime = Color(0xFF7CFC00);
  static const Color yellow = Color(0xFFFFD65C);
  static const Color skyBlue = Color(0xFF79CDF1);
  static const Color coral = Color(0xFFFF8A79);
  static const Color mint = Color(0xFF8CDD79);
}
