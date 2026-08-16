import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../theme/play_palette.dart';

class CreateRoomRequest {
  final String roomName;
  final int maxPlayers;
  final String gameMode;
  final int targetScore;
  final int botCount;
  final String password;

  const CreateRoomRequest({
    required this.roomName,
    required this.maxPlayers,
    required this.gameMode,
    required this.targetScore,
    required this.botCount,
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
  final TextEditingController _targetScoreController =
      TextEditingController(text: '72');

  String _gameMode = '101';
  int _maxPlayers = 2;
  int _botCount = 0;
  int _targetScore = 101;
  bool _obscurePassword = true;

  bool get _isAz => context.appLanguage.code == 'az';
  bool get _isPhone => _gameMode == 'phone';

  @override
  void dispose() {
    _roomNameController.dispose();
    _passwordController.dispose();
    _targetScoreController.dispose();
    super.dispose();
  }

  void _selectMode(String mode) {
    setState(() {
      _gameMode = mode;
      if (mode == '101') {
        _maxPlayers = 2;
        if (_botCount > 1) _botCount = 1;
        _targetScore = 101;
      } else if (_targetScore == 101) {
        _targetScore = 72;
        _targetScoreController.text = '72';
      }
    });
  }

  void _selectPlayerCount(int value) {
    setState(() {
      _maxPlayers = value;
      final maxBots = _maxPlayers - 1;
      if (_botCount > maxBots) _botCount = maxBots;
    });
  }

  void _selectTargetScore(int value) {
    setState(() {
      _targetScore = value;
      _targetScoreController.text = '$value';
      _targetScoreController.selection = TextSelection.collapsed(
        offset: _targetScoreController.text.length,
      );
    });
  }

  void _submit() {
    var targetScore = 101;
    if (_isPhone) {
      final parsed = int.tryParse(_targetScoreController.text.trim());
      if (parsed == null || parsed < 5 || parsed > 500) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                _isAz
                    ? 'Qələbə xalı 5-dən 500-ə qədər olmalıdır.'
                    : 'Количество очков для победы должно быть от 5 до 500.',
              ),
            ),
          );
        return;
      }
      targetScore = parsed;
    }

    Navigator.of(context).pop(
      CreateRoomRequest(
        roomName: _roomNameController.text.trim(),
        maxPlayers: _maxPlayers,
        gameMode: _gameMode,
        targetScore: targetScore,
        botCount: _botCount,
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
          color: _CreateRoomPalette.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          border: Border(
            top: BorderSide(color: _CreateRoomPalette.border),
            left: BorderSide(color: _CreateRoomPalette.border),
            right: BorderSide(color: _CreateRoomPalette.border),
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
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _CreateRoomPalette.handle,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SiteIconBox(
                      icon: Icons.table_restaurant_rounded,
                      size: 54,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('create_table'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.55,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Text(
                            context.tr('create_table_account_description'),
                            style: const TextStyle(
                              color: PlayPalette.muted,
                              fontSize: 13.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _SiteTextField(
                  controller: _roomNameController,
                  maxLength: 80,
                  textInputAction: TextInputAction.next,
                  hintText: context.tr('table_name_optional'),
                  icon: Icons.edit_rounded,
                ),
                const SizedBox(height: 24),
                _LabelRow(
                  icon: Icons.rule_rounded,
                  label: _isAz ? 'Oyun qaydası' : 'Правила игры',
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: _RuleButton(
                        title: '101',
                        subtitle: _isAz ? 'Cərimə xalları' : 'Штрафные очки',
                        icon: Icons.looks_one_rounded,
                        selected: _gameMode == '101',
                        onTap: () => _selectMode('101'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RuleButton(
                        title: _isAz ? 'Telefon' : 'Телефон',
                        subtitle: _isAz ? '4 tərəf · ×5' : '4 стороны · ×5',
                        icon: Icons.add_rounded,
                        selected: _gameMode == 'phone',
                        onTap: () => _selectMode('phone'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _InfoPanel(
                  text: _isPhone
                      ? (_isAz
                          ? 'İlk dubl mərkəzdədir. Oyun 4 tərəfə gedir. Açıq ucların cəmi 5-ə bölünəndə aktiv xal qazanırsan.'
                          : 'Первый дубль становится центром креста. Игра идёт в 4 стороны. Если сумма открытых концов кратна 5 — получаешь активные очки.')
                      : (_isAz
                          ? '2 oyunçu. Raundun sonunda əlində qalan bütün nöqtələr cərimədir. 101 xal toplayan uduzur.'
                          : '2 игрока. В конце раунда все точки на оставшихся костяшках идут в штраф. Набравший 101 проигрывает.'),
                ),
                const SizedBox(height: 24),
                _LabelRow(
                  icon: Icons.groups_rounded,
                  label: context.tr('player_count'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final count in (_isPhone ? const [2, 3, 4] : const [2])) ...[
                      if (count != 2) const SizedBox(width: 10),
                      Expanded(
                        child: _ChoiceButton(
                          label: '$count',
                          selected: _maxPlayers == count,
                          onTap: () => _selectPlayerCount(count),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 24),
                _LabelRow(
                  icon: Icons.smart_toy_rounded,
                  label: _isAz ? 'Bot sayı' : 'Количество ботов',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (var count = 0; count < _maxPlayers; count++) ...[
                      if (count > 0) const SizedBox(width: 10),
                      Expanded(
                        child: _ChoiceButton(
                          label: '$count',
                          selected: _botCount == count,
                          onTap: () => setState(() => _botCount = count),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                _InfoPanel(
                  text: _isAz
                      ? '0 — yalnız real oyunçular. Botlar masadakı yerləri dərhal tutur; qalan yerlərə real insanlar qoşula bilər.'
                      : '0 — только реальные игроки. Боты сразу занимают выбранные места, а на оставшиеся могут зайти реальные люди.',
                ),
                if (_isPhone) ...[
                  const SizedBox(height: 24),
                  _LabelRow(
                    icon: Icons.emoji_events_rounded,
                    label: _isAz ? 'Qələbə xalı' : 'Очков для победы',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceButton(
                          label: '72',
                          selected: _targetScore == 72 &&
                              _targetScoreController.text.trim() == '72',
                          onTap: () => _selectTargetScore(72),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChoiceButton(
                          label: '101',
                          selected: _targetScore == 101 &&
                              _targetScoreController.text.trim() == '101',
                          onTap: () => _selectTargetScore(101),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  _SiteTextField(
                    controller: _targetScoreController,
                    maxLength: 3,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    hintText: _isAz
                        ? 'Başqa xal (5–500)'
                        : 'Другое значение (5–500)',
                    icon: Icons.tune_rounded,
                    onChanged: (value) {
                      final parsed = int.tryParse(value.trim());
                      if (parsed != null) {
                        setState(() => _targetScore = parsed);
                      }
                    },
                  ),
                ],
                const SizedBox(height: 24),
                _SiteTextField(
                  controller: _passwordController,
                  maxLength: 64,
                  obscureText: _obscurePassword,
                  onSubmitted: (_) => _submit(),
                  hintText: context.tr('password_optional'),
                  icon: Icons.lock_rounded,
                  suffix: IconButton(
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                    color: Colors.white,
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

class _LabelRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _LabelRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: PlayPalette.navy,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _CreateRoomPalette.border),
          ),
          child: Icon(icon, color: PlayPalette.blue, size: 19),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  final String text;

  const _InfoPanel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: PlayPalette.navy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CreateRoomPalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: PlayPalette.blue,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: PlayPalette.muted,
                height: 1.35,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _RuleButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? PlayPalette.blue : PlayPalette.navy,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? PlayPalette.blue : _CreateRoomPalette.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 21),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? const Color(0xD9FFFFFF)
                    : PlayPalette.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteIconBox extends StatelessWidget {
  final IconData icon;
  final double size;

  const _SiteIconBox({required this.icon, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PlayPalette.blue,
        borderRadius: BorderRadius.circular(17),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 16,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 28),
    );
  }
}

class _SiteTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final int maxLength;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _SiteTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.maxLength,
    this.textInputAction,
    this.keyboardType,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _CreateRoomPalette.border),
    );

    return TextField(
      controller: controller,
      maxLength: maxLength,
      obscureText: obscureText,
      textInputAction: textInputAction,
      keyboardType: keyboardType,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      cursorColor: PlayPalette.blue,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: PlayPalette.muted,
          fontWeight: FontWeight.w600,
        ),
        counterText: '',
        filled: true,
        fillColor: PlayPalette.navy,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
        prefixIconConstraints: const BoxConstraints(minWidth: 58, minHeight: 56),
        prefixIcon: Padding(
          padding: const EdgeInsets.fromLTRB(8, 7, 7, 7),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: PlayPalette.blue,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
        ),
        suffixIcon: suffix,
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: PlayPalette.blue, width: 1.5),
        ),
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
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
        height: 56,
        decoration: BoxDecoration(
          color: selected ? PlayPalette.blue : PlayPalette.navy,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? PlayPalette.blue : _CreateRoomPalette.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected) ...[
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
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

  const _CreateButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: PlayPalette.blue,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x55000000),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.add_circle_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
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
  static const Color background = Color(0xFF121212);
  static const Color border = Color(0xFF353538);
  static const Color handle = Color(0xFF55555A);
}
