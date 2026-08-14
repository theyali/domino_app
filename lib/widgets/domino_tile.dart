import 'package:flutter/material.dart';

import '../models/domino.dart';

class DominoTile extends StatelessWidget {
  final Domino domino;
  final VoidCallback? onTap;

  final double width;
  final double height;
  final double dotSize;
  final bool horizontal;

  const DominoTile({
    super.key,
    required this.domino,
    this.onTap,
    this.width = 52,
    this.height = 88,
    this.dotSize = 7,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact =
        width < 45 || height < 45;

    final halfPadding =
        isCompact ? 3.0 : 6.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            isCompact ? 6 : 8,
          ),
          border: Border.all(
            color: Colors.black,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(1, 2),
            ),
          ],
        ),
        child: horizontal
            ? _buildHorizontal(
                halfPadding,
              )
            : _buildVertical(
                halfPadding,
              ),
      ),
    );
  }

  Widget _buildVertical(
    double halfPadding,
  ) {
    return Column(
      children: [
        Expanded(
          child: DominoHalf(
            value: domino.left,
            dotSize: dotSize,
            padding: halfPadding,
            horizontalTile: false,
          ),
        ),
        Container(
          height: 2,
          color: Colors.black,
        ),
        Expanded(
          child: DominoHalf(
            value: domino.right,
            dotSize: dotSize,
            padding: halfPadding,
            horizontalTile: false,
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontal(
    double halfPadding,
  ) {
    return Row(
      children: [
        Expanded(
          child: DominoHalf(
            value: domino.left,
            dotSize: dotSize,
            padding: halfPadding,
            horizontalTile: true,
          ),
        ),
        Container(
          width: 2,
          color: Colors.black,
        ),
        Expanded(
          child: DominoHalf(
            value: domino.right,
            dotSize: dotSize,
            padding: halfPadding,
            horizontalTile: true,
          ),
        ),
      ],
    );
  }
}

class DominoHalf extends StatelessWidget {
  final int value;
  final double dotSize;
  final double padding;

  /// Ориентация всей костяшки.
  /// Нужна, чтобы шестёрка визуально поворачивалась вместе с домино.
  final bool horizontalTile;

  const DominoHalf({
    super.key,
    required this.value,
    required this.dotSize,
    required this.padding,
    required this.horizontalTile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(
        padding,
      ),
      child: Stack(
        children: _buildDots(),
      ),
    );
  }

  Widget _dot(
    Alignment alignment,
  ) {
    return Align(
      alignment: alignment,
      child: DominoDot(
        size: dotSize,
      ),
    );
  }

  List<Widget> _buildDots() {
    switch (value) {
      case 0:
        return [];

      case 1:
        return [
          _dot(
            Alignment.center,
          ),
        ];

      case 2:
        return [
          _dot(
            Alignment.topLeft,
          ),
          _dot(
            Alignment.bottomRight,
          ),
        ];

      case 3:
        return [
          _dot(
            Alignment.topLeft,
          ),
          _dot(
            Alignment.center,
          ),
          _dot(
            Alignment.bottomRight,
          ),
        ];

      case 4:
        return [
          _dot(
            Alignment.topLeft,
          ),
          _dot(
            Alignment.topRight,
          ),
          _dot(
            Alignment.bottomLeft,
          ),
          _dot(
            Alignment.bottomRight,
          ),
        ];

      case 5:
        return [
          _dot(
            Alignment.topLeft,
          ),
          _dot(
            Alignment.topRight,
          ),
          _dot(
            Alignment.center,
          ),
          _dot(
            Alignment.bottomLeft,
          ),
          _dot(
            Alignment.bottomRight,
          ),
        ];

      case 6:
        if (horizontalTile) {
          // Горизонтальная костяшка: 2 ряда по 3 точки.
          // ● ● ●
          // ● ● ●
          return [
            _dot(
              Alignment.topLeft,
            ),
            _dot(
              Alignment.topCenter,
            ),
            _dot(
              Alignment.topRight,
            ),
            _dot(
              Alignment.bottomLeft,
            ),
            _dot(
              Alignment.bottomCenter,
            ),
            _dot(
              Alignment.bottomRight,
            ),
          ];
        }

        // Вертикальная костяшка / дубль: 3 ряда по 2 точки.
        // ●   ●
        // ●   ●
        // ●   ●
        return [
          _dot(
            Alignment.topLeft,
          ),
          _dot(
            Alignment.topRight,
          ),
          _dot(
            Alignment.centerLeft,
          ),
          _dot(
            Alignment.centerRight,
          ),
          _dot(
            Alignment.bottomLeft,
          ),
          _dot(
            Alignment.bottomRight,
          ),
        ];

      default:
        throw ArgumentError(
          'Domino value must be between 0 and 6',
        );
    }
  }
}

class DominoDot extends StatelessWidget {
  final double size;

  const DominoDot({
    super.key,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
    );
  }
}
