import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/domino.dart';
import 'domino_tile.dart';

enum _ChainDirection { right, left, up, down }

class _ChainPlacement {
  final int tableIndex;
  final Domino domino;
  final Offset center;
  final _ChainDirection direction;

  const _ChainPlacement({
    required this.tableIndex,
    required this.domino,
    required this.center,
    required this.direction,
  });

  Domino get displayDomino {
    if (direction == _ChainDirection.left ||
        direction == _ChainDirection.up) {
      return Domino(left: domino.right, right: domino.left);
    }

    return domino;
  }
}

class _TrackStepGeometry {
  final Offset center;
  final Offset nextConnection;

  const _TrackStepGeometry({
    required this.center,
    required this.nextConnection,
  });
}

class _TrackLayoutDraft {
  final List<_ChainPlacement> placements;
  final Offset leftEnd;
  final Offset rightEnd;
  final _ChainDirection previousDirection;
  final _ChainDirection rowDirection;
  final bool needsTurn;
  final int rowUsedSquares;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _TrackLayoutDraft({
    required this.placements,
    required this.leftEnd,
    required this.rightEnd,
    required this.previousDirection,
    required this.rowDirection,
    required this.needsTurn,
    required this.rowUsedSquares,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });

  double get contentWidth => maxX - minX;
  double get contentHeight => maxY - minY;
}

class _SnakeLayout {
  final List<_ChainPlacement> placements;
  final double dominoShortSide;
  final double width;
  final double height;

  const _SnakeLayout({
    required this.placements,
    required this.dominoShortSide,
    required this.width,
    required this.height,
  });
}

/// Визуальная змейка для сетевой игры.
///
/// Источник истины о порядке и ориентации костей — backend. Этот Widget
/// отвечает только за геометрию отображения на столе.
///
/// Трасса перенесена из GameScreen:
/// - максимум 11 квадратов на горизонтальном ряду;
/// - обычная кость занимает 2 квадрата;
/// - дубль занимает 1 квадрат вдоль направления цепочки и лежит поперёк;
/// - при нехватке места цепочка уходит вниз и меняет направление ряда;
/// - при длинной цепочке размер костей автоматически уменьшается, чтобы
///   змейка не выходила за границы игрового поля.
class MultiplayerDominoSnake extends StatelessWidget {
  static const double _trackGap = 0;
  static const int _horizontalTrackSquares = 11;
  static const double _safeMargin = 18;

  final List<Domino> dominoes;

  const MultiplayerDominoSnake({
    super.key,
    required this.dominoes,
  });

  @override
  Widget build(BuildContext context) {
    if (dominoes.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 1,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 1,
        );
        final layout = _createLayout(boardSize);

        return SizedBox(
          width: layout.width,
          height: layout.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final placement in layout.placements)
                _buildPlacedDomino(
                  placement,
                  shortSide: layout.dominoShortSide,
                ),
            ],
          ),
        );
      },
    );
  }

  double _preferredShortSideForBoard(Size boardSize) {
    final count = dominoes.length;

    final preferredByCount = count <= 7
        ? 32.0
        : count <= 13
            ? 30.0
            : count <= 19
                ? 29.0
                : count <= 24
                    ? 28.0
                    : 27.0;

    final availableWidth = math.max(
      1.0,
      boardSize.width - (_safeMargin * 2),
    );

    final maxByWidth = availableWidth / _horizontalTrackSquares;

    return math.max(
      1.0,
      math.min(preferredByCount, maxByWidth),
    );
  }

  double _longSideFor(double shortSide) => shortSide * 2;

  double _dotSizeFor(double side) {
    if (side >= 32) return 5.0;
    if (side >= 30) return 4.8;
    if (side >= 29) return 4.7;
    if (side >= 28) return 4.6;
    if (side >= 24) return 4.4;
    return math.max(2.8, side * 0.16);
  }

  Offset _directionVector(_ChainDirection direction) {
    return switch (direction) {
      _ChainDirection.right => const Offset(1, 0),
      _ChainDirection.left => const Offset(-1, 0),
      _ChainDirection.up => const Offset(0, -1),
      _ChainDirection.down => const Offset(0, 1),
    };
  }

  bool _directionIsHorizontal(_ChainDirection direction) {
    return direction == _ChainDirection.right ||
        direction == _ChainDirection.left;
  }

  bool _displayHorizontalFor({
    required Domino domino,
    required _ChainDirection direction,
  }) {
    final pathIsHorizontal = _directionIsHorizontal(direction);

    if (domino.left == domino.right) {
      return !pathIsHorizontal;
    }

    return pathIsHorizontal;
  }

  Size _displaySizeFor({
    required Domino domino,
    required _ChainDirection direction,
    required double shortSide,
  }) {
    final horizontal = _displayHorizontalFor(
      domino: domino,
      direction: direction,
    );
    final longSide = _longSideFor(shortSide);

    return Size(
      horizontal ? longSide : shortSide,
      horizontal ? shortSide : longSide,
    );
  }

  double _halfCenterOffsetFor(double shortSide) {
    return (_longSideFor(shortSide) - shortSide) / 2;
  }

  _TrackStepGeometry _placeTrackStep({
    required Offset connectionPoint,
    required _ChainDirection direction,
    required Domino domino,
    required double shortSide,
  }) {
    final vector = _directionVector(direction);
    final isDouble = domino.left == domino.right;

    if (isDouble) {
      final center = connectionPoint + vector * (shortSide + _trackGap);

      return _TrackStepGeometry(
        center: center,
        nextConnection: center,
      );
    }

    final connectingSquareCenter =
        connectionPoint + vector * (shortSide + _trackGap);
    final center = connectingSquareCenter +
        vector * _halfCenterOffsetFor(shortSide);
    final nextConnection =
        center + vector * _halfCenterOffsetFor(shortSide);

    return _TrackStepGeometry(
      center: center,
      nextConnection: nextConnection,
    );
  }

  _TrackLayoutDraft _buildLayoutDraft({required double shortSide}) {
    final rawPlacements = <_ChainPlacement>[];
    final firstDomino = dominoes.first;
    final firstIsDouble = firstDomino.left == firstDomino.right;

    rawPlacements.add(
      _ChainPlacement(
        tableIndex: 0,
        domino: firstDomino,
        center: Offset.zero,
        direction: _ChainDirection.right,
      ),
    );

    final halfCenterOffset = _halfCenterOffsetFor(shortSide);
    final rawLeftEnd =
        firstIsDouble ? Offset.zero : Offset(-halfCenterOffset, 0);

    var connectionPoint =
        firstIsDouble ? Offset.zero : Offset(halfCenterOffset, 0);
    var previousDirection = _ChainDirection.right;
    var rowDirection = _ChainDirection.right;
    var rowUsedSquares = firstIsDouble ? 1 : 2;
    var needsTurn = rowUsedSquares >= _horizontalTrackSquares;

    for (var tableIndex = 1; tableIndex < dominoes.length; tableIndex++) {
      final domino = dominoes[tableIndex];
      final isDouble = domino.left == domino.right;
      final requiredSquares = isDouble ? 1 : 2;
      final wouldOverflow =
          rowUsedSquares + requiredSquares > _horizontalTrackSquares;
      final shouldTurnBeforeDomino = needsTurn || wouldOverflow;

      late final _ChainDirection direction;

      if (shouldTurnBeforeDomino) {
        direction = _ChainDirection.down;
        rowDirection = rowDirection == _ChainDirection.right
            ? _ChainDirection.left
            : _ChainDirection.right;

        // На вертикальном переходе обычная кость занимает ширину одного
        // квадрата нового ряда, а поперечный дубль — двух.
        rowUsedSquares = isDouble ? 2 : 1;
        needsTurn = rowUsedSquares >= _horizontalTrackSquares;
      } else {
        direction = rowDirection;
      }

      final geometry = _placeTrackStep(
        connectionPoint: connectionPoint,
        direction: direction,
        domino: domino,
        shortSide: shortSide,
      );

      rawPlacements.add(
        _ChainPlacement(
          tableIndex: tableIndex,
          domino: domino,
          center: geometry.center,
          direction: direction,
        ),
      );

      connectionPoint = geometry.nextConnection;

      if (_directionIsHorizontal(direction)) {
        rowUsedSquares += requiredSquares;
        needsTurn = rowUsedSquares >= _horizontalTrackSquares;
      }

      previousDirection = direction;
    }

    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;

    for (final placement in rawPlacements) {
      final size = _displaySizeFor(
        domino: placement.domino,
        direction: placement.direction,
        shortSide: shortSide,
      );

      minX = math.min(minX, placement.center.dx - size.width / 2);
      maxX = math.max(maxX, placement.center.dx + size.width / 2);
      minY = math.min(minY, placement.center.dy - size.height / 2);
      maxY = math.max(maxY, placement.center.dy + size.height / 2);
    }

    return _TrackLayoutDraft(
      placements: rawPlacements,
      leftEnd: rawLeftEnd,
      rightEnd: connectionPoint,
      previousDirection: previousDirection,
      rowDirection: rowDirection,
      needsTurn: needsTurn,
      rowUsedSquares: rowUsedSquares,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
  }

  _SnakeLayout _createLayout(Size boardSize) {
    final preferredShortSide = _preferredShortSideForBoard(boardSize);
    final availableWidth = math.max(
      1.0,
      boardSize.width - (_safeMargin * 2),
    );
    final availableHeight = math.max(
      1.0,
      boardSize.height - (_safeMargin * 2),
    );

    var shortSide = preferredShortSide;
    var draft = _buildLayoutDraft(shortSide: shortSide);

    for (var attempt = 0; attempt < 3; attempt++) {
      final widthScale = draft.contentWidth <= 0
          ? 1.0
          : availableWidth / draft.contentWidth;
      final heightScale = draft.contentHeight <= 0
          ? 1.0
          : availableHeight / draft.contentHeight;
      final fitScale = math.min(
        1.0,
        math.min(widthScale, heightScale),
      );

      if (fitScale >= 0.999) break;

      shortSide = math.max(
        1.0,
        shortSide * fitScale * 0.985,
      );
      draft = _buildLayoutDraft(shortSide: shortSide);
    }

    final contentCenterX = (draft.minX + draft.maxX) / 2;
    final contentCenterY = (draft.minY + draft.maxY) / 2;
    final desiredShiftX = boardSize.width / 2 - contentCenterX;
    final desiredShiftY = boardSize.height / 2 - contentCenterY;

    final minShiftX = _safeMargin - draft.minX;
    final maxShiftX = boardSize.width - _safeMargin - draft.maxX;
    final minShiftY = _safeMargin - draft.minY;
    final maxShiftY = boardSize.height - _safeMargin - draft.maxY;

    final shiftX = minShiftX <= maxShiftX
        ? desiredShiftX.clamp(minShiftX, maxShiftX).toDouble()
        : desiredShiftX;
    final shiftY = minShiftY <= maxShiftY
        ? desiredShiftY.clamp(minShiftY, maxShiftY).toDouble()
        : desiredShiftY;
    final shift = Offset(shiftX, shiftY);

    final placements = draft.placements
        .map(
          (placement) => _ChainPlacement(
            tableIndex: placement.tableIndex,
            domino: placement.domino,
            center: placement.center + shift,
            direction: placement.direction,
          ),
        )
        .toList(growable: false);

    return _SnakeLayout(
      placements: placements,
      dominoShortSide: shortSide,
      width: boardSize.width,
      height: boardSize.height,
    );
  }

  Widget _buildPlacedDomino(
    _ChainPlacement placement, {
    required double shortSide,
  }) {
    final horizontal = _displayHorizontalFor(
      domino: placement.domino,
      direction: placement.direction,
    );
    final size = _displaySizeFor(
      domino: placement.domino,
      direction: placement.direction,
      shortSide: shortSide,
    );

    return Positioned(
      key: ValueKey(
        'snake-${placement.tableIndex}-${placement.domino.left}-${placement.domino.right}',
      ),
      left: placement.center.dx - size.width / 2,
      top: placement.center.dy - size.height / 2,
      child: DominoTile(
        domino: placement.displayDomino,
        width: size.width,
        height: size.height,
        dotSize: _dotSizeFor(shortSide),
        horizontal: horizontal,
      ),
    );
  }
}
