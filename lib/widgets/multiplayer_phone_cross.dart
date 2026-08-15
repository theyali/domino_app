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
  final Offset connectionUnits;
  final _PhoneDirection baseDirection;
  final _PhoneDirection driftDirection;
  final _PhoneDirection direction;
  final _PhoneDirection previousDirection;
  final bool onDrift;
  final bool axisForward;
  final bool previousWasDouble;
  final bool hasTurned;
  final double usedUnits;

  const _PhoneBranchState({
    required this.connectionUnits,
    required this.baseDirection,
    required this.driftDirection,
    required this.direction,
    required this.previousDirection,
    required this.onDrift,
    required this.axisForward,
    required this.previousWasDouble,
    required this.hasTurned,
    required this.usedUnits,
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

  double get widthUnits => maxX - minX;
  double get heightUnits => maxY - minY;
}

/// Визуальная змейка режима «Телефон».
///
/// Сервер продолжает хранить четыре независимых логических конца
/// (`top/right/bottom/left`). Здесь меняется только отображение: каждая ветка
/// выходит из центрального дубля, а затем укладывается змейкой в своём секторе.
/// Логика ходов и подсчёта очков остаётся серверной.
class MultiplayerPhoneCross extends StatelessWidget {
  static const double _safeMargin = 14;
  static const double _preferredShortSide = 29;

  // Первый луч уходит достаточно далеко от центра, чтобы четыре ветки не
  // пересекались. После первого поворота змейка ходит туда-обратно короче,
  // сохраняя свободный крест вокруг центрального дубля.
  static const double _initialAxisRunUnits = 8;
  static const double _returnAxisRunUnits = 4;
  static const double _driftRunUnits = 3;

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
        final shift = _shiftFor(boardSize, draft, shortSide);

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
                  shift: shift,
                ),
              if (selectedDomino != null && onTargetTap != null)
                for (final side in const ['top', 'right', 'bottom', 'left'])
                  if (playableSides.contains(side))
                    _buildTarget(
                      state: draft.branchStates[side]!,
                      domino: selectedDomino!.domino,
                      shortSide: shortSide,
                      shift: shift,
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

  _PhoneDirection _directionFor(String side) => switch (side) {
        'top' => _PhoneDirection.top,
        'right' => _PhoneDirection.right,
        'bottom' => _PhoneDirection.bottom,
        _ => _PhoneDirection.left,
      };

  _PhoneDirection _driftDirectionFor(String side) => switch (side) {
        // Каждая ветка получает свой сектор:
        // top -> верх-право, right -> низ-право,
        // bottom -> низ-лево, left -> верх-лево.
        'top' => _PhoneDirection.right,
        'right' => _PhoneDirection.bottom,
        'bottom' => _PhoneDirection.left,
        _ => _PhoneDirection.top,
      };

  _PhoneDirection _opposite(_PhoneDirection direction) => switch (direction) {
        _PhoneDirection.top => _PhoneDirection.bottom,
        _PhoneDirection.right => _PhoneDirection.left,
        _PhoneDirection.bottom => _PhoneDirection.top,
        _PhoneDirection.left => _PhoneDirection.right,
      };

  Offset _vector(_PhoneDirection direction) => switch (direction) {
        _PhoneDirection.top => const Offset(0, -1),
        _PhoneDirection.right => const Offset(1, 0),
        _PhoneDirection.bottom => const Offset(0, 1),
        _PhoneDirection.left => const Offset(-1, 0),
      };

  bool _horizontal(_PhoneDirection direction) =>
      direction == _PhoneDirection.left || direction == _PhoneDirection.right;

  double _pathUnits(Domino domino) => domino.left == domino.right ? 1 : 2;

  Offset _openingConnectionUnits(_PhoneDirection direction) {
    // connectionUnits — это центр последнего соединительного квадрата, а не
    // физический край кости. Такая модель позволяет делать поворот без
    // наложения одной костяшки на другую.
    return switch (direction) {
      _PhoneDirection.top => const Offset(0, -0.5),
      _PhoneDirection.bottom => const Offset(0, 0.5),
      _PhoneDirection.left => Offset.zero,
      _PhoneDirection.right => Offset.zero,
    };
  }

  _PhoneBranchState _initialBranchState(String side) {
    final baseDirection = _directionFor(side);
    return _PhoneBranchState(
      connectionUnits: _openingConnectionUnits(baseDirection),
      baseDirection: baseDirection,
      driftDirection: _driftDirectionFor(side),
      direction: baseDirection,
      previousDirection: baseDirection,
      onDrift: false,
      axisForward: true,
      previousWasDouble: false,
      hasTurned: false,
      usedUnits: 0,
    );
  }

  _PhoneBranchState _prepareForDomino(
    _PhoneBranchState state,
    Domino domino,
  ) {
    final requiredUnits = _pathUnits(domino);
    var connectionUnits = state.connectionUnits;
    var direction = state.direction;
    var onDrift = state.onDrift;
    var axisForward = state.axisForward;
    var hasTurned = state.hasTurned;
    var usedUnits = state.usedUnits;

    final currentLimit = onDrift
        ? _driftRunUnits
        : hasTurned
            ? _returnAxisRunUnits
            : _initialAxisRunUnits;

    if (usedUnits + requiredUnits > currentLimit) {
      if (onDrift) {
        onDrift = false;
        axisForward = !axisForward;
        direction = axisForward
            ? state.baseDirection
            : _opposite(state.baseDirection);
      } else {
        onDrift = true;
        direction = state.driftDirection;
        hasTurned = true;
      }
      usedUnits = 0;

      // После дубля connectionUnits находится в центре дубля. При повороте
      // сдвигаем точку соединения к нужной половине его длинной стороны,
      // чтобы следующая костяшка только касалась дубля, а не перекрывала его.
      if (state.previousWasDouble && direction != state.previousDirection) {
        connectionUnits += _vector(direction) * 0.5;
      }
    }

    return _PhoneBranchState(
      connectionUnits: connectionUnits,
      baseDirection: state.baseDirection,
      driftDirection: state.driftDirection,
      direction: direction,
      previousDirection: state.previousDirection,
      onDrift: onDrift,
      axisForward: axisForward,
      previousWasDouble: state.previousWasDouble,
      hasTurned: hasTurned,
      usedUnits: usedUnits,
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

    // Сначала находим центр половинки, которая касается предыдущей кости.
    // Вторая половинка продолжает путь ещё на один квадрат.
    final connectingSquareCenter = connectionUnits + vector;
    final center = connectingSquareCenter + vector * 0.5;
    final nextConnection = center + vector * 0.5;
    return (center, nextConnection);
  }

  _PhoneBranchBuildResult _buildBranch(String side) {
    var state = _initialBranchState(side);
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
      final geometry = _stepUnits(
        connectionUnits: prepared.connectionUnits,
        domino: domino,
        direction: prepared.direction,
      );
      final requiredUnits = _pathUnits(domino);

      placements.add(
        _PlacedPhoneDomino(
          domino: serverDomino,
          centerUnits: geometry.$1,
          direction: prepared.direction,
        ),
      );

      state = _PhoneBranchState(
        connectionUnits: geometry.$2,
        baseDirection: prepared.baseDirection,
        driftDirection: prepared.driftDirection,
        direction: prepared.direction,
        previousDirection: prepared.direction,
        onDrift: prepared.onDrift,
        axisForward: prepared.axisForward,
        previousWasDouble: serverDomino.isDouble,
        hasTurned: prepared.hasTurned,
        usedUnits: prepared.usedUnits + requiredUnits,
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

  Domino _displayDomino(
    Domino domino,
    _PhoneDirection direction,
  ) {
    // Сервер хранит left = значение возле предыдущей кости, right = новый
    // открытый конец. На экранных направлениях вверх/влево переворачиваем.
    if (direction == _PhoneDirection.top || direction == _PhoneDirection.left) {
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

  ({Offset centerUnits, Size sizeUnits}) _targetGeometryUnits({
    required _PhoneBranchState state,
    required Domino domino,
  }) {
    final prepared = _prepareForDomino(state, domino);
    final geometry = _stepUnits(
      connectionUnits: prepared.connectionUnits,
      domino: domino,
      direction: prepared.direction,
    );
    return (
      centerUnits: geometry.$1,
      sizeUnits: _displaySizeUnits(
        domino: domino,
        direction: prepared.direction,
      ),
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

    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;

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
    final byWidth = availableWidth / math.max(1.0, draft.widthUnits);
    final byHeight = availableHeight / math.max(1.0, draft.heightUnits);
    return math.max(
      10.0,
      math.min(_preferredShortSide, math.min(byWidth, byHeight)),
    );
  }

  Offset _shiftFor(
    Size boardSize,
    _PhoneLayoutDraft draft,
    double shortSide,
  ) {
    final contentCenterUnits = Offset(
      (draft.minX + draft.maxX) / 2,
      (draft.minY + draft.maxY) / 2,
    );
    return Offset(boardSize.width / 2, boardSize.height / 2) -
        contentCenterUnits * shortSide;
  }

  double _dotSize(double shortSide) => math.max(2.5, shortSide * 0.16);

  Widget _buildPlacedDomino(
    _PlacedPhoneDomino placement, {
    required double shortSide,
    required Offset shift,
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
    final center = shift + placement.centerUnits * shortSide;
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
    required Offset shift,
    required VoidCallback onTap,
  }) {
    final target = _targetGeometryUnits(
      state: state,
      domino: domino,
    );
    final center = shift + target.centerUnits * shortSide;
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
