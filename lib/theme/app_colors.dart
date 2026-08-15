import 'package:flutter/material.dart';

abstract final class AppColors {
  static const lime = Color(0xFF7CFC00);
  static const limeDark = Color(0xFF4EA900);
  static const limeSoft = Color(0xFFB7FF72);

  // Тёплая игровая палитра вместо холодных синих панелей.
  // Эти оттенки специально остаются достаточно тёмными, чтобы старые
  // белые подписи продолжали читаться, но визуально экран стал ближе
  // к cartoon / board-game стилю.
  static const background = Color(0xFF2B1B14);
  static const surface = Color(0xFF3A241A);
  static const surfaceRaised = Color(0xFF5A3825);
  static const panelTop = Color(0xFF6E4329);
  static const panelBottom = Color(0xFF3A241A);

  static const cream = Color(0xFFFFE8B6);
  static const ink = Color(0xFF111111);
  static const badge = Color(0xFF3B241A);
  static const badgeLight = Color(0xFF6E4329);

  static const brassLight = Color(0xFFFFE58A);
  static const brass = Color(0xFFF4B63F);
  static const brassDark = Color(0xFF7A451B);

  static const rackWoodLight = Color(0xFFA85F34);
  static const rackWood = Color(0xFF6F3E26);
  static const rackWoodDark = Color(0xFF3B2318);

  // Общие яркие акценты для новых cartoon-элементов игрового экрана.
  static const cartoonYellow = Color(0xFFFFD65C);
  static const cartoonCoral = Color(0xFFFF7A70);
  static const cartoonMint = Color(0xFF8FE3A1);
  static const cartoonSky = Color(0xFF82D7F5);
  static const cartoonPurple = Color(0xFFB99AF4);
}
