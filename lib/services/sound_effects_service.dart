import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Общие короткие звуки интерфейса.
///
/// Игровые звуки костяшек и базара остаются привязаны к их анимациям,
/// потому что там важно попасть точно в момент приземления. Этот сервис
/// отвечает за кнопки меню, подтверждение выхода/сдачи и результат матча.
class SoundEffectsService {
  static const String _buttonSound = 'sounds/button_press.wav';
  static const String _buttonAltSound = 'sounds/button_press_2.wav';
  static const String _quitSound = 'sounds/quit_qame.wav';

  /// Пока это временные файлы. Их можно просто заменить своими WAV-файлами
  /// с теми же именами без изменений Dart-кода.
  static const String _victorySound = 'sounds/victory.wav';
  static const String _defeatSound = 'sounds/defeat.wav';

  static final AudioPlayer _buttonPlayer = AudioPlayer();
  static final AudioPlayer _actionPlayer = AudioPlayer();
  static final AudioPlayer _resultPlayer = AudioPlayer();

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

  static void victory() {
    unawaited(
      _resultPlayer.play(
        AssetSource(_victorySound),
        volume: 0.96,
        mode: PlayerMode.lowLatency,
      ),
    );
  }

  static void defeat() {
    unawaited(
      _resultPlayer.play(
        AssetSource(_defeatSound),
        volume: 0.9,
        mode: PlayerMode.lowLatency,
      ),
    );
  }
}
