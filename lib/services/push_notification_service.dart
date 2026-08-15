import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../models/social.dart';
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

  static const Duration _foregroundPollInterval = Duration(seconds: 4);
  static const Duration _remoteDedupeWindow = Duration(seconds: 15);

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  Timer? _foregroundPollTimer;

  String? _currentToken;
  bool _initialized = false;
  bool _firebaseReady = false;
  bool _pollInProgress = false;
  bool _socialSnapshotReady = false;

  PushTapCallback? _onTap;
  PushForegroundCallback? _onForeground;

  final Set<String> _knownFriendRequestKeys = <String>{};
  final Set<int> _knownInvitationIds = <int>{};
  final Map<int, DateTime?> _knownConversationTimes = <int, DateTime?>{};
  final Map<String, DateTime> _recentRemoteEvents = <String, DateTime>{};

  NotificationPreferences? _preferences;
  DateTime? _preferencesLoadedAt;

  /// True означает, что Firebase уже реально инициализирован либо для него
  /// переданы dart-defines. Foreground fallback при этом работает независимо.
  bool get isConfigured => _firebaseReady || _firebaseOptions() != null;

  Future<bool> initialize({
    PushTapCallback? onTap,
    PushForegroundCallback? onForeground,
  }) async {
    _onTap = onTap;
    _onForeground = onForeground;

    if (_initialized) return _firebaseReady;
    if (kIsWeb) return false;

    _initialized = true;

    // Foreground fallback нужен даже без Firebase: пока приложение открыто
    // (в том числе поверх MainShell открыт игровой экран), новые сообщения,
    // заявки и приглашения всё равно появляются как уведомления.
    _startForegroundFallbackPolling();

    final options = _firebaseOptions();

    try {
      if (Firebase.apps.isEmpty) {
        if (options != null) {
          await Firebase.initializeApp(options: options);
        } else {
          // Поддерживаем стандартную конфигурацию FlutterFire через
          // GoogleService-Info.plist / google-services.json, если пользователь
          // добавит её в native targets. Это избавляет от обязательных
          // --dart-define для каждого запуска.
          await Firebase.initializeApp();
        }
      }

      final messaging = FirebaseMessaging.instance;
      final permission = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (permission.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('Push permission is denied by the user.');
      }

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

      _firebaseReady = true;
      await _registerCurrentToken();

      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleOpenedMessage(initialMessage);
      }
      return true;
    } catch (error) {
      _firebaseReady = false;
      debugPrint(
        'Firebase push is not configured yet; foreground social notifications '
        'will use API fallback. Details: $error',
      );
      return false;
    }
  }

  void _startForegroundFallbackPolling() {
    _foregroundPollTimer?.cancel();
    unawaited(_pollSocialNotifications());
    _foregroundPollTimer = Timer.periodic(
      _foregroundPollInterval,
      (_) => unawaited(_pollSocialNotifications()),
    );
  }

  Future<void> _pollSocialNotifications() async {
    if (_pollInProgress) return;
    _pollInProgress = true;

    try {
      final overview = await _socialService.fetchOverview();
      final preferences = await _loadPreferencesIfNeeded();

      if (!_socialSnapshotReady) {
        _rememberOverview(overview);
        _socialSnapshotReady = true;
        return;
      }

      final enabled = preferences.enabled;

      for (final request in overview.incomingRequests) {
        final key = 'friend_request:${request.user.id}';
        final isNew = _knownFriendRequestKeys.add(key);
        if (!isNew || !enabled || !preferences.friendRequests) continue;
        if (_wasRecentlyDeliveredRemotely(key)) continue;

        _onForeground?.call(
          'Новая заявка в друзья',
          '${request.user.displayName} хочет добавить тебя в друзья.',
          {
            'type': 'friend_request',
            'user_id': request.user.id,
            'friendship_id': request.id,
          },
        );
      }

      final currentInvitationIds = <int>{};
      for (final invitation in overview.invitations) {
        currentInvitationIds.add(invitation.id);
        final isNew = _knownInvitationIds.add(invitation.id);
        if (!isNew || !enabled || !preferences.roomInvites) continue;

        final key = 'room_invitation:${invitation.id}';
        if (_wasRecentlyDeliveredRemotely(key)) continue;

        _onForeground?.call(
          'Приглашение за стол',
          '${invitation.sender.displayName} зовёт тебя в '
              '${invitation.restaurantName} · ${invitation.roomName}.',
          {
            'type': 'room_invitation',
            'invitation_id': invitation.id,
            'room_id': invitation.roomId,
            'restaurant_id': invitation.restaurantId,
          },
        );
      }
      _knownInvitationIds.removeWhere(
        (id) => !currentInvitationIds.contains(id),
      );

      for (final conversation in overview.conversations) {
        final previous = _knownConversationTimes[conversation.user.id];
        final current = conversation.lastMessageAt;
        final hasNewUnread = conversation.unreadCount > 0 &&
            current != null &&
            (previous == null || current.isAfter(previous));

        _knownConversationTimes[conversation.user.id] = current;

        if (!hasNewUnread || !enabled || !preferences.directMessages) {
          continue;
        }

        final key = 'direct_message:${conversation.user.id}';
        if (_wasRecentlyDeliveredRemotely(key)) continue;

        _onForeground?.call(
          conversation.user.displayName,
          conversation.lastMessage,
          {
            'type': 'direct_message',
            'user_id': conversation.user.id,
          },
        );
      }
    } catch (error) {
      // Игра и основной UI не должны зависеть от уведомлений. Следующий poll
      // автоматически повторит попытку.
      debugPrint('Foreground social notification poll failed: $error');
    } finally {
      _pollInProgress = false;
    }
  }

  Future<NotificationPreferences> _loadPreferencesIfNeeded() async {
    final now = DateTime.now();
    final loadedAt = _preferencesLoadedAt;
    final cached = _preferences;
    if (cached != null &&
        loadedAt != null &&
        now.difference(loadedAt) < const Duration(seconds: 30)) {
      return cached;
    }

    final preferences = await _socialService.fetchNotificationPreferences();
    _preferences = preferences;
    _preferencesLoadedAt = now;
    return preferences;
  }

  void _rememberOverview(SocialOverview overview) {
    _knownFriendRequestKeys
      ..clear()
      ..addAll(
        overview.incomingRequests.map(
          (request) => 'friend_request:${request.user.id}',
        ),
      );

    _knownInvitationIds
      ..clear()
      ..addAll(overview.invitations.map((item) => item.id));

    _knownConversationTimes
      ..clear()
      ..addEntries(
        overview.conversations.map(
          (item) => MapEntry(item.user.id, item.lastMessageAt),
        ),
      );
  }

  bool _wasRecentlyDeliveredRemotely(String key) {
    final now = DateTime.now();
    _recentRemoteEvents.removeWhere(
      (_, deliveredAt) => now.difference(deliveredAt) > _remoteDedupeWindow,
    );
    final deliveredAt = _recentRemoteEvents[key];
    return deliveredAt != null && now.difference(deliveredAt) <= _remoteDedupeWindow;
  }

  void _rememberRemoteEvent(Map<String, dynamic> data) {
    final type = data['type']?.toString();
    if (type == null || type.isEmpty) return;

    String? key;
    if (type == 'room_invitation') {
      final invitationId = data['invitation_id']?.toString();
      if (invitationId != null) key = '$type:$invitationId';
    } else if (type == 'friend_request' || type == 'direct_message') {
      final userId = data['user_id']?.toString();
      if (userId != null) key = '$type:$userId';
    }

    if (key != null) {
      _recentRemoteEvents[key] = DateTime.now();
    }
  }

  Future<void> _registerCurrentToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // На реальном iPhone APNs token может появиться не в тот же кадр,
        // когда пользователь разрешил уведомления. Ждём его несколько секунд,
        // иначе Firebase getToken() иногда вызывается слишком рано.
        for (var attempt = 0; attempt < 10; attempt += 1) {
          final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
          if (apnsToken != null && apnsToken.isNotEmpty) break;
          await Future<void>.delayed(const Duration(milliseconds: 500));
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
    _rememberRemoteEvent(data);
    _onTap?.call(data);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    _rememberRemoteEvent(data);

    // На iOS foreground alert показывает сама система через
    // setForegroundNotificationPresentationOptions. На Android показываем
    // внутриигровое/внутриприложенное уведомление через MainShellScreen.
    if (defaultTargetPlatform == TargetPlatform.iOS) return;

    final notification = message.notification;
    final title = notification?.title ?? 'Domino APP';
    final body = notification?.body ?? '';
    _onForeground?.call(title, body, data);
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
    _foregroundPollTimer?.cancel();
    _foregroundPollTimer = null;
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
