import '../config/api_config.dart';
import 'domino.dart';
import 'gift.dart';
import 'player.dart';
import 'user_gender.dart';

class ServerDomino {
  final int id;
  final int left;
  final int right;
  final String gameMode;
  final int? playedByPlayerId;
  final String? side;
  final int? moveNumber;

  const ServerDomino({
    required this.id,
    required this.left,
    required this.right,
    this.gameMode = '101',
    this.playedByPlayerId,
    this.side,
    this.moveNumber,
  });

  factory ServerDomino.fromJson(Map<String, dynamic> json) {
    return ServerDomino(
      id: json['id'] as int,
      left: json['left'] as int,
      right: json['right'] as int,
      gameMode: json['game_mode'] as String? ?? '101',
      playedByPlayerId: json['played_by_player_id'] as int?,
      side: json['side'] as String?,
      moveNumber: json['move_number'] as int?,
    );
  }

  Domino get domino => Domino(left: left, right: right);

  bool get isDouble => left == right;
  bool get isPhone => gameMode == 'phone';

  bool containsValue(int value) => left == value || right == value;
}

class MultiplayerPlayerState {
  final int id;
  final int? userId;
  final String name;
  final String? avatarUrl;
  final UserGender? gender;
  final int seatIndex;
  final bool isOwner;
  final bool isBot;
  final bool isActive;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final int score;
  final int dominoCount;
  final Gift? activeGift;

  const MultiplayerPlayerState({
    required this.id,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    this.gender,
    required this.seatIndex,
    required this.isOwner,
    required this.isBot,
    required this.isActive,
    required this.isOnline,
    required this.lastSeenAt,
    required this.score,
    required this.dominoCount,
    required this.activeGift,
  });

  factory MultiplayerPlayerState.fromJson(Map<String, dynamic> json) {
    final rawActiveGift = json['active_gift'];
    final id = json['id'] as int;
    final avatarUrl = ApiConfig.resolveUrl(json['avatar_url'] as String?);
    final gender = UserGender.fromApi(json['gender']);

    PlayerAvatarCache.remember(id, avatarUrl);
    PlayerGenderCache.remember(id, gender);

    return MultiplayerPlayerState(
      id: id,
      userId: json['user_id'] as int?,
      name: json['name'] as String,
      avatarUrl: avatarUrl,
      gender: gender,
      seatIndex: json['seat_index'] as int,
      isOwner: json['is_owner'] as bool? ?? false,
      isBot: json['is_bot'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
      score: json['score'] as int? ?? 0,
      dominoCount: json['domino_count'] as int? ?? 0,
      activeGift: rawActiveGift is Map
          ? Gift.fromRealtimeJson(
              Map<String, dynamic>.from(rawActiveGift),
            )
          : null,
    );
  }
}

class MultiplayerRoundResult {
  final String reason;
  final List<int> winnerPlayerIds;
  final Map<int, int> handPoints;
  final Map<int, int> addedPenalties;
  final Map<int, int> addedPoints;
  final int roundBonusPips;
  final Map<int, int> totalScores;
  final List<int> matchLoserPlayerIds;
  final List<int> matchWinnerPlayerIds;
  final int? leftPlayerId;

  const MultiplayerRoundResult({
    required this.reason,
    required this.winnerPlayerIds,
    required this.handPoints,
    required this.addedPenalties,
    required this.addedPoints,
    required this.roundBonusPips,
    required this.totalScores,
    required this.matchLoserPlayerIds,
    required this.matchWinnerPlayerIds,
    this.leftPlayerId,
  });

  factory MultiplayerRoundResult.fromJson(Map<String, dynamic> json) {
    return MultiplayerRoundResult(
      reason: json['reason'] as String? ?? 'domino',
      winnerPlayerIds: _intList(json['winner_player_ids']),
      handPoints: _intMap(json['hand_points']),
      addedPenalties: _intMap(json['added_penalties']),
      addedPoints: _intMap(json['added_points']),
      roundBonusPips: json['round_bonus_pips'] as int? ?? 0,
      totalScores: _intMap(json['total_scores']),
      matchLoserPlayerIds: _intList(json['match_loser_player_ids']),
      matchWinnerPlayerIds: _intList(json['match_winner_player_ids']),
      leftPlayerId: json['left_player_id'] as int?,
    );
  }

  static List<int> _intList(dynamic raw) {
    if (raw is! List) return const <int>[];
    return raw
        .whereType<num>()
        .map((value) => value.toInt())
        .toList(growable: false);
  }

  static Map<int, int> _intMap(dynamic raw) {
    if (raw is! Map) return const <int, int>{};

    final result = <int, int>{};
    for (final entry in raw.entries) {
      final key = int.tryParse(entry.key.toString());
      final value = entry.value;
      if (key != null && value is num) {
        result[key] = value.toInt();
      }
    }
    return result;
  }
}

class MultiplayerGameState {
  final int gameId;
  final int roomId;
  final String gameMode;
  final String gameModeLabel;
  final int targetScore;
  final String status;
  final int roundNumber;
  final int version;
  final DateTime? serverTime;
  final int currentPlayerId;
  final int openingPlayerId;
  final int openingDominoId;
  final DateTime? turnStartedAt;
  final DateTime? turnDeadlineAt;
  final int boneyardCount;
  final int myPlayerId;
  final List<ServerDomino> myHand;
  final Map<int, List<ServerDomino>> revealedHands;
  final List<ServerDomino> table;
  final List<MultiplayerPlayerState> players;
  final MultiplayerRoundResult? roundResult;
  final Map<String, int> phoneOpenEnds;
  final int phoneOpenSum;

  const MultiplayerGameState({
    required this.gameId,
    required this.roomId,
    required this.gameMode,
    required this.gameModeLabel,
    required this.targetScore,
    required this.status,
    required this.roundNumber,
    required this.version,
    required this.serverTime,
    required this.currentPlayerId,
    required this.openingPlayerId,
    required this.openingDominoId,
    required this.turnStartedAt,
    required this.turnDeadlineAt,
    required this.boneyardCount,
    required this.myPlayerId,
    required this.myHand,
    required this.revealedHands,
    required this.table,
    required this.players,
    required this.roundResult,
    required this.phoneOpenEnds,
    required this.phoneOpenSum,
  });

  factory MultiplayerGameState.fromJson(Map<String, dynamic> json) {
    final rawHand = json['my_hand'] as List<dynamic>? ?? const [];
    final rawRevealedHands = json['revealed_hands'];
    final rawTable = json['table'] as List<dynamic>? ?? const [];
    final rawPlayers = json['players'] as List<dynamic>? ?? const [];
    final rawRoundResult = json['round_result'];
    final rawPhoneEnds = json['phone_open_ends'];
    final gameMode = json['game_mode'] as String? ?? '101';

    return MultiplayerGameState(
      gameId: json['game_id'] as int,
      roomId: json['room_id'] as int,
      gameMode: gameMode,
      gameModeLabel: json['game_mode_label'] as String? ??
          (gameMode == 'phone' ? 'Телефон' : '101'),
      targetScore: json['target_score'] as int? ?? (gameMode == 'phone' ? 72 : 101),
      status: json['status'] as String? ?? 'active',
      roundNumber: json['round_number'] as int? ?? 1,
      version: json['version'] as int? ?? 1,
      serverTime: DateTime.tryParse(json['server_time'] as String? ?? ''),
      currentPlayerId: json['current_player_id'] as int,
      openingPlayerId: json['opening_player_id'] as int,
      openingDominoId: json['opening_domino_id'] as int,
      turnStartedAt: DateTime.tryParse(json['turn_started_at'] as String? ?? ''),
      turnDeadlineAt: DateTime.tryParse(json['turn_deadline_at'] as String? ?? ''),
      boneyardCount: json['boneyard_count'] as int? ?? 0,
      myPlayerId: json['my_player_id'] as int,
      myHand: rawHand
          .map(
            (item) => ServerDomino.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      revealedHands: _revealedHandsFromJson(rawRevealedHands),
      table: rawTable
          .map(
            (item) => ServerDomino.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      players: rawPlayers
          .map(
            (item) => MultiplayerPlayerState.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      roundResult: rawRoundResult is Map
          ? MultiplayerRoundResult.fromJson(
              Map<String, dynamic>.from(rawRoundResult),
            )
          : null,
      phoneOpenEnds: _stringIntMap(rawPhoneEnds),
      phoneOpenSum: json['phone_open_sum'] as int? ?? 0,
    );
  }

  static Map<int, List<ServerDomino>> _revealedHandsFromJson(dynamic raw) {
    if (raw is! Map) return const <int, List<ServerDomino>>{};

    final result = <int, List<ServerDomino>>{};
    for (final entry in raw.entries) {
      final playerId = int.tryParse(entry.key.toString());
      final rawHand = entry.value;
      if (playerId == null || rawHand is! List) continue;

      result[playerId] = rawHand
          .whereType<Map>()
          .map(
            (item) => ServerDomino.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(growable: false);
    }
    return result;
  }

  static Map<String, int> _stringIntMap(dynamic raw) {
    if (raw is! Map) return const <String, int>{};
    final result = <String, int>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      if (value is num) result[entry.key.toString()] = value.toInt();
    }
    return result;
  }

  bool get isPhone => gameMode == 'phone';
  bool get isClassic101 => gameMode == '101';
  bool get isMyTurn => currentPlayerId == myPlayerId;
  bool get isActive => status == 'active';
  bool get isRoundFinished => status == 'round_finished';
  bool get isMatchFinished => status == 'finished';

  int? get leftEnd => table.isEmpty ? null : table.first.left;
  int? get rightEnd => table.isEmpty ? null : table.last.right;

  MultiplayerPlayerState get myPlayer =>
      players.firstWhere((player) => player.id == myPlayerId);

  MultiplayerPlayerState get currentPlayer =>
      players.firstWhere((player) => player.id == currentPlayerId);

  ServerDomino? get requiredOpeningDomino {
    for (final domino in myHand) {
      if (domino.id == openingDominoId) return domino;
    }
    return null;
  }

  Set<String> playableSidesFor(ServerDomino domino) {
    if (!isMyTurn || !isActive) return const <String>{};

    if (table.isEmpty) {
      if (domino.id == openingDominoId) return const {'center'};
      return const <String>{};
    }

    if (isPhone) {
      final result = <String>{};
      for (final entry in phoneOpenEnds.entries) {
        if (domino.containsValue(entry.value)) result.add(entry.key);
      }
      return result;
    }

    final result = <String>{};
    final leftValue = leftEnd;
    final rightValue = rightEnd;

    if (leftValue != null && domino.containsValue(leftValue)) {
      result.add('left');
    }
    if (rightValue != null && domino.containsValue(rightValue)) {
      result.add('right');
    }
    return result;
  }

  bool get hasPlayableDomino {
    for (final domino in myHand) {
      if (playableSidesFor(domino).isNotEmpty) return true;
    }
    return false;
  }

  bool get canDrawFromBoneyard =>
      isMyTurn && isActive && !hasPlayableDomino && boneyardCount > 0;

  bool get canPass =>
      isMyTurn && isActive && !hasPlayableDomino && boneyardCount == 0;
}
