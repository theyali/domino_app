import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Общие короткие звуки интерфейса.
///
/// Игровые звуки костяшек и базара остаются привязаны к их анимациям,
/// потому что там важно попасть точно в момент приземления. Этот сервис
/// отвечает за кнопки меню и подтверждение выхода/сдачи.
class SoundEffectsService {
  static const String _buttonSound = 'sounds/button_press.wav';
  static const String _buttonAltSound = 'sounds/button_press_2.wav';
  static const String _quitSound = 'sounds/quit_qame.wav';

  static final AudioPlayer _buttonPlayer = AudioPlayer();
  static final AudioPlayer _actionPlayer = AudioPlayer();

  const SoundEffectsService._();

  static void button({bool alternate = false}) {
    unawaited(
      _buttonPlayer.play(
        AssetSource(alternate ? _buttonAltSound : _buttonSound),
        volume: alternate ? 0.72 : 0.78,
        mode: PlayerMode.lowLatency,
      ),
    );
  }

  static void quitGame() {
    unawaited(
      _actionPlayer.play(
        AssetSource(_quitSound),
        volume: 0.92,
        mode: PlayerMode.lowLatency,
      ),
    );
  }
}
