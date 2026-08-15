import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'social_service.dart';

typedef PushTapCallback = void Function(Map<String, dynamic> data);
typedef PushForegroundCallback = void Function(
  String title,
  String body,
  Map<String, dynamic> data,
);

class PushNotificationService {
  static const SocialService _socialService = SocialService();

  static const String _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const String _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const String _senderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const String _androidAppId =
      String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const String _iosAppId =
      String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const String _iosBundleId = String.fromEnvironment(
    'FIREBASE_IOS_BUNDLE_ID',
    defaultValue: 'az.ali.dominoAPP',
  );
  static const String _storageBucket =
      String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  String? _currentToken;
  bool _initialized = false;
  PushTapCallback? _onTap;
  PushForegroundCallback? _onForeground;

  bool get isConfigured => _firebaseOptions() != null;

  Future<bool> initialize({
    PushTapCallback? onTap,
    PushForegroundCallback? onForeground,
  }) async {
    _onTap = onTap;
    _onForeground = onForeground;

    if (_initialized) return true;
    if (kIsWeb) return false;

    final options = _firebaseOptions();
    if (options == null) {
      debugPrint(
        'Push notifications are disabled: Firebase dart-defines are missing.',
      );
      return false;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _tokenSubscription = messaging.onTokenRefresh.listen(
        (token) => unawaited(_registerToken(token)),
      );
      _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpenedMessage,
      );
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _handleForegroundMessage,
      );

      _initialized = true;
      await _registerCurrentToken();

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }
      return true;
    } catch (error) {
      debugPrint('Push initialization failed: $error');
      return false;
    }
  }

  Future<void> _registerCurrentToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // APNs token иногда появляется чуть позже после первого запуска.
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null) {
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _registerToken(token);
      }
    } catch (error) {
      debugPrint('Push token registration will retry on token refresh: $error');
    }
  }

  Future<void> _registerToken(String token) async {
    _currentToken = token;
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    try {
      await _socialService.registerPushDevice(
        registrationToken: token,
        platform: platform,
      );
    } catch (error) {
      debugPrint('Could not register push token on backend: $error');
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    _onTap?.call(data);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // На iOS foreground alert уже показывает сама система через
    // setForegroundNotificationPresentationOptions. На Android показываем
    // компактное внутриигровое уведомление через MainShellScreen.
    if (defaultTargetPlatform == TargetPlatform.iOS) return;

    final notification = message.notification;
    final title = notification?.title ?? 'Domino APP';
    final body = notification?.body ?? '';
    _onForeground?.call(
      title,
      body,
      Map<String, dynamic>.from(message.data),
    );
  }

  Future<void> unregisterCurrentDevice() async {
    final token = _currentToken;
    if (token == null || token.isEmpty) return;
    try {
      await _socialService.unregisterPushDevice(token);
    } catch (_) {
      // Logout не должен блокироваться из-за недоступного push endpoint.
    }
  }

  void dispose() {
    _tokenSubscription?.cancel();
    _openedSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _tokenSubscription = null;
    _openedSubscription = null;
    _foregroundSubscription = null;
  }

  FirebaseOptions? _firebaseOptions() {
    if (_apiKey.isEmpty || _projectId.isEmpty || _senderId.isEmpty) {
      return null;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (_iosAppId.isEmpty) return null;
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: _iosAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        iosBundleId: _iosBundleId,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      );
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      if (_androidAppId.isEmpty) return null;
      return FirebaseOptions(
        apiKey: _apiKey,
        appId: _androidAppId,
        messagingSenderId: _senderId,
        projectId: _projectId,
        storageBucket: _storageBucket.isEmpty ? null : _storageBucket,
      );
    }

    return null;
  }
}
