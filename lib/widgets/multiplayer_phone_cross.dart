import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/domino.dart';
import '../models/multiplayer_game_state.dart';
import 'domino_placement_target.dart';
import 'domino_play_animation.dart';
import 'domino_tile.dart';

enum _PhoneDirection { top, right, bottom, left }

class _PlacedPhoneDomino {
  final ServerDomino domino;
  final Offset center;
  final _PhoneDirection direction;

  const _PlacedPhoneDomino({
    required this.domino,
    required this.center,
    required this.direction,
  });
}

class _PhoneBranchEnd {
  final Offset connection;
  final _PhoneDirection direction;

  const _PhoneBranchEnd({
    required this.connection,
    required this.direction,
  });
}

/// Игровое поле режима «Телефон».
///
/// Сервер хранит четыре независимые ветки в поле `side` (`top/right/bottom/left`)
/// и остаётся источником истины для допустимых ходов. Этот widget отвечает
/// только за геометрию креста, пунктирные цели и анимацию приземления.
class MultiplayerPhoneCross extends StatelessWidget {
  static const double _safeMargin = 14;
  static const double _preferredShortSide = 29;

  final List<ServerDomino> dominoes;
  final ServerDomino? selectedDomino;
  final Set<String> playableSides;
  final ValueChanged<String>? onTargetTap;
  final int? animatedMoveNumber;
  final Offset? animationSourceGlobalCenter;
  final bool soundEnabled;
  final VoidCallback? onDoubleImpact;

  const MultiplayerPhoneCross({
    super.key,
    required this.dominoes,
    this.selectedDomino,
    this.playableSides = const <String>{},
    this.onTargetTap,
    this.animatedMoveNumber,
    this.animationSourceGlobalCenter,
    this.soundEnabled = true,
    this.onDoubleImpact,
  });

  @override
  Widget build(BuildContext context) {
    if (dominoes.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 1,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 1,
        );
        final shortSide = _shortSideFor(size);
        final center = Offset(size.width / 2, size.height / 2);
        final opening = _openingDomino;
        final placements = <_PlacedPhoneDomino>[];
        final branchEnds = <String, _PhoneBranchEnd>{};

        final openingSize = Size(shortSide, shortSide * 2);
        placements.add(
          _PlacedPhoneDomino(
            domino: opening,
            center: center,
            direction: _PhoneDirection.bottom,
          ),
        );

        for (final side in const ['top', 'right', 'bottom', 'left']) {
          final direction = _directionFor(side);
          var connection = _openingConnection(
            center: center,
            openingSize: openingSize,
            direction: direction,
          );

          final branch = dominoes
              .where((item) => item.side == side)
              .toList(growable: false)
            ..sort(
              (a, b) => (a.moveNumber ?? 0).compareTo(b.moveNumber ?? 0),
            );

          for (final domino in branch) {
            final geometry = _step(
              connection: connection,
              domino: domino.domino,
              direction: direction,
              shortSide: shortSide,
            );
            placements.add(
              _PlacedPhoneDomino(
                domino: domino,
                center: geometry.$1,
                direction: direction,
              ),
            );
            connection = geometry.$2;
          }

          branchEnds[side] = _PhoneBranchEnd(
            connection: connection,
            direction: direction,
          );
        }

        return SizedBox(
          width: size.width,
          height: size.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final placement in placements)
                _buildPlacedDomino(placement, shortSide: shortSide),
              if (selectedDomino != null && onTargetTap != null)
                for (final side in const ['top', 'right', 'bottom', 'left'])
                  if (playableSides.contains(side))
                    _buildTarget(
                      end: branchEnds[side]!,
                      domino: selectedDomino!.domino,
                      shortSide: shortSide,
                      onTap: () => onTargetTap!(side),
                    ),
            ],
          ),
        );
      },
    );
  }

  ServerDomino get _openingDomino {
    for (final domino in dominoes) {
      if (domino.side == 'center' || domino.moveNumber == 1) return domino;
    }
    return dominoes.first;
  }

  double _shortSideFor(Size boardSize) {
    int units(String side) {
      var value = 0;
      for (final domino in dominoes) {
        if (domino.side != side) continue;
        value += domino.isDouble ? 1 : 2;
      }
      if (selectedDomino != null && playableSides.contains(side)) {
        value += selectedDomino!.isDouble ? 1 : 2;
      }
      return value;
    }

    final horizontalUnits = units('left') + units('right') + 1;
    final verticalUnits = units('top') + units('bottom') + 2;
    final availableWidth = math.max(1.0, boardSize.width - _safeMargin * 2);
    final availableHeight = math.max(1.0, boardSize.height - _safeMargin * 2);
    final byWidth = availableWidth / math.max(1, horizontalUnits);
    final byHeight = availableHeight / math.max(1, verticalUnits);
    return math.max(10.0, math.min(_preferredShortSide, math.min(byWidth, byHeight)));
  }

  _PhoneDirection _directionFor(String side) => switch (side) {
        'top' => _PhoneDirection.top,
        'right' => _PhoneDirection.right,
        'bottom' => _PhoneDirection.bottom,
        _ => _PhoneDirection.left,
      };

  Offset _vector(_PhoneDirection direction) => switch (direction) {
        _PhoneDirection.top => const Offset(0, -1),
        _PhoneDirection.right => const Offset(1, 0),
        _PhoneDirection.bottom => const Offset(0, 1),
        _PhoneDirection.left => const Offset(-1, 0),
      };

  bool _horizontal(_PhoneDirection direction) =>
      direction == _PhoneDirection.left || direction == _PhoneDirection.right;

  Offset _openingConnection({
    required Offset center,
    required Size openingSize,
    required _PhoneDirection direction,
  }) {
    return switch (direction) {
      _PhoneDirection.top => center - Offset(0, openingSize.height / 2),
      _PhoneDirection.bottom => center + Offset(0, openingSize.height / 2),
      _PhoneDirection.left => center - Offset(openingSize.width / 2, 0),
      _PhoneDirection.right => center + Offset(openingSize.width / 2, 0),
    };
  }

  (Offset, Offset) _step({
    required Offset connection,
    required Domino domino,
    required _PhoneDirection direction,
    required double shortSide,
  }) {
    final vector = _vector(direction);
    final pathLength = domino.left == domino.right ? shortSide : shortSide * 2;
    final center = connection + vector * (pathLength / 2);
    final nextConnection = center + vector * (pathLength / 2);
    return (center, nextConnection);
  }

  Size _displaySize({
    required Domino domino,
    required _PhoneDirection direction,
    required double shortSide,
  }) {
    final pathHorizontal = _horizontal(direction);
    final dominoHorizontal = domino.left == domino.right
        ? !pathHorizontal
        : pathHorizontal;
    return Size(
      dominoHorizontal ? shortSide * 2 : shortSide,
      dominoHorizontal ? shortSide : shortSide * 2,
    );
  }

  Domino _displayDomino(
    Domino domino,
    _PhoneDirection direction,
  ) {
    // Сервер хранит left = значение ближе к центру, right = наружный конец.
    // Для веток, идущих вверх/влево, экранное направление обратное.
    if (direction == _PhoneDirection.top || direction == _PhoneDirection.left) {
      return Domino(left: domino.right, right: domino.left);
    }
    return domino;
  }

  double _dotSize(double shortSide) => math.max(2.5, shortSide * 0.16);

  Widget _buildPlacedDomino(
    _PlacedPhoneDomino placement, {
    required double shortSide,
  }) {
    final isOpening = placement.domino.side == 'center' ||
        placement.domino.moveNumber == 1;
    final size = isOpening
        ? Size(shortSide, shortSide * 2)
        : _displaySize(
            domino: placement.domino.domino,
            direction: placement.direction,
            shortSide: shortSide,
          );
    final horizontal = size.width > size.height;
    final displayDomino = isOpening
        ? placement.domino.domino
        : _displayDomino(placement.domino.domino, placement.direction);

    final tile = DominoTile(
      domino: displayDomino,
      width: size.width,
      height: size.height,
      dotSize: _dotSize(shortSide),
      horizontal: horizontal,
    );

    final shouldAnimate = animationSourceGlobalCenter != null &&
        animatedMoveNumber != null &&
        placement.domino.moveNumber == animatedMoveNumber;

    final child = shouldAnimate
        ? DominoPlayAnimation(
            key: ValueKey('phone-play-$animatedMoveNumber'),
            sourceGlobalCenter: animationSourceGlobalCenter!,
            isDouble: placement.domino.isDouble,
            horizontal: horizontal,
            soundEnabled: soundEnabled,
            onDoubleImpact: onDoubleImpact,
            child: tile,
          )
        : tile;

    return Positioned(
      left: placement.center.dx - size.width / 2,
      top: placement.center.dy - size.height / 2,
      child: child,
    );
  }

  Widget _buildTarget({
    required _PhoneBranchEnd end,
    required Domino domino,
    required double shortSide,
    required VoidCallback onTap,
  }) {
    final geometry = _step(
      connection: end.connection,
      domino: domino,
      direction: end.direction,
      shortSide: shortSide,
    );
    final size = _displaySize(
      domino: domino,
      direction: end.direction,
      shortSide: shortSide,
    );

    return Positioned(
      left: geometry.$1.dx - size.width / 2,
      top: geometry.$1.dy - size.height / 2,
      child: DominoPlacementTarget(
        width: size.width,
        height: size.height,
        onTap: onTap,
      ),
    );
  }
}
