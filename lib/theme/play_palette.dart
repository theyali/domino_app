import 'package:flutter/material.dart';

/// Палитра нового игрового интерфейса.
///
/// Пока применяется только к главному экрану Play и нижней навигации,
/// чтобы редизайн можно было переносить на остальные экраны постепенно.
abstract final class PlayPalette {
  static const backgroundTop = Color(0xFF0B1733);
  static const backgroundBottom = Color(0xFF101F46);
  static const navy = Color(0xFF0B1834);
  static const navySoft = Color(0xFF172A50);

  static const blue = Color(0xFF268CFF);
  static const blueBright = Color(0xFF43B8FF);
  static const blueSoft = Color(0xFF87D7FF);
  static const cyan = Color(0xFF55E0FF);

  static const ice = Color(0xFFEAF7FF);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF10182A);
  static const muted = Color(0xFFA9BBD8);

  static const yellow = Color(0xFFFFD35A);
  static const coral = Color(0xFFFF6475);
  static const green = Color(0xFF5FE2A0);

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF49C6FF), Color(0xFF267CFF)],
  );

  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [backgroundTop, backgroundBottom],
  );
}
