import '../config/api_config.dart';
import 'game_room.dart';
import 'restaurant.dart';
import 'room_player.dart';
import 'user_gender.dart';

class SocialUser {
  final int id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final UserGender? gender;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final String friendshipStatus;
  final int? friendshipId;
  final DateTime? lastPlayedAt;
  final bool isBlocked;
  final bool blockedByUser;

  const SocialUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    this.gender,
    required this.isOnline,
    required this.lastSeenAt,
    required this.friendshipStatus,
    required this.friendshipId,
    required this.lastPlayedAt,
    this.isBlocked = false,
    this.blockedByUser = false,
  });

  factory SocialUser.fromJson(Map<String, dynamic> json) {
    final username = json['username'] as String? ?? '';
    final displayName = json['display_name'] as String?;
    return SocialUser(
      id: json['id'] as int,
      username: username,
      displayName: displayName?.trim().isNotEmpty == true
          ? displayName!
          : (username.isNotEmpty ? username : 'Игрок'),
      avatarUrl: ApiConfig.resolveUrl(json['avatar_url'] as String?),
      gender: UserGender.fromApi(json['gender']),
      isOnline: json['is_online'] as bool? ?? false,
      lastSeenAt: _parseDate(json['last_seen_at']),
      friendshipStatus: json['friendship_status'] as String? ?? 'none',
      friendshipId: json['friendship_id'] as int?,
      lastPlayedAt: _parseDate(json['last_played_at']),
      isBlocked: json['is_blocked'] as bool? ?? false,
      blockedByUser: json['blocked_by_user'] as bool? ?? false,
    );
  }

  bool get isFriend => friendshipStatus == 'friends';
  bool get requestIncoming => friendshipStatus == 'incoming';
  bool get requestOutgoing => friendshipStatus == 'outgoing';
}

class FriendRequestItem {
  final int id;
  final SocialUser user;
  final DateTime? createdAt;

  const FriendRequestItem({
    required this.id,
    required this.user,
    required this.createdAt,
  });

  factory FriendRequestItem.fromJson(Map<String, dynamic> json) {
    return FriendRequestItem(
      id: json['id'] as int,
      user: SocialUser.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

class ChatPreview {
  final SocialUser user;
  final String lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const ChatPreview({
    required this.user,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory ChatPreview.fromJson(Map<String, dynamic> json) {
    return ChatPreview(
      user: SocialUser.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageAt: _parseDate(json['last_message_at']),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }
}

class RoomInvitationItem {
  final int id;
  final SocialUser sender;
  final int roomId;
  final String roomName;
  final int restaurantId;
  final String restaurantName;
  final DateTime? createdAt;
  final String status;

  const RoomInvitationItem({
    required this.id,
    required this.sender,
    required this.roomId,
    required this.roomName,
    required this.restaurantId,
    required this.restaurantName,
    required this.createdAt,
    required this.status,
  });

  factory RoomInvitationItem.fromJson(Map<String, dynamic> json) {
    return RoomInvitationItem(
      id: json['id'] as int,
      sender: SocialUser.fromJson(
        Map<String, dynamic>.from(json['sender'] as Map),
      ),
      roomId: json['room_id'] as int,
      roomName: json['room_name'] as String? ?? 'Стол',
      restaurantId: json['restaurant_id'] as int,
      restaurantName: json['restaurant_name'] as String? ?? 'Ресторан',
      createdAt: _parseDate(json['created_at']),
      status: json['status'] as String? ?? 'pending',
    );
  }
}

class SocialOverview {
  final List<SocialUser> friends;
  final List<FriendRequestItem> incomingRequests;
  final List<FriendRequestItem> outgoingRequests;
  final List<SocialUser> recentPlayers;
  final List<ChatPreview> conversations;
  final List<RoomInvitationItem> invitations;

  const SocialOverview({
    required this.friends,
    required this.incomingRequests,
    required this.outgoingRequests,
    required this.recentPlayers,
    required this.conversations,
    required this.invitations,
  });

  factory SocialOverview.fromJson(Map<String, dynamic> json) {
    return SocialOverview(
      friends: _parseList(json['friends'], SocialUser.fromJson),
      incomingRequests: _parseList(
        json['incoming_requests'],
        FriendRequestItem.fromJson,
      ),
      outgoingRequests: _parseList(
        json['outgoing_requests'],
        FriendRequestItem.fromJson,
      ),
      recentPlayers: _parseList(json['recent_players'], SocialUser.fromJson),
      conversations: _parseList(json['conversations'], ChatPreview.fromJson),
      invitations: _parseList(json['invitations'], RoomInvitationItem.fromJson),
    );
  }

  int get unreadMessages => conversations.fold<int>(
        0,
        (total, item) => total + item.unreadCount,
      );
}

class NotificationPreferences {
  final bool enabled;
  final bool friendRequests;
  final bool roomInvites;
  final bool directMessages;

  const NotificationPreferences({
    required this.enabled,
    required this.friendRequests,
    required this.roomInvites,
    required this.directMessages,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      enabled: json['push_notifications_enabled'] as bool? ?? true,
      friendRequests: json['notify_friend_requests'] as bool? ?? true,
      roomInvites: json['notify_room_invites'] as bool? ?? true,
      directMessages: json['notify_direct_messages'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'push_notifications_enabled': enabled,
        'notify_friend_requests': friendRequests,
        'notify_room_invites': roomInvites,
        'notify_direct_messages': directMessages,
      };

  NotificationPreferences copyWith({
    bool? enabled,
    bool? friendRequests,
    bool? roomInvites,
    bool? directMessages,
  }) {
    return NotificationPreferences(
      enabled: enabled ?? this.enabled,
      friendRequests: friendRequests ?? this.friendRequests,
      roomInvites: roomInvites ?? this.roomInvites,
      directMessages: directMessages ?? this.directMessages,
    );
  }
}

class DirectMessageItem {
  final int id;
  final int senderId;
  final int recipientId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  const DirectMessageItem({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    required this.readAt,
  });

  factory DirectMessageItem.fromJson(Map<String, dynamic> json) {
    return DirectMessageItem(
      id: json['id'] as int,
      senderId: json['sender_id'] as int,
      recipientId: json['recipient_id'] as int,
      body: json['body'] as String? ?? '',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      readAt: _parseDate(json['read_at']),
    );
  }
}

class DirectMessageThread {
  final SocialUser user;
  final List<DirectMessageItem> messages;

  const DirectMessageThread({required this.user, required this.messages});

  factory DirectMessageThread.fromJson(Map<String, dynamic> json) {
    return DirectMessageThread(
      user: SocialUser.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
      messages: _parseList(json['messages'], DirectMessageItem.fromJson),
    );
  }
}

class BlockedUserItem {
  final SocialUser user;
  final DateTime? blockedAt;

  const BlockedUserItem({required this.user, required this.blockedAt});

  factory BlockedUserItem.fromJson(Map<String, dynamic> json) {
    return BlockedUserItem(
      user: SocialUser.fromJson(
        Map<String, dynamic>.from(json['user'] as Map),
      ),
      blockedAt: _parseDate(json['blocked_at']),
    );
  }
}

class AcceptedRoomInvitation {
  final Restaurant restaurant;
  final GameRoom room;
  final RoomPlayer player;

  const AcceptedRoomInvitation({
    required this.restaurant,
    required this.room,
    required this.player,
  });

  factory AcceptedRoomInvitation.fromJson(Map<String, dynamic> json) {
    return AcceptedRoomInvitation(
      restaurant: Restaurant.fromJson(
        Map<String, dynamic>.from(json['restaurant'] as Map),
      ),
      room: GameRoom.fromJson(
        Map<String, dynamic>.from(json['room'] as Map),
      ),
      player: RoomPlayer.fromJson(
        Map<String, dynamic>.from(json['player'] as Map),
      ),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}

List<T> _parseList<T>(dynamic raw, T Function(Map<String, dynamic>) parser) {
  if (raw is! List) return <T>[];
  return raw
      .whereType<Map>()
      .map((item) => parser(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}
