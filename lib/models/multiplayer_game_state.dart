import 'domino.dart';

class ServerDomino {
  final int id;
  final int left;
  final int right;
  final int? playedByPlayerId;
  final String? side;
  final int? moveNumber;

  const ServerDomino({
    required this.id,
    required this.left,
    required this.right,
    this.playedByPlayerId,
    this.side,
    this.moveNumber,
  });

  factory ServerDomino.fromJson(Map<String, dynamic> json) {
    return ServerDomino(
      id: json['id'] as int,
      left: json['left'] as int,
      right: json['right'] as int,
      playedByPlayerId: json['played_by_player_id'] as int?,
      side: json['side'] as String?,
      moveNumber: json['move_number'] as int?,
    );
  }

  Domino get domino => Domino(left: left, right: right);

  bool get isDouble => left == right;

  bool containsValue(int value) => left == value || right == value;
}

class MultiplayerPlayerState {
  final int id;
  final String name;
  final int seatIndex;
  final bool isOwner;
  final bool isActive;
  final bool isOnline;
  final DateTime? lastSeenAt;
  final int score;
  final int dominoCount;

  const MultiplayerPlayerState({
    required this.id,
    required this.name,
    required this.seatIndex,
    required this.isOwner,
    required this.isActive,
    required this.isOnline,
    required this.lastSeenAt,
    required this.score,
    required this.dominoCount,
  });

  factory MultiplayerPlayerState.fromJson(Map<String, dynamic> json) {
    return MultiplayerPlayerState(
      id: json['id'] as int,
      name: json['name'] as String,
      seatIndex: json['seat_index'] as int,
      isOwner: json['is_owner'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      isOnline: json['is_online'] as bool? ?? false,
      lastSeenAt: DateTime.tryParse(json['last_seen_at'] as String? ?? ''),
      score: json['score'] as int? ?? 0,
      dominoCount: json['domino_count'] as int? ?? 0,
    );
  }
}

class MultiplayerRoundResult {
  final String reason;
  final List<int> winnerPlayerIds;
  final Map<int, int> handPoints;
  final Map<int, int> addedPenalties;
  final Map<int, int> totalScores;
  final List<int> matchLoserPlayerIds;
  final List<int> matchWinnerPlayerIds;
  final int? leftPlayerId;

  const MultiplayerRoundResult({
    required this.reason,
    required this.winnerPlayerIds,
    required this.handPoints,
    required this.addedPenalties,
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
  final List<ServerDomino> table;
  final List<MultiplayerPlayerState> players;
  final MultiplayerRoundResult? roundResult;

  const MultiplayerGameState({
    required this.gameId,
    required this.roomId,
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
    required this.table,
    required this.players,
    required this.roundResult,
  });

  factory MultiplayerGameState.fromJson(Map<String, dynamic> json) {
    final rawHand = json['my_hand'] as List<dynamic>? ?? const [];
    final rawTable = json['table'] as List<dynamic>? ?? const [];
    final rawPlayers = json['players'] as List<dynamic>? ?? const [];
    final rawRoundResult = json['round_result'];

    return MultiplayerGameState(
      gameId: json['game_id'] as int,
      roomId: json['room_id'] as int,
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
    );
  }

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
      if (domino.id == openingDominoId) {
        return domino;
      }
    }
    return null;
  }

  Set<String> playableSidesFor(ServerDomino domino) {
    if (!isMyTurn || !isActive) {
      return const <String>{};
    }

    if (table.isEmpty) {
      if (domino.id == openingDominoId) {
        return const {'center'};
      }
      return const <String>{};
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
      if (playableSidesFor(domino).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool get canDrawFromBoneyard =>
      isMyTurn && isActive && !hasPlayableDomino && boneyardCount > 0;

  bool get canPass =>
      isMyTurn && isActive && !hasPlayableDomino && boneyardCount == 0;
}
