import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

class StatisticsStrings {
  final bool isAzerbaijani;

  const StatisticsStrings._(this.isAzerbaijani);

  factory StatisticsStrings.of(BuildContext context) {
    return StatisticsStrings._(context.appLanguage.code == 'az');
  }

  String get title => isAzerbaijani ? 'Statistika' : 'Статистика';
  String get play => isAzerbaijani ? 'Oyna' : 'Играть';
  String get league => isAzerbaijani ? 'Liqa' : 'Лига';
  String get yourLeague => isAzerbaijani ? 'Sizin liqanız' : 'Твоя лига';
  String get leaderboard => isAzerbaijani ? 'Liqa cədvəli' : 'Таблица лиги';
  String get noPlayers => isAzerbaijani
      ? 'Bu liqada hələ oyunçu yoxdur.'
      : 'В этой лиге пока нет игроков.';
  String get points => isAzerbaijani ? 'xal' : 'очков';
  String get wins => isAzerbaijani ? 'Qələbə' : 'Победы';
  String get losses => isAzerbaijani ? 'Məğlubiyyət' : 'Поражения';
  String get games => isAzerbaijani ? 'Oyun' : 'Матчи';
  String get winRate => isAzerbaijani ? 'Qələbə faizi' : 'Винрейт';
  String get maxLeague => isAzerbaijani
      ? 'Ən yüksək liqadasınız'
      : 'Ты уже в высшей лиге';
  String pointsUntilNext(int points, String roman) => isAzerbaijani
      ? 'Liqa $roman üçün $points xal qalıb'
      : 'До лиги $roman осталось $points очков';
  String winReward(int points) => isAzerbaijani
      ? 'Matç qələbəsi +$points xal verir'
      : 'Победа в матче даёт +$points очков';
  String get loadFailed => isAzerbaijani
      ? 'Statistikanı yükləmək mümkün olmadı.'
      : 'Не удалось загрузить статистику.';
}
