import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/social.dart';
import 'social_service.dart';

typedef PushTapCallback = void Function(Map<String, dynamic> data);
typedef PushForegroundCallback = void Function(
  String title,
  String body,
  Map<String, dynamic> data,
);

/// Временный сервис уведомлений без Firebase.
///
/// Пока приложение открыто, социальные события проверяются через Django API
/// и показываются тем же callback-механизмом, который уже использует UI.
/// Фоновые push-уведомления при закрытом приложении вернём позже, когда будет
/// настроен Apple Developer / APNs и понадобится полноценный push transport.
class PushNotificationService {
  static const SocialService _socialService = SocialService();
  static const Duration _foregroundPollInterval = Duration(seconds: 4);

  Timer? _foregroundPollTimer;

  bool _initialized = false;
  bool _pollInProgress = false;
  bool _socialSnapshotReady = false;

  PushTapCallback? _onTap;
  PushForegroundCallback? _onForeground;

  final Set<String> _knownFriendRequestKeys = <String>{};
  final Set<int> _knownInvitationIds = <int>{};
  final Map<int, DateTime?> _knownConversationTimes = <int, DateTime?>{};

  NotificationPreferences? _preferences;
  DateTime? _preferencesLoadedAt;

  /// Firebase сейчас намеренно отключён.
  bool get isConfigured => false;

  /// Запускает только foreground API fallback.
  ///
  /// Возвращает false, потому что native push transport сейчас отсутствует.
  Future<bool> initialize({
    PushTapCallback? onTap,
    PushForegroundCallback? onForeground,
  }) async {
    _onTap = onTap;
    _onForeground = onForeground;

    if (_initialized) return false;
    _initialized = true;

    _startForegroundFallbackPolling();
    return false;
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
      // Основной UI не зависит от уведомлений. Следующий poll повторит попытку.
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

  /// Оставлен для совместимости с текущим MainShellScreen.
  /// Без Firebase/APNs регистрировать или удалять device token нечего.
  Future<void> unregisterCurrentDevice() async {}

  void dispose() {
    _foregroundPollTimer?.cancel();
    _foregroundPollTimer = null;
  }
}
