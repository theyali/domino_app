import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

class ProfileStrings {
  final bool isAzerbaijani;

  const ProfileStrings._(this.isAzerbaijani);

  factory ProfileStrings.of(BuildContext context) {
    return ProfileStrings._(context.appLanguage.code == 'az');
  }

  String get editProfile => isAzerbaijani ? 'Profili redaktə et' : 'Редактировать профиль';
  String get displayName => isAzerbaijani ? 'Ad' : 'Имя';
  String get username => isAzerbaijani ? 'İstifadəçi adı' : 'Имя пользователя';
  String get email => 'Email';
  String get changeAvatar => isAzerbaijani ? 'Şəkli dəyiş' : 'Изменить фото';
  String get chooseFromGallery => isAzerbaijani ? 'Qalereyadan seç' : 'Выбрать из галереи';
  String get save => isAzerbaijani ? 'Yadda saxla' : 'Сохранить';
  String get saving => isAzerbaijani ? 'Yadda saxlanılır...' : 'Сохраняем...';
  String get saved => isAzerbaijani ? 'Profil yeniləndi' : 'Профиль обновлён';
  String get saveFailed => isAzerbaijani ? 'Profili yeniləmək mümkün olmadı.' : 'Не удалось обновить профиль.';
  String get tokenMissing => isAzerbaijani ? 'Avtorizasiya sessiyası tapılmadı.' : 'Сессия авторизации не найдена.';
  String get fillFields => isAzerbaijani ? 'Ad, istifadəçi adı və email sahələrini doldurun.' : 'Заполни имя, имя пользователя и email.';
  String get avatarHint => isAzerbaijani ? 'JPG və ya PNG, maksimum 5 MB' : 'JPG или PNG, максимум 5 МБ';
}
