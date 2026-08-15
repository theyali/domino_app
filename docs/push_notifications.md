# Push-уведомления Domino APP

В приложении есть два уровня уведомлений:

1. **Foreground fallback** — работает сразу через Django API, пока приложение открыто. Он показывает новые личные сообщения, заявки в друзья и приглашения за стол даже если пользователь сейчас находится прямо внутри игры. Firebase для этого не нужен.
2. **Настоящие системные push в background/когда приложение закрыто** — идут через Firebase Cloud Messaging + APNs на iOS. Для них один раз нужно подключить Firebase-проект и серверный service account.

## Flutter / Firebase client

`PushNotificationService` сначала пробует стандартную native-конфигурацию FlutterFire:

- `ios/Runner/GoogleService-Info.plist`
- `android/app/google-services.json`

Если native-файлов нет, поддерживаются публичные параметры через `--dart-define`:

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

`FIREBASE_ANDROID_APP_ID` и `FIREBASE_IOS_APP_ID` — разные App ID двух приложений внутри одного Firebase project.

Если Firebase пока не настроен, приложение не ломается: foreground-уведомления продолжают приходить через API fallback.

## iOS

Bundle ID приложения: `az.ali.dominoAPP`.

В репозитории уже есть:

- `UIBackgroundModes → remote-notification`;
- `ios/Runner/Runner.entitlements` с `aps-environment`;
- подключение entitlements для Debug и Release.

В Firebase Console остаётся один внешний шаг: добавить APNs Authentication Key для iOS-приложения.

## Android

Разрешение `POST_NOTIFICATIONS` уже добавлено в AndroidManifest. После подключения Android app к Firebase FCM token регистрируется на Django автоматически.

## Backend

Django отправляет push через Firebase Admin SDK. Service account нельзя хранить в Git.

Поддерживаются три варианта конфигурации:

```bash
# стандартный Google/Firebase вариант
export GOOGLE_APPLICATION_CREDENTIALS=/secure/path/firebase-service-account.json
export FIREBASE_PROJECT_ID=your-firebase-project-id
```

или:

```bash
export FIREBASE_SERVICE_ACCOUNT_FILE=/secure/path/firebase-service-account.json
export FIREBASE_PROJECT_ID=your-firebase-project-id
```

или JSON напрямую через секрет окружения:

```bash
export FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account", ...}'
export FIREBASE_PROJECT_ID=your-firebase-project-id
```

После изменения env перезапусти Django.

Push отправляются для:

- новой заявки в друзья;
- принятой заявки в друзья;
- приглашения за игровой стол;
- личного сообщения.

Каждый тип можно выключить в приложении: **Друзья → Поиск и настройки → Уведомления**.
