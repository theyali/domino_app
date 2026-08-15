# Push-уведомления Domino APP

Код приложения уже умеет регистрировать FCM token на Django backend и открывать раздел «Друзья» по нажатию на уведомление.

Секреты Firebase в Git не коммитятся. Для локального запуска передай публичные параметры Firebase через `--dart-define`:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://192.168.100.223:8000 \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_ANDROID_APP_ID=... \
  --dart-define=FIREBASE_IOS_APP_ID=... \
  --dart-define=FIREBASE_IOS_BUNDLE_ID=az.ali.dominoAPP
```

`FIREBASE_ANDROID_APP_ID` и `FIREBASE_IOS_APP_ID` — это разные App ID двух приложений внутри одного Firebase project.

## iOS

В Firebase создай iOS app с bundle id `az.ali.dominoAPP`.

В Xcode для target `Runner` один раз включи:

- **Push Notifications**;
- **Background Modes → Remote notifications**.

Также в Firebase Console в Cloud Messaging подключи APNs Authentication Key из Apple Developer account.

## Android

Создай Android app в том же Firebase project. Разрешение `POST_NOTIFICATIONS` уже добавлено в `AndroidManifest.xml`, а Flutter сам запросит его на поддерживаемых версиях Android.

## Backend

Django отправляет push через Firebase Admin SDK. На сервере укажи service-account credential вне репозитория:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/secure/path/firebase-service-account.json
export FIREBASE_PROJECT_ID=your-firebase-project-id
```

После этого перезапусти Django.

Push отправляются для:

- новой заявки в друзья;
- принятой заявки в друзья;
- приглашения за игровой стол;
- личного сообщения.

Каждый тип можно выключить в приложении: **Друзья → Поиск и настройки → Уведомления**.
