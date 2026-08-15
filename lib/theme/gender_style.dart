import 'package:flutter/material.dart';

import '../models/user_gender.dart';

abstract final class GenderStyle {
  static const Color male = Color(0xFF2F80ED);
  static const Color female = Color(0xFFDE3163);

  static Color colorFor(
    UserGender? gender, {
    Color fallback = const Color(0xFF111111),
  }) {
    return switch (gender) {
      UserGender.male => male,
      UserGender.female => female,
      null => fallback,
    };
  }
}
