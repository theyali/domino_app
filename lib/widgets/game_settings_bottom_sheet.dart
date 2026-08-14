import 'package:flutter/material.dart';

class GameSettingsBottomSheet extends StatefulWidget {
  final bool soundEnabled;
  final ValueChanged<bool> onSoundChanged;

  const GameSettingsBottomSheet({
    super.key,
    required this.soundEnabled,
    required this.onSoundChanged,
  });

  @override
  State<GameSettingsBottomSheet> createState() =>
      _GameSettingsBottomSheetState();
}

class _GameSettingsBottomSheetState extends State<GameSettingsBottomSheet> {
  late bool _soundEnabled;

  @override
  void initState() {
    super.initState();
    _soundEnabled = widget.soundEnabled;
  }

  void _changeSound(bool value) {
    setState(() {
      _soundEnabled = value;
    });

    widget.onSoundChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF111827),
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(99),
              ),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Настройки игры',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white10,
                ),
              ),
              child: SwitchListTile.adaptive(
                value: _soundEnabled,
                onChanged: _changeSound,
                secondary: Icon(
                  _soundEnabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: Colors.white,
                ),
                title: const Text(
                  'Звук игры',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  _soundEnabled
                      ? 'Звуки ударов костяшек включены'
                      : 'Игра работает без звука',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Вибрация удара пока остаётся включённой даже в беззвучном режиме.',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
