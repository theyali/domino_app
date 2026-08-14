import 'dart:math';

import '../models/domino.dart';
import '../models/player.dart';

enum DominoSide {
  left,
  right,
}

enum DominoRoundEndReason {
  domino,
  fish,
}

class Domino101Rules {
  final int handSize;
  final int losingScore;
  final int minimumPenaltyToRecord;
  final int doubleBlankPenaltyWhenAlone;

  const Domino101Rules({
    this.handSize = 7,
    this.losingScore = 101,
    this.minimumPenaltyToRecord = 13,
    this.doubleBlankPenaltyWhenAlone = 25,
  });
}

class DominoMoveResult {
  final int playerIndex;
  final int handIndex;
  final Domino playedDomino;
  final DominoSide side;
  final int tableIndex;
  final bool roundEnded;

  const DominoMoveResult({
    required this.playerIndex,
    required this.handIndex,
    required this.playedDomino,
    required this.side,
    required this.tableIndex,
    required this.roundEnded,
  });
}

class DominoPassResult {
  final int playerIndex;
  final bool roundEnded;

  const DominoPassResult({
    required this.playerIndex,
    required this.roundEnded,
  });
}

class DominoDrawResult {
  final int playerIndex;
  final int handIndex;
  final Domino domino;
  final int boneyardRemaining;
  final bool hasLegalMove;

  const DominoDrawResult({
    required this.playerIndex,
    required this.handIndex,
    required this.domino,
    required this.boneyardRemaining,
    required this.hasLegalMove,
  });
}

class DominoRoundResult {
  final DominoRoundEndReason reason;
  final List<int> winnerIndices;
  final List<int> handPoints;
  final List<int> addedPenalties;
  final List<int> totalScores;
  final List<int> matchLoserIndices;

  const DominoRoundResult({
    required this.reason,
    required this.winnerIndices,
    required this.handPoints,
    required this.addedPenalties,
    required this.totalScores,
    required this.matchLoserIndices,
  });
}

class DominoGame {
  final List<Player> _basePlayers;
  final Domino101Rules rules;
  final Random _random;
  final List<int> _turnOrder;

  late List<List<Domino>> _hands;
  late List<Domino> _boneyard;

  final List<Domino> _tableDominoes = [];
  late List<int> _scores;

  int currentPlayerIndex = 0;
  int roundNumber = 0;

  int _consecutivePasses = 0;
  int? _openingPlayerIndex;
  int? _openingHandIndex;

  int _openingTableIndex = -1;

  bool isRoundOver = false;
  bool isMatchOver = false;

  DominoRoundResult? lastRoundResult;

  DominoGame({
    required List<Player> players,
    this.rules = const Domino101Rules(),
    Random? random,
    List<int>? turnOrder,
  })  : assert(players.length == 4),
        _basePlayers = List.unmodifiable(players),
        _random = random ?? Random(),
        _turnOrder = List<int>.unmodifiable(
          turnOrder ??
              List<int>.generate(
                players.length,
                (index) => index,
              ),
        ) {
    assert(
      _turnOrder.length == _basePlayers.length,
      'turnOrder должен содержать всех игроков',
    );

    assert(
      _turnOrder.toSet().length == _basePlayers.length,
      'turnOrder не должен содержать повторяющиеся индексы',
    );

    assert(
      _turnOrder.every(
        (index) =>
            index >= 0 &&
            index < _basePlayers.length,
      ),
      'turnOrder содержит некорректный индекс игрока',
    );

    _scores = List<int>.filled(
      _basePlayers.length,
      0,
    );

    startNextRound();
  }

  List<Player> get players {
    return List<Player>.generate(
      _basePlayers.length,
      (index) {
        final player = _basePlayers[index];

        return Player(
          id: player.id,
          name: player.name,
          avatarUrl: player.avatarUrl,
          score: _scores[index],
          isMe: player.isMe,
        );
      },
      growable: false,
    );
  }

  List<int> get scores =>
      List<int>.unmodifiable(_scores);

  List<Domino> get tableDominoes =>
      List<Domino>.unmodifiable(
        _tableDominoes,
      );

  int get boneyardCount =>
      _boneyard.length;

  bool get hasBoneyard =>
      _boneyard.isNotEmpty;

  int? get openingTableIndex {
    if (
      _tableDominoes.isEmpty ||
      _openingTableIndex < 0
    ) {
      return null;
    }

    return _openingTableIndex;
  }

  int? get leftOpenValue {
    if (_tableDominoes.isEmpty) {
      return null;
    }

    return _tableDominoes.first.left;
  }

  int? get rightOpenValue {
    if (_tableDominoes.isEmpty) {
      return null;
    }

    return _tableDominoes.last.right;
  }

  int get playerCount =>
      _basePlayers.length;

  int get openingPlayerIndex =>
      _openingPlayerIndex ??
      currentPlayerIndex;

  Domino? get requiredOpeningDomino {
    final playerIndex =
        _openingPlayerIndex;

    final handIndex =
        _openingHandIndex;

    if (
      playerIndex == null ||
      handIndex == null ||
      _tableDominoes.isNotEmpty
    ) {
      return null;
    }

    return _hands[playerIndex][handIndex];
  }

  List<Domino> handFor(
    int playerIndex,
  ) {
    return List<Domino>.unmodifiable(
      _hands[playerIndex],
    );
  }

  int handCountFor(
    int playerIndex,
  ) {
    return _hands[playerIndex].length;
  }

  void resetMatch() {
    _scores = List<int>.filled(
      _basePlayers.length,
      0,
    );

    isMatchOver = false;
    lastRoundResult = null;
    roundNumber = 0;

    startNextRound();
  }

  void startNextRound() {
    if (isMatchOver) {
      return;
    }

    roundNumber++;

    isRoundOver = false;
    lastRoundResult = null;

    _tableDominoes.clear();
    _consecutivePasses = 0;
    _openingTableIndex = -1;

    final deck =
        _createFullSet()
          ..shuffle(_random);

    _hands = List<List<Domino>>.generate(
      playerCount,
      (_) => <Domino>[],
    );

    for (
      var round = 0;
      round < rules.handSize;
      round++
    ) {
      for (
        var playerIndex = 0;
        playerIndex < playerCount;
        playerIndex++
      ) {
        if (deck.isEmpty) {
          break;
        }

        _hands[playerIndex].add(
          deck.removeLast(),
        );
      }
    }

    _boneyard = List<Domino>.from(
      deck,
    );

    _chooseOpeningPlayer();
  }

  bool canDrawFromBoneyard(
    int playerIndex,
  ) {
    if (
      isRoundOver ||
      playerIndex != currentPlayerIndex ||
      _boneyard.isEmpty
    ) {
      return false;
    }

    return !hasLegalMove(
      playerIndex,
    );
  }

  DominoDrawResult? drawFromBoneyard(
    int playerIndex,
  ) {
    if (
      !canDrawFromBoneyard(
        playerIndex,
      )
    ) {
      return null;
    }

    final domino =
        _boneyard.removeLast();

    final hand =
        _hands[playerIndex];

    hand.add(domino);

    final handIndex =
        hand.length - 1;

    _consecutivePasses = 0;

    return DominoDrawResult(
      playerIndex: playerIndex,
      handIndex: handIndex,
      domino: domino,
      boneyardRemaining:
          _boneyard.length,
      hasLegalMove:
          hasLegalMove(
        playerIndex,
      ),
    );
  }

  List<DominoDrawResult>
      drawUntilPlayable(
    int playerIndex,
  ) {
    final results =
        <DominoDrawResult>[];

    while (
      canDrawFromBoneyard(
        playerIndex,
      )
    ) {
      final result =
          drawFromBoneyard(
        playerIndex,
      );

      if (result == null) {
        break;
      }

      results.add(result);

      if (result.hasLegalMove) {
        break;
      }
    }

    return List<DominoDrawResult>.unmodifiable(
      results,
    );
  }

  bool canCurrentPlayerPass() {
    return !hasLegalMove(
          currentPlayerIndex,
        ) &&
        _boneyard.isEmpty;
  }

  bool hasLegalMove(
    int playerIndex,
  ) {
    return legalHandIndicesForPlayer(
      playerIndex,
    ).isNotEmpty;
  }

  List<int> legalHandIndicesForPlayer(
    int playerIndex,
  ) {
    if (
      isRoundOver ||
      playerIndex != currentPlayerIndex
    ) {
      return const [];
    }

    final hand =
        _hands[playerIndex];

    final result = <int>[];

    for (
      var index = 0;
      index < hand.length;
      index++
    ) {
      if (
        canPlayHandIndex(
          playerIndex: playerIndex,
          handIndex: index,
        )
      ) {
        result.add(index);
      }
    }

    return result;
  }

  bool canPlayHandIndex({
    required int playerIndex,
    required int handIndex,
  }) {
    if (
      isRoundOver ||
      playerIndex != currentPlayerIndex
    ) {
      return false;
    }

    final hand =
        _hands[playerIndex];

    if (
      handIndex < 0 ||
      handIndex >= hand.length
    ) {
      return false;
    }

    if (_tableDominoes.isEmpty) {
      return playerIndex ==
              _openingPlayerIndex &&
          handIndex ==
              _openingHandIndex;
    }

    final domino =
        hand[handIndex];

    return canDominoPlayOnSide(
          playerIndex: playerIndex,
          domino: domino,
          side: DominoSide.left,
        ) ||
        canDominoPlayOnSide(
          playerIndex: playerIndex,
          domino: domino,
          side: DominoSide.right,
        );
  }

  bool canDominoPlayOnSide({
    required int playerIndex,
    required Domino domino,
    required DominoSide side,
  }) {
    if (
      isRoundOver ||
      playerIndex != currentPlayerIndex
    ) {
      return false;
    }

    if (_tableDominoes.isEmpty) {
      final openingDomino =
          requiredOpeningDomino;

      if (openingDomino == null) {
        return false;
      }

      return _sameDomino(
        domino,
        openingDomino,
      );
    }

    final openValue =
        side == DominoSide.left
            ? leftOpenValue!
            : rightOpenValue!;

    return domino.left == openValue ||
        domino.right == openValue;
  }

  bool canPlayDomino({
    required int playerIndex,
    required Domino domino,
  }) {
    return canDominoPlayOnSide(
          playerIndex: playerIndex,
          domino: domino,
          side: DominoSide.left,
        ) ||
        canDominoPlayOnSide(
          playerIndex: playerIndex,
          domino: domino,
          side: DominoSide.right,
        );
  }

  DominoMoveResult? playDomino({
    required int playerIndex,
    required int handIndex,
    required DominoSide preferredSide,
  }) {
    if (
      !canPlayHandIndex(
        playerIndex: playerIndex,
        handIndex: handIndex,
      )
    ) {
      return null;
    }

    final hand =
        _hands[playerIndex];

    final domino =
        hand[handIndex];

    late final DominoSide sideToPlay;
    late final Domino playedDomino;
    late final int tableIndex;

    if (_tableDominoes.isEmpty) {
      sideToPlay = DominoSide.right;
      playedDomino = domino;
      tableIndex = 0;

      hand.removeAt(handIndex);
      _tableDominoes.add(
        playedDomino,
      );

      _openingTableIndex = 0;

      _openingPlayerIndex = null;
      _openingHandIndex = null;
    } else {
      final canLeft =
          canDominoPlayOnSide(
        playerIndex: playerIndex,
        domino: domino,
        side: DominoSide.left,
      );

      final canRight =
          canDominoPlayOnSide(
        playerIndex: playerIndex,
        domino: domino,
        side: DominoSide.right,
      );

      if (canLeft && canRight) {
        sideToPlay = preferredSide;
      } else if (canLeft) {
        sideToPlay = DominoSide.left;
      } else {
        sideToPlay = DominoSide.right;
      }

      if (sideToPlay == DominoSide.left) {
        playedDomino =
            _orientForLeft(
          domino,
          leftOpenValue!,
        );

        hand.removeAt(handIndex);

        _tableDominoes.insert(
          0,
          playedDomino,
        );

        if (_openingTableIndex >= 0) {
          _openingTableIndex++;
        }

        tableIndex = 0;
      } else {
        playedDomino =
            _orientForRight(
          domino,
          rightOpenValue!,
        );

        hand.removeAt(handIndex);

        tableIndex =
            _tableDominoes.length;

        _tableDominoes.add(
          playedDomino,
        );
      }
    }

    _consecutivePasses = 0;

    if (hand.isEmpty) {
      _finishRound(
        reason:
            DominoRoundEndReason.domino,
        winnerIndices: [
          playerIndex,
        ],
      );
    } else {
      _advancePlayer();
    }

    return DominoMoveResult(
      playerIndex: playerIndex,
      handIndex: handIndex,
      playedDomino: playedDomino,
      side: sideToPlay,
      tableIndex: tableIndex,
      roundEnded: isRoundOver,
    );
  }

  DominoPassResult? skipTurn(
    int playerIndex,
  ) {
    if (
      isRoundOver ||
      playerIndex != currentPlayerIndex ||
      hasLegalMove(playerIndex) ||
      _boneyard.isNotEmpty
    ) {
      return null;
    }

    _consecutivePasses++;

    if (
      _consecutivePasses >=
          playerCount
    ) {
      _finishFishRound();
    } else {
      _advancePlayer();
    }

    return DominoPassResult(
      playerIndex: playerIndex,
      roundEnded: isRoundOver,
    );
  }

  DominoMoveResult? playAutomaticTurn(
    int playerIndex,
  ) {
    final legal =
        legalHandIndicesForPlayer(
      playerIndex,
    );

    if (legal.isEmpty) {
      return null;
    }

    var bestHandIndex =
        legal.first;

    for (final candidate in legal.skip(1)) {
      final currentBest =
          _hands[playerIndex]
              [bestHandIndex];

      final candidateDomino =
          _hands[playerIndex]
              [candidate];

      if (
        _autoMoveWeight(
          candidateDomino,
        ) >
        _autoMoveWeight(
          currentBest,
        )
      ) {
        bestHandIndex = candidate;
      }
    }

    final domino =
        _hands[playerIndex]
            [bestHandIndex];

    final canRight =
        canDominoPlayOnSide(
      playerIndex: playerIndex,
      domino: domino,
      side: DominoSide.right,
    );

    final preferredSide =
        canRight
            ? DominoSide.right
            : DominoSide.left;

    return playDomino(
      playerIndex: playerIndex,
      handIndex: bestHandIndex,
      preferredSide: preferredSide,
    );
  }

  List<Domino> _createFullSet() {
    final result = <Domino>[];

    for (var left = 0; left <= 6; left++) {
      for (
        var right = left;
        right <= 6;
        right++
      ) {
        result.add(
          Domino(
            left: left,
            right: right,
          ),
        );
      }
    }

    return result;
  }

  void _chooseOpeningPlayer() {
    int? chosenPlayer;
    int? chosenHandIndex;

    for (
      var doubleValue = 6;
      doubleValue >= 0;
      doubleValue--
    ) {
      for (
        var playerIndex = 0;
        playerIndex < playerCount;
        playerIndex++
      ) {
        final hand =
            _hands[playerIndex];

        for (
          var handIndex = 0;
          handIndex < hand.length;
          handIndex++
        ) {
          final domino =
              hand[handIndex];

          if (
            domino.left == doubleValue &&
            domino.right == doubleValue
          ) {
            chosenPlayer =
                playerIndex;

            chosenHandIndex =
                handIndex;

            break;
          }
        }

        if (chosenPlayer != null) {
          break;
        }
      }

      if (chosenPlayer != null) {
        break;
      }
    }

    if (chosenPlayer == null) {
      var bestWeight = -1;

      for (
        var playerIndex = 0;
        playerIndex < playerCount;
        playerIndex++
      ) {
        final hand =
            _hands[playerIndex];

        for (
          var handIndex = 0;
          handIndex < hand.length;
          handIndex++
        ) {
          final weight =
              hand[handIndex].left +
              hand[handIndex].right;

          if (weight > bestWeight) {
            bestWeight = weight;
            chosenPlayer =
                playerIndex;

            chosenHandIndex =
                handIndex;
          }
        }
      }
    }

    _openingPlayerIndex =
        chosenPlayer;

    _openingHandIndex =
        chosenHandIndex;

    currentPlayerIndex =
        chosenPlayer ?? 0;
  }

  void _advancePlayer() {
    final currentOrderIndex =
        _turnOrder.indexOf(
      currentPlayerIndex,
    );

    if (currentOrderIndex == -1) {
      currentPlayerIndex =
          _turnOrder.first;
      return;
    }

    final nextOrderIndex =
        (currentOrderIndex + 1) %
        _turnOrder.length;

    currentPlayerIndex =
        _turnOrder[nextOrderIndex];
  }

  void _finishFishRound() {
    final points =
        List<int>.generate(
      playerCount,
      _handPointsFor,
    );

    final minimum =
        points.reduce(min);

    final winners = <int>[];

    for (
      var index = 0;
      index < points.length;
      index++
    ) {
      if (points[index] == minimum) {
        winners.add(index);
      }
    }

    _finishRound(
      reason:
          DominoRoundEndReason.fish,
      winnerIndices: winners,
      precomputedHandPoints:
          points,
    );
  }

  void _finishRound({
    required DominoRoundEndReason reason,
    required List<int> winnerIndices,
    List<int>? precomputedHandPoints,
  }) {
    isRoundOver = true;

    final handPoints =
        precomputedHandPoints ??
        List<int>.generate(
          playerCount,
          _handPointsFor,
        );

    final addedPenalties =
        List<int>.filled(
      playerCount,
      0,
    );

    for (
      var index = 0;
      index < playerCount;
      index++
    ) {
      if (winnerIndices.contains(index)) {
        continue;
      }

      final penalty =
          handPoints[index];

      if (
        penalty >=
        rules.minimumPenaltyToRecord
      ) {
        _scores[index] += penalty;
        addedPenalties[index] =
            penalty;
      }
    }

    final matchLosers = <int>[];

    for (
      var index = 0;
      index < _scores.length;
      index++
    ) {
      if (
        _scores[index] >=
        rules.losingScore
      ) {
        matchLosers.add(index);
      }
    }

    isMatchOver =
        matchLosers.isNotEmpty;

    lastRoundResult =
        DominoRoundResult(
      reason: reason,
      winnerIndices:
          List<int>.unmodifiable(
        winnerIndices,
      ),
      handPoints:
          List<int>.unmodifiable(
        handPoints,
      ),
      addedPenalties:
          List<int>.unmodifiable(
        addedPenalties,
      ),
      totalScores:
          List<int>.unmodifiable(
        _scores,
      ),
      matchLoserIndices:
          List<int>.unmodifiable(
        matchLosers,
      ),
    );
  }

  int _handPointsFor(
    int playerIndex,
  ) {
    final hand =
        _hands[playerIndex];

    if (
      hand.length == 1 &&
      hand.first.left == 0 &&
      hand.first.right == 0
    ) {
      return rules
          .doubleBlankPenaltyWhenAlone;
    }

    var total = 0;

    for (final domino in hand) {
      total +=
          domino.left +
          domino.right;
    }

    return total;
  }

  Domino _orientForLeft(
    Domino domino,
    int openValue,
  ) {
    if (
      domino.right == openValue
    ) {
      return domino;
    }

    return Domino(
      left: domino.right,
      right: domino.left,
    );
  }

  Domino _orientForRight(
    Domino domino,
    int openValue,
  ) {
    if (
      domino.left == openValue
    ) {
      return domino;
    }

    return Domino(
      left: domino.right,
      right: domino.left,
    );
  }

  int _autoMoveWeight(
    Domino domino,
  ) {
    final doubleBonus =
        domino.left ==
                domino.right
            ? 20
            : 0;

    return doubleBonus +
        domino.left +
        domino.right;
  }

  bool _sameDomino(
    Domino first,
    Domino second,
  ) {
    return first.left == second.left &&
        first.right == second.right;
  }
}
