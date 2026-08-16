import 'package:flutter/material.dart';

/// Палитра нового игрового интерфейса.
///
/// Базовый набор цветов намеренно небольшой:
/// #121212 — фон, #262628 — поверхности, #106CFF — основной акцент.
abstract final class PlayPalette {
  static const backgroundTop = Color(0xFF121212);
  static const backgroundBottom = Color(0xFF121212);
  static const navy = Color(0xFF262628);
  static const navySoft = Color(0xFF262628);

  static const blue = Color(0xFF106CFF);
  static const blueBright = Color(0xFF106CFF);
  static const blueSoft = Color(0xFF106CFF);
  static const cyan = Color(0xFF106CFF);

  static const ice = Color(0xFFF4F4F4);
  static const white = Color(0xFFFFFFFF);
  static const ink = Color(0xFF121212);
  static const muted = Color(0xFFA7A7AD);

  static const yellow = Color(0xFFFFD35A);
  static const coral = Color(0xFFFF6475);
  static const green = Color(0xFF5FE2A0);

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF262628), Color(0xFF262628)],
  );

  static const pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF121212), Color(0xFF121212)],
  );
}
