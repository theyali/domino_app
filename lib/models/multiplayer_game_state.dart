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
  final int score;
  final int dominoCount;

  const MultiplayerPlayerState({
    required this.id,
    required this.name,
    required this.seatIndex,
    required this.isOwner,
    required this.score,
    required this.dominoCount,
  });

  factory MultiplayerPlayerState.fromJson(Map<String, dynamic> json) {
    return MultiplayerPlayerState(
      id: json['id'] as int,
      name: json['name'] as String,
      seatIndex: json['seat_index'] as int,
      isOwner: json['is_owner'] as bool? ?? false,
      score: json['score'] as int? ?? 0,
      dominoCount: json['domino_count'] as int? ?? 0,
    );
  }
}

class MultiplayerGameState {
  final int gameId;
  final int roomId;
  final String status;
  final int roundNumber;
  final int version;
  final int currentPlayerId;
  final int openingPlayerId;
  final int openingDominoId;
  final int boneyardCount;
  final int myPlayerId;
  final List<ServerDomino> myHand;
  final List<ServerDomino> table;
  final List<MultiplayerPlayerState> players;

  const MultiplayerGameState({
    required this.gameId,
    required this.roomId,
    required this.status,
    required this.roundNumber,
    required this.version,
    required this.currentPlayerId,
    required this.openingPlayerId,
    required this.openingDominoId,
    required this.boneyardCount,
    required this.myPlayerId,
    required this.myHand,
    required this.table,
    required this.players,
  });

  factory MultiplayerGameState.fromJson(Map<String, dynamic> json) {
    final rawHand = json['my_hand'] as List<dynamic>? ?? const [];
    final rawTable = json['table'] as List<dynamic>? ?? const [];
    final rawPlayers = json['players'] as List<dynamic>? ?? const [];

    return MultiplayerGameState(
      gameId: json['game_id'] as int,
      roomId: json['room_id'] as int,
      status: json['status'] as String? ?? 'active',
      roundNumber: json['round_number'] as int? ?? 1,
      version: json['version'] as int? ?? 1,
      currentPlayerId: json['current_player_id'] as int,
      openingPlayerId: json['opening_player_id'] as int,
      openingDominoId: json['opening_domino_id'] as int,
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
    );
  }

  bool get isMyTurn => currentPlayerId == myPlayerId;

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
    if (!isMyTurn || status != 'active') {
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
}
