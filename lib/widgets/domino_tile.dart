import 'package:flutter/material.dart';

import '../models/domino.dart';
import '../theme/app_colors.dart';

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
    final isCompact = width < 45 || height < 45;
    final halfPadding = isCompact ? 3.0 : 6.0;
    final radius = isCompact ? 6.5 : 9.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFFFFF),
              AppColors.cream,
              Color(0xFFEDE4D1),
            ],
          ),
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: AppColors.ink,
            width: isCompact ? 2 : 2.3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.34),
              blurRadius: isCompact ? 4 : 7,
              offset: const Offset(1, 3),
            ),
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.38),
              blurRadius: 2,
              offset: const Offset(-1, -1),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - 2),
          child: horizontal
              ? _buildHorizontal(halfPadding)
              : _buildVertical(halfPadding),
        ),
      ),
    );
  }

  Widget _buildVertical(double halfPadding) {
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
          color: AppColors.ink,
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

  Widget _buildHorizontal(double halfPadding) {
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
          color: AppColors.ink,
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
      padding: EdgeInsets.all(padding),
      child: Stack(
        children: _buildDots(),
      ),
    );
  }

  Widget _dot(Alignment alignment) {
    return Align(
      alignment: alignment,
      child: DominoDot(size: dotSize),
    );
  }

  List<Widget> _buildDots() {
    switch (value) {
      case 0:
        return [];
      case 1:
        return [_dot(Alignment.center)];
      case 2:
        return [
          _dot(Alignment.topLeft),
          _dot(Alignment.bottomRight),
        ];
      case 3:
        return [
          _dot(Alignment.topLeft),
          _dot(Alignment.center),
          _dot(Alignment.bottomRight),
        ];
      case 4:
        return [
          _dot(Alignment.topLeft),
          _dot(Alignment.topRight),
          _dot(Alignment.bottomLeft),
          _dot(Alignment.bottomRight),
        ];
      case 5:
        return [
          _dot(Alignment.topLeft),
          _dot(Alignment.topRight),
          _dot(Alignment.center),
          _dot(Alignment.bottomLeft),
          _dot(Alignment.bottomRight),
        ];
      case 6:
        if (horizontalTile) {
          return [
            _dot(Alignment.topLeft),
            _dot(Alignment.topCenter),
            _dot(Alignment.topRight),
            _dot(Alignment.bottomLeft),
            _dot(Alignment.bottomCenter),
            _dot(Alignment.bottomRight),
          ];
        }

        return [
          _dot(Alignment.topLeft),
          _dot(Alignment.topRight),
          _dot(Alignment.centerLeft),
          _dot(Alignment.centerRight),
          _dot(Alignment.bottomLeft),
          _dot(Alignment.bottomRight),
        ];
      default:
        throw ArgumentError('Domino value must be between 0 and 6');
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
      decoration: BoxDecoration(
        color: AppColors.ink,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 1.5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
    );
  }
}
