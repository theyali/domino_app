enum UserGender {
  male('male'),
  female('female');

  final String apiValue;

  const UserGender(this.apiValue);

  static UserGender? fromApi(dynamic value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final gender in UserGender.values) {
      if (gender.apiValue == normalized) return gender;
    }
    return null;
  }

  String label({required bool isAzerbaijani}) {
    return switch (this) {
      UserGender.male => isAzerbaijani ? 'Kişi' : 'Мужской',
      UserGender.female => isAzerbaijani ? 'Qadın' : 'Женский',
    };
  }
}
