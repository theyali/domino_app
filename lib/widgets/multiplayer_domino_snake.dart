import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/domino.dart';
import '../models/multiplayer_game_state.dart';
import 'domino_placement_target.dart';
import 'domino_play_animation.dart';
import 'domino_tile.dart';

enum _ChainDirection { right, left, up, down }

enum _BranchSide { center, left, right }

class _ChainPlacement {
  final int tableIndex;
  final ServerDomino serverDomino;
  final Offset center;
  final _ChainDirection direction;
  final _BranchSide branchSide;

  const _ChainPlacement({
    required this.tableIndex,
    required this.serverDomino,
    required this.center,
    required this.direction,
    required this.branchSide,
  });

  Domino get domino => serverDomino.domino;

  bool get isDouble => domino.left == domino.right;

  Domino get displayDomino {
    if (branchSide == _BranchSide.center) {
      return domino;
    }

    // Backend хранит всю цепочку слева направо.
    // При построении левой ветки мы идём от центра наружу, то есть
    // логическое направление костяшки сначала нужно развернуть.
    var outwardDomino = branchSide == _BranchSide.left
        ? Domino(left: domino.right, right: domino.left)
        : domino;

    // Если сама геометрическая ветка идёт влево или вверх, экранное
    // направление снова разворачивается, чтобы соединяющиеся значения
    // оставались рядом друг с другом.
    if (direction == _ChainDirection.left ||
        direction == _ChainDirection.up) {
      outwardDomino = Domino(
        left: outwardDomino.right,
        right: outwardDomino.left,
      );
    }

    return outwardDomino;
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

class _BranchTrackState {
  final Offset connectionPoint;
  final _ChainDirection previousDirection;
  final _ChainDirection rowDirection;
  final bool needsTurn;
  final int rowUsedSquares;
  final bool initialRow;

  const _BranchTrackState({
    required this.connectionPoint,
    required this.previousDirection,
    required this.rowDirection,
    required this.needsTurn,
    required this.rowUsedSquares,
    required this.initialRow,
  });

  _BranchTrackState shifted(Offset offset) {
    return _BranchTrackState(
      connectionPoint: connectionPoint + offset,
      previousDirection: previousDirection,
      rowDirection: rowDirection,
      needsTurn: needsTurn,
      rowUsedSquares: rowUsedSquares,
      initialRow: initialRow,
    );
  }
}

class _BranchBuildResult {
  final List<_ChainPlacement> placements;
  final _BranchTrackState state;

  const _BranchBuildResult({
    required this.placements,
    required this.state,
  });
}

class _TrackLayoutDraft {
  final List<_ChainPlacement> placements;
  final _BranchTrackState leftState;
  final _BranchTrackState rightState;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _TrackLayoutDraft({
    required this.placements,
    required this.leftState,
    required this.rightState,
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
  final _BranchTrackState leftState;
  final _BranchTrackState rightState;
  final double dominoShortSide;
  final double width;
  final double height;

  const _SnakeLayout({
    required this.placements,
    required this.leftState,
    required this.rightState,
    required this.dominoShortSide,
    required this.width,
    required this.height,
  });
}

/// Сетевая версия фиксированной змейки.
///
/// Backend остаётся источником истины по порядку и ориентации костей.
/// Widget отвечает только за визуальную трассу, пунктиры и анимацию.
///
/// Первая сыгранная кость остаётся визуальным центром. Ходы влево
/// достраивают левую ветку, а ходы вправо — правую, поэтому существующая
/// цепочка не прыгает при серверном insert(0).
class MultiplayerDominoSnake extends StatelessWidget {
  static const double _trackGap = 0;
  static const int _horizontalTrackSquares = 11;

  // Первая горизонталь расходится от центра в две стороны. По 5 квадратов
  // на ветку + центральная зона дают тот же бюджет примерно в 11 квадратов.
  static const int _initialBranchSquares = 5;
  static const double _safeMargin = 18;

  final List<ServerDomino> dominoes;
  final ServerDomino? selectedDomino;
  final Set<String> playableSides;
  final ValueChanged<String>? onTargetTap;

  final int? animatedMoveNumber;
  final Offset? animationSourceGlobalCenter;
  final bool soundEnabled;
  final VoidCallback? onDoubleImpact;

  const MultiplayerDominoSnake({
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
    if (dominoes.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final boardSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 1,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 1,
        );
        final layout = _createLayout(
          boardSize,
          targetDomino: selectedDomino?.domino,
          targetSides: playableSides,
        );

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
              if (selectedDomino != null &&
                  playableSides.contains('left') &&
                  onTargetTap != null)
                _buildPlacementTarget(
                  state: layout.leftState,
                  side: _BranchSide.left,
                  domino: selectedDomino!.domino,
                  shortSide: layout.dominoShortSide,
                  onTap: () => onTargetTap!('left'),
                ),
              if (selectedDomino != null &&
                  playableSides.contains('right') &&
                  onTargetTap != null)
                _buildPlacementTarget(
                  state: layout.rightState,
                  side: _BranchSide.right,
                  domino: selectedDomino!.domino,
                  shortSide: layout.dominoShortSide,
                  onTap: () => onTargetTap!('right'),
                ),
            ],
          ),
        );
      },
    );
  }

  int _openingIndex() {
    final byMoveNumber = dominoes.indexWhere(
      (domino) => domino.moveNumber == 1,
    );
    if (byMoveNumber >= 0) {
      return byMoveNumber;
    }

    final bySide = dominoes.indexWhere(
      (domino) => domino.side == 'center',
    );
    if (bySide >= 0) {
      return bySide;
    }

    return 0;
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

  _ChainDirection _oppositeDirection(_ChainDirection direction) {
    return switch (direction) {
      _ChainDirection.right => _ChainDirection.left,
      _ChainDirection.left => _ChainDirection.right,
      _ChainDirection.up => _ChainDirection.down,
      _ChainDirection.down => _ChainDirection.up,
    };
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
    final center =
        connectingSquareCenter + vector * _halfCenterOffsetFor(shortSide);
    final nextConnection =
        center + vector * _halfCenterOffsetFor(shortSide);

    return _TrackStepGeometry(
      center: center,
      nextConnection: nextConnection,
    );
  }

  int _rowLimit(_BranchTrackState state) {
    return state.initialRow
        ? _initialBranchSquares
        : _horizontalTrackSquares;
  }

  _ChainDirection _verticalDirectionFor(_BranchSide side) {
    return side == _BranchSide.left
        ? _ChainDirection.up
        : _ChainDirection.down;
  }

  _ChainDirection _nextDirectionFor({
    required _BranchTrackState state,
    required _BranchSide side,
    required Domino domino,
  }) {
    final requiredSquares = domino.left == domino.right ? 1 : 2;
    final wouldOverflow =
        state.rowUsedSquares + requiredSquares > _rowLimit(state);

    if (state.needsTurn || wouldOverflow) {
      return _verticalDirectionFor(side);
    }

    return state.rowDirection;
  }

  _BranchBuildResult _buildBranch({
    required List<MapEntry<int, ServerDomino>> items,
    required Offset startConnectionPoint,
    required _BranchSide side,
    required double shortSide,
  }) {
    var connectionPoint = startConnectionPoint;
    var rowDirection = side == _BranchSide.left
        ? _ChainDirection.left
        : _ChainDirection.right;
    var previousDirection = rowDirection;
    var rowUsedSquares = 0;
    var needsTurn = false;
    var initialRow = true;

    final placements = <_ChainPlacement>[];

    for (final item in items) {
      final domino = item.value.domino;
      final isDouble = domino.left == domino.right;
      final requiredSquares = isDouble ? 1 : 2;
      final rowLimit = initialRow
          ? _initialBranchSquares
          : _horizontalTrackSquares;
      final wouldOverflow =
          rowUsedSquares + requiredSquares > rowLimit;
      final shouldTurnBeforeDomino = needsTurn || wouldOverflow;

      late final _ChainDirection direction;

      if (shouldTurnBeforeDomino) {
        direction = _verticalDirectionFor(side);
        rowDirection = _oppositeDirection(rowDirection);
        initialRow = false;

        // После вертикального перехода физическая ширина занятого начала
        // нового ряда равна одному квадрату у обычной кости и двум у дубля.
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

      placements.add(
        _ChainPlacement(
          tableIndex: item.key,
          serverDomino: item.value,
          center: geometry.center,
          direction: direction,
          branchSide: side,
        ),
      );

      connectionPoint = geometry.nextConnection;

      if (_directionIsHorizontal(direction)) {
        rowUsedSquares += requiredSquares;
        final activeLimit = initialRow
            ? _initialBranchSquares
            : _horizontalTrackSquares;
        needsTurn = rowUsedSquares >= activeLimit;
      }

      previousDirection = direction;
    }

    return _BranchBuildResult(
      placements: placements,
      state: _BranchTrackState(
        connectionPoint: connectionPoint,
        previousDirection: previousDirection,
        rowDirection: rowDirection,
        needsTurn: needsTurn,
        rowUsedSquares: rowUsedSquares,
        initialRow: initialRow,
      ),
    );
  }

  void _includeRectInBounds({
    required Rect rect,
    required List<double> bounds,
  }) {
    bounds[0] = math.min(bounds[0], rect.left);
    bounds[1] = math.max(bounds[1], rect.right);
    bounds[2] = math.min(bounds[2], rect.top);
    bounds[3] = math.max(bounds[3], rect.bottom);
  }

  Rect _targetRectFor({
    required _BranchTrackState state,
    required _BranchSide side,
    required Domino domino,
    required double shortSide,
  }) {
    final direction = _nextDirectionFor(
      state: state,
      side: side,
      domino: domino,
    );
    final geometry = _placeTrackStep(
      connectionPoint: state.connectionPoint,
      direction: direction,
      domino: domino,
      shortSide: shortSide,
    );
    final size = _displaySizeFor(
      domino: domino,
      direction: direction,
      shortSide: shortSide,
    );

    return Rect.fromCenter(
      center: geometry.center,
      width: size.width,
      height: size.height,
    );
  }

  _TrackLayoutDraft _buildLayoutDraft({
    required double shortSide,
    Domino? targetDomino,
    Set<String> targetSides = const <String>{},
  }) {
    final openingIndex = _openingIndex();
    final opening = dominoes[openingIndex];
    final openingDomino = opening.domino;
    final openingIsDouble = openingDomino.left == openingDomino.right;

    final halfCenterOffset = _halfCenterOffsetFor(shortSide);
    final leftStartConnection = openingIsDouble
        ? Offset.zero
        : Offset(-halfCenterOffset, 0);
    final rightStartConnection = openingIsDouble
        ? Offset.zero
        : Offset(halfCenterOffset, 0);

    final leftItems = <MapEntry<int, ServerDomino>>[];
    for (var index = openingIndex - 1; index >= 0; index--) {
      leftItems.add(MapEntry(index, dominoes[index]));
    }

    final rightItems = <MapEntry<int, ServerDomino>>[];
    for (var index = openingIndex + 1; index < dominoes.length; index++) {
      rightItems.add(MapEntry(index, dominoes[index]));
    }

    final leftBranch = _buildBranch(
      items: leftItems,
      startConnectionPoint: leftStartConnection,
      side: _BranchSide.left,
      shortSide: shortSide,
    );
    final rightBranch = _buildBranch(
      items: rightItems,
      startConnectionPoint: rightStartConnection,
      side: _BranchSide.right,
      shortSide: shortSide,
    );

    final placements = <_ChainPlacement>[
      _ChainPlacement(
        tableIndex: openingIndex,
        serverDomino: opening,
        center: Offset.zero,
        direction: _ChainDirection.right,
        branchSide: _BranchSide.center,
      ),
      ...leftBranch.placements,
      ...rightBranch.placements,
    ];

    final bounds = <double>[
      double.infinity,
      double.negativeInfinity,
      double.infinity,
      double.negativeInfinity,
    ];

    for (final placement in placements) {
      final size = _displaySizeFor(
        domino: placement.domino,
        direction: placement.direction,
        shortSide: shortSide,
      );

      _includeRectInBounds(
        rect: Rect.fromCenter(
          center: placement.center,
          width: size.width,
          height: size.height,
        ),
        bounds: bounds,
      );
    }

    // Пунктир участвует в расчёте fit/shift. Поэтому мы не двигаем его
    // отдельно к безопасному краю: он остаётся точно на будущей траектории.
    if (targetDomino != null && targetSides.contains('left')) {
      _includeRectInBounds(
        rect: _targetRectFor(
          state: leftBranch.state,
          side: _BranchSide.left,
          domino: targetDomino,
          shortSide: shortSide,
        ),
        bounds: bounds,
      );
    }

    if (targetDomino != null && targetSides.contains('right')) {
      _includeRectInBounds(
        rect: _targetRectFor(
          state: rightBranch.state,
          side: _BranchSide.right,
          domino: targetDomino,
          shortSide: shortSide,
        ),
        bounds: bounds,
      );
    }

    return _TrackLayoutDraft(
      placements: placements,
      leftState: leftBranch.state,
      rightState: rightBranch.state,
      minX: bounds[0],
      maxX: bounds[1],
      minY: bounds[2],
      maxY: bounds[3],
    );
  }

  _SnakeLayout _createLayout(
    Size boardSize, {
    Domino? targetDomino,
    Set<String> targetSides = const <String>{},
  }) {
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
    var draft = _buildLayoutDraft(
      shortSide: shortSide,
      targetDomino: targetDomino,
      targetSides: targetSides,
    );

    for (var attempt = 0; attempt < 4; attempt++) {
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
      draft = _buildLayoutDraft(
        shortSide: shortSide,
        targetDomino: targetDomino,
        targetSides: targetSides,
      );
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
            serverDomino: placement.serverDomino,
            center: placement.center + shift,
            direction: placement.direction,
            branchSide: placement.branchSide,
          ),
        )
        .toList(growable: false);

    return _SnakeLayout(
      placements: placements,
      leftState: draft.leftState.shifted(shift),
      rightState: draft.rightState.shifted(shift),
      dominoShortSide: shortSide,
      width: boardSize.width,
      height: boardSize.height,
    );
  }

  Widget _buildPlacementTarget({
    required _BranchTrackState state,
    required _BranchSide side,
    required Domino domino,
    required double shortSide,
    required VoidCallback onTap,
  }) {
    final direction = _nextDirectionFor(
      state: state,
      side: side,
      domino: domino,
    );
    final geometry = _placeTrackStep(
      connectionPoint: state.connectionPoint,
      direction: direction,
      domino: domino,
      shortSide: shortSide,
    );
    final size = _displaySizeFor(
      domino: domino,
      direction: direction,
      shortSide: shortSide,
    );

    return Positioned(
      left: geometry.center.dx - size.width / 2,
      top: geometry.center.dy - size.height / 2,
      child: DominoPlacementTarget(
        width: size.width,
        height: size.height,
        onTap: onTap,
      ),
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

    final tile = DominoTile(
      domino: placement.displayDomino,
      width: size.width,
      height: size.height,
      dotSize: _dotSizeFor(shortSide),
      horizontal: horizontal,
    );

    final shouldAnimate = animationSourceGlobalCenter != null &&
        animatedMoveNumber != null &&
        placement.serverDomino.moveNumber == animatedMoveNumber;

    final child = shouldAnimate
        ? DominoPlayAnimation(
            key: ValueKey('multiplayer-play-$animatedMoveNumber'),
            sourceGlobalCenter: animationSourceGlobalCenter!,
            isDouble: placement.isDouble,
            horizontal: horizontal,
            soundEnabled: soundEnabled,
            onDoubleImpact: onDoubleImpact,
            child: tile,
          )
        : tile;

    return Positioned(
      key: ValueKey(
        'snake-${placement.serverDomino.id}-${placement.serverDomino.moveNumber}',
      ),
      left: placement.center.dx - size.width / 2,
      top: placement.center.dy - size.height / 2,
      child: child,
    );
  }
}
