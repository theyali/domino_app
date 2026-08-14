import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

class ProfileStrings {
  final bool isAzerbaijani;

  const ProfileStrings._(this.isAzerbaijani);

  factory ProfileStrings.of(BuildContext context) {
    return ProfileStrings._(context.appLanguage.code == 'az');
  }

  String get editProfile =>
      isAzerbaijani ? 'Profili redaktə et' : 'Редактировать профиль';
  String get displayName => isAzerbaijani ? 'Ad' : 'Имя';
  String get username =>
      isAzerbaijani ? 'İstifadəçi adı' : 'Имя пользователя';
  String get email => 'Email';
  String get changeAvatar => isAzerbaijani ? 'Şəkli dəyiş' : 'Изменить фото';
  String get chooseFromGallery =>
      isAzerbaijani ? 'Qalereyadan seç' : 'Выбрать из галереи';
  String get cropAvatar =>
      isAzerbaijani ? 'Profil şəklini seç' : 'Выбери область аватара';
  String get useAvatar => isAzerbaijani ? 'Hazır' : 'Готово';
  String get cancel => isAzerbaijani ? 'Ləğv et' : 'Отмена';
  String get save => isAzerbaijani ? 'Yadda saxla' : 'Сохранить';
  String get saving =>
      isAzerbaijani ? 'Yadda saxlanılır...' : 'Сохраняем...';
  String get saved =>
      isAzerbaijani ? 'Profil yeniləndi' : 'Профиль обновлён';
  String get saveFailed => isAzerbaijani
      ? 'Profili yeniləmək mümkün olmadı.'
      : 'Не удалось обновить профиль.';
  String get avatarCropFailed => isAzerbaijani
      ? 'Şəkli kəsmək mümkün olmadı.'
      : 'Не удалось подготовить аватар.';
  String get tokenMissing => isAzerbaijani
      ? 'Avtorizasiya sessiyası tapılmadı.'
      : 'Сессия авторизации не найдена.';
  String get fillFields => isAzerbaijani
      ? 'Ad, istifadəçi adı və email sahələrini doldurun.'
      : 'Заполни имя, имя пользователя и email.';
  String get avatarHint => isAzerbaijani
      ? 'Şəkli dairənin içində hərəkət etdirin və yaxınlaşdırın'
      : 'После выбора можно двигать и масштабировать фото внутри круга';
}
