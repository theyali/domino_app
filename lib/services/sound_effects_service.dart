import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

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
    _play(
      player: _buttonPlayer,
      assetPath: alternate ? _buttonAltSound : _buttonSound,
      volume: alternate ? 0.72 : 0.78,
    );
  }

  static void quitGame() {
    _play(
      player: _actionPlayer,
      assetPath: _quitSound,
      volume: 0.92,
    );
  }

  static void victory() {
    _play(
      player: _resultPlayer,
      assetPath: _victorySound,
      volume: 0.96,
    );
  }

  static void defeat() {
    _play(
      player: _resultPlayer,
      assetPath: _defeatSound,
      volume: 0.9,
    );
  }

  static void _play({
    required AudioPlayer player,
    required String assetPath,
    required double volume,
  }) {
    unawaited(
      player
          .play(
            AssetSource(assetPath),
            volume: volume,
            mode: PlayerMode.lowLatency,
          )
          .catchError((Object error, StackTrace stackTrace) {
        debugPrint('Sound asset failed to play: $assetPath ($error)');
      }),
    );
  }
}
