import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

class GameActionStrings {
  final bool isAzerbaijani;

  const GameActionStrings._(this.isAzerbaijani);

  factory GameActionStrings.of(BuildContext context) {
    return GameActionStrings._(context.appLanguage.code == 'az');
  }

  String get surrender => isAzerbaijani ? 'Təslim ol' : 'Сдаться';

  String get surrenderTitle =>
      isAzerbaijani ? 'Təslim olmaq?' : 'Сдаться?';

  String get surrenderDescription => isAzerbaijani
      ? 'Təslim olsanız, matç dərhal başa çatacaq və digər oyunçular qalib sayılacaq.'
      : 'Если сдаться, матч сразу завершится, а остальные игроки будут считаться победителями.';

  String get keepPlaying =>
      isAzerbaijani ? 'Oyuna davam et' : 'Продолжить игру';

  String get surrenderFailed => isAzerbaijani
      ? 'Təslim olmaq mümkün olmadı.'
      : 'Не удалось сдаться.';

  String get exitGame => isAzerbaijani ? 'Oyundan çıx' : 'Выйти из игры';

  String get exitTitle =>
      isAzerbaijani ? 'Oyundan çıxmaq?' : 'Выйти из игры?';

  String get exitDescription => isAzerbaijani
      ? 'Masadan çıxacaqsınız. Aktiv matç varsa, digər oyunçular üçün oyun başa çatacaq.'
      : 'Ты покинешь стол. Если матч ещё идёт, для остальных игроков он завершится.';

  String get exitConfirm => isAzerbaijani ? 'Çıx' : 'Выйти';

  String get surrenderResultTitle =>
      isAzerbaijani ? 'Oyunçu təslim oldu' : 'Игрок сдался';

  String surrenderedPlayer(String playerName) => isAzerbaijani
      ? '$playerName təslim oldu. Digər oyunçular matçın qalibidir.'
      : '$playerName сдался. Остальные игроки выиграли матч.';
}
