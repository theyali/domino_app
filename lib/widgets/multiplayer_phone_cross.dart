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
  final Offset centerUnits;
  final _PhoneDirection direction;

  const _PlacedPhoneDomino({
    required this.domino,
    required this.centerUnits,
    required this.direction,
  });
}

class _PhoneBranchState {
  final String side;
  final Offset connectionUnits;
  final int segmentIndex;
  final double usedUnits;
  final _PhoneDirection previousDirection;
  final bool previousWasDouble;

  const _PhoneBranchState({
    required this.side,
    required this.connectionUnits,
    required this.segmentIndex,
    required this.usedUnits,
    required this.previousDirection,
    required this.previousWasDouble,
  });
}

class _PhoneBranchBuildResult {
  final List<_PlacedPhoneDomino> placements;
  final _PhoneBranchState state;

  const _PhoneBranchBuildResult({
    required this.placements,
    required this.state,
  });
}

class _PhoneLayoutDraft {
  final List<_PlacedPhoneDomino> placements;
  final Map<String, _PhoneBranchState> branchStates;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;

  const _PhoneLayoutDraft({
    required this.placements,
    required this.branchStates,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });
}

/// Визуальная раскладка режима «Телефон».
///
/// Сервер остаётся источником истины и хранит четыре независимых конца:
/// top / right / bottom / left. От центрального дубля каждый луч проходит
/// только одну обычную костяшку прямо, после чего сразу уходит в отдельную
/// змейку в своём секторе стола.
///
/// Так сохраняется правило четырёх открытых концов «Телефона», но визуально
/// поле больше не растёт длинным крестом через весь экран.
class MultiplayerPhoneCross extends StatelessWidget {
  static const double _safeMargin = 16;
  static const double _preferredShortSide = 29;

  /// Одна обычная костяшка от центра = 2 квадратных единицы. После неё луч
  /// обязательно поворачивает и продолжает путь змейкой.
  static const double _initialRunUnits = 2;

  /// В каждом длинном ряду помещаются максимум две обычные костяшки.
  static const double _rowRunUnits = 4;

  /// Вынос следующего ряда наружу. Три квадрата оставляют место дублю,
  /// лежащему поперёк цепочки.
  static const double _rowStepUnits = 3;

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
        final boardSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 1,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 1,
        );
        final draft = _buildDraft();
        final shortSide = _shortSideFor(boardSize, draft);
        final boardCenter = Offset(boardSize.width / 2, boardSize.height / 2);

        return SizedBox(
          width: boardSize.width,
          height: boardSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final placement in draft.placements)
                _buildPlacedDomino(
                  placement,
                  shortSide: shortSide,
                  boardCenter: boardCenter,
                ),
              if (selectedDomino != null && onTargetTap != null)
                for (final side in const ['top', 'right', 'bottom', 'left'])
                  if (playableSides.contains(side))
                    _buildTarget(
                      state: draft.branchStates[side]!,
                      domino: selectedDomino!.domino,
                      shortSide: shortSide,
                      boardCenter: boardCenter,
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

  _PhoneDirection _baseDirection(String side) => switch (side) {
        'top' => _PhoneDirection.top,
        'right' => _PhoneDirection.right,
        'bottom' => _PhoneDirection.bottom,
        _ => _PhoneDirection.left,
      };

  _PhoneDirection _directionForSegment(String side, int segmentIndex) {
    if (segmentIndex == 0) return _baseDirection(side);

    if (segmentIndex.isEven) return _baseDirection(side);

    final rowNumber = (segmentIndex - 1) ~/ 2;
    final forward = rowNumber.isEven;

    return switch (side) {
      'top' => forward ? _PhoneDirection.right : _PhoneDirection.left,
      'right' => forward ? _PhoneDirection.bottom : _PhoneDirection.top,
      'bottom' => forward ? _PhoneDirection.left : _PhoneDirection.right,
      _ => forward ? _PhoneDirection.top : _PhoneDirection.bottom,
    };
  }

  double _limitForSegment(int segmentIndex) {
    if (segmentIndex == 0) return _initialRunUnits;
    return segmentIndex.isOdd ? _rowRunUnits : _rowStepUnits;
  }

  Offset _vector(_PhoneDirection direction) => switch (direction) {
        _PhoneDirection.top => const Offset(0, -1),
        _PhoneDirection.right => const Offset(1, 0),
        _PhoneDirection.bottom => const Offset(0, 1),
        _PhoneDirection.left => const Offset(-1, 0),
      };

  bool _horizontal(_PhoneDirection direction) =>
      direction == _PhoneDirection.left ||
      direction == _PhoneDirection.right;

  double _pathUnits(Domino domino) => domino.left == domino.right ? 1 : 2;

  Offset _openingConnectionUnits(String side) {
    return switch (side) {
      'top' => const Offset(0, -0.5),
      'bottom' => const Offset(0, 0.5),
      'left' => Offset.zero,
      _ => Offset.zero,
    };
  }

  _PhoneBranchState _initialState(String side) {
    final direction = _baseDirection(side);
    return _PhoneBranchState(
      side: side,
      connectionUnits: _openingConnectionUnits(side),
      segmentIndex: 0,
      usedUnits: 0,
      previousDirection: direction,
      previousWasDouble: false,
    );
  }

  _PhoneBranchState _prepareForDomino(
    _PhoneBranchState state,
    Domino domino,
  ) {
    final requiredUnits = _pathUnits(domino);
    var segmentIndex = state.segmentIndex;
    var usedUnits = state.usedUnits;
    var connection = state.connectionUnits;

    var direction = _directionForSegment(state.side, segmentIndex);
    var limit = _limitForSegment(segmentIndex);

    if (usedUnits + requiredUnits > limit) {
      segmentIndex += 1;
      usedUnits = 0;
      final nextDirection = _directionForSegment(state.side, segmentIndex);

      if (state.previousWasDouble && nextDirection != state.previousDirection) {
        connection += _vector(nextDirection) * 0.5;
      }

      direction = nextDirection;
      limit = _limitForSegment(segmentIndex);

      if (requiredUnits > limit) {
        segmentIndex += 1;
        direction = _directionForSegment(state.side, segmentIndex);
      }
    }

    return _PhoneBranchState(
      side: state.side,
      connectionUnits: connection,
      segmentIndex: segmentIndex,
      usedUnits: usedUnits,
      previousDirection: direction,
      previousWasDouble: state.previousWasDouble,
    );
  }

  (Offset, Offset) _stepUnits({
    required Offset connectionUnits,
    required Domino domino,
    required _PhoneDirection direction,
  }) {
    final vector = _vector(direction);
    final isDouble = domino.left == domino.right;

    if (isDouble) {
      final center = connectionUnits + vector;
      return (center, center);
    }

    final connectingSquareCenter = connectionUnits + vector;
    final center = connectingSquareCenter + vector * 0.5;
    final nextConnection = center + vector * 0.5;
    return (center, nextConnection);
  }

  _PhoneBranchBuildResult _buildBranch(String side) {
    var state = _initialState(side);
    final placements = <_PlacedPhoneDomino>[];

    final branch = dominoes
        .where((item) => item.side == side)
        .toList(growable: false)
      ..sort(
        (a, b) => (a.moveNumber ?? 0).compareTo(b.moveNumber ?? 0),
      );

    for (final serverDomino in branch) {
      final domino = serverDomino.domino;
      final prepared = _prepareForDomino(state, domino);
      final direction = _directionForSegment(
        prepared.side,
        prepared.segmentIndex,
      );
      final geometry = _stepUnits(
        connectionUnits: prepared.connectionUnits,
        domino: domino,
        direction: direction,
      );

      placements.add(
        _PlacedPhoneDomino(
          domino: serverDomino,
          centerUnits: geometry.$1,
          direction: direction,
        ),
      );

      state = _PhoneBranchState(
        side: side,
        connectionUnits: geometry.$2,
        segmentIndex: prepared.segmentIndex,
        usedUnits: prepared.usedUnits + _pathUnits(domino),
        previousDirection: direction,
        previousWasDouble: serverDomino.isDouble,
      );
    }

    return _PhoneBranchBuildResult(
      placements: placements,
      state: state,
    );
  }

  Size _displaySizeUnits({
    required Domino domino,
    required _PhoneDirection direction,
  }) {
    final pathHorizontal = _horizontal(direction);
    final dominoHorizontal = domino.left == domino.right
        ? !pathHorizontal
        : pathHorizontal;
    return Size(
      dominoHorizontal ? 2 : 1,
      dominoHorizontal ? 1 : 2,
    );
  }

  Domino _displayDomino(Domino domino, _PhoneDirection direction) {
    if (direction == _PhoneDirection.top ||
        direction == _PhoneDirection.left) {
      return Domino(left: domino.right, right: domino.left);
    }
    return domino;
  }

  Rect _rectForPlacement(_PlacedPhoneDomino placement) {
    final isOpening = placement.domino.side == 'center' ||
        placement.domino.moveNumber == 1;
    final size = isOpening
        ? const Size(1, 2)
        : _displaySizeUnits(
            domino: placement.domino.domino,
            direction: placement.direction,
          );
    return Rect.fromCenter(
      center: placement.centerUnits,
      width: size.width,
      height: size.height,
    );
  }

  ({Offset centerUnits, Size sizeUnits, _PhoneDirection direction})
      _targetGeometryUnits({
    required _PhoneBranchState state,
    required Domino domino,
  }) {
    final prepared = _prepareForDomino(state, domino);
    final direction = _directionForSegment(
      prepared.side,
      prepared.segmentIndex,
    );
    final geometry = _stepUnits(
      connectionUnits: prepared.connectionUnits,
      domino: domino,
      direction: direction,
    );
    return (
      centerUnits: geometry.$1,
      sizeUnits: _displaySizeUnits(domino: domino, direction: direction),
      direction: direction,
    );
  }

  _PhoneLayoutDraft _buildDraft() {
    final opening = _openingDomino;
    final placements = <_PlacedPhoneDomino>[
      _PlacedPhoneDomino(
        domino: opening,
        centerUnits: Offset.zero,
        direction: _PhoneDirection.bottom,
      ),
    ];
    final branchStates = <String, _PhoneBranchState>{};

    for (final side in const ['top', 'right', 'bottom', 'left']) {
      final result = _buildBranch(side);
      placements.addAll(result.placements);
      branchStates[side] = result.state;
    }

    var minX = -0.5;
    var maxX = 0.5;
    var minY = -1.0;
    var maxY = 1.0;

    void include(Rect rect) {
      minX = math.min(minX, rect.left);
      maxX = math.max(maxX, rect.right);
      minY = math.min(minY, rect.top);
      maxY = math.max(maxY, rect.bottom);
    }

    for (final placement in placements) {
      include(_rectForPlacement(placement));
    }

    if (selectedDomino != null) {
      for (final side in const ['top', 'right', 'bottom', 'left']) {
        if (!playableSides.contains(side)) continue;
        final target = _targetGeometryUnits(
          state: branchStates[side]!,
          domino: selectedDomino!.domino,
        );
        include(
          Rect.fromCenter(
            center: target.centerUnits,
            width: target.sizeUnits.width,
            height: target.sizeUnits.height,
          ),
        );
      }
    }

    return _PhoneLayoutDraft(
      placements: placements,
      branchStates: branchStates,
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
    );
  }

  double _shortSideFor(Size boardSize, _PhoneLayoutDraft draft) {
    final availableWidth = math.max(1.0, boardSize.width - _safeMargin * 2);
    final availableHeight = math.max(1.0, boardSize.height - _safeMargin * 2);

    final halfWidthUnits = math.max(
      1.0,
      math.max(draft.minX.abs(), draft.maxX.abs()),
    );
    final halfHeightUnits = math.max(
      1.0,
      math.max(draft.minY.abs(), draft.maxY.abs()),
    );

    final byWidth = availableWidth / (halfWidthUnits * 2);
    final byHeight = availableHeight / (halfHeightUnits * 2);

    return math.max(
      10.0,
      math.min(_preferredShortSide, math.min(byWidth, byHeight)),
    );
  }

  double _dotSize(double shortSide) => math.max(2.5, shortSide * 0.16);

  Widget _buildPlacedDomino(
    _PlacedPhoneDomino placement, {
    required double shortSide,
    required Offset boardCenter,
  }) {
    final isOpening = placement.domino.side == 'center' ||
        placement.domino.moveNumber == 1;
    final sizeUnits = isOpening
        ? const Size(1, 2)
        : _displaySizeUnits(
            domino: placement.domino.domino,
            direction: placement.direction,
          );
    final size = Size(
      sizeUnits.width * shortSide,
      sizeUnits.height * shortSide,
    );
    final center = boardCenter + placement.centerUnits * shortSide;
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
      key: ValueKey(
        'phone-${placement.domino.id}-${placement.domino.moveNumber}',
      ),
      left: center.dx - size.width / 2,
      top: center.dy - size.height / 2,
      child: child,
    );
  }

  Widget _buildTarget({
    required _PhoneBranchState state,
    required Domino domino,
    required double shortSide,
    required Offset boardCenter,
    required VoidCallback onTap,
  }) {
    final target = _targetGeometryUnits(state: state, domino: domino);
    final center = boardCenter + target.centerUnits * shortSide;
    final size = Size(
      target.sizeUnits.width * shortSide,
      target.sizeUnits.height * shortSide,
    );

    return Positioned(
      left: center.dx - size.width / 2,
      top: center.dy - size.height / 2,
      child: DominoPlacementTarget(
        width: size.width,
        height: size.height,
        onTap: onTap,
      ),
    );
  }
}
