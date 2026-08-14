import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GameTableDecorations extends StatelessWidget {
  final String label;

  const GameTableDecorations({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(23),
                  border: Border.all(
                    color: AppColors.brassLight.withValues(alpha: 0.22),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ),
          const Positioned(left: 13, top: 13, child: _BrassFastener()),
          const Positioned(right: 13, top: 13, child: _BrassFastener()),
          const Positioned(left: 13, bottom: 13, child: _BrassFastener()),
          const Positioned(right: 13, bottom: 13, child: _BrassFastener()),
          Center(
            child: Opacity(
              opacity: 0.065,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _DominoWatermark(),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BrassFastener extends StatelessWidget {
  const _BrassFastener();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 15,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.35),
          radius: 0.95,
          colors: [
            AppColors.brassLight,
            AppColors.brass,
            AppColors.brassDark,
          ],
        ),
        border: Border.all(
          color: AppColors.ink.withValues(alpha: 0.82),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 3,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Transform.rotate(
          angle: -0.55,
          child: Container(
            width: 7,
            height: 1.3,
            decoration: BoxDecoration(
              color: AppColors.brassDark,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ),
      ),
    );
  }
}

class _DominoWatermark extends StatelessWidget {
  const _DominoWatermark();

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.08,
      child: Container(
        width: 34,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: AppColors.cream,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: const [
                  _WatermarkPip(alignment: Alignment.topLeft),
                  _WatermarkPip(alignment: Alignment.bottomRight),
                ],
              ),
            ),
            Container(height: 2, color: AppColors.cream),
            Expanded(
              child: Stack(
                children: const [
                  _WatermarkPip(alignment: Alignment.topLeft),
                  _WatermarkPip(alignment: Alignment.topRight),
                  _WatermarkPip(alignment: Alignment.bottomLeft),
                  _WatermarkPip(alignment: Alignment.bottomRight),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatermarkPip extends StatelessWidget {
  final Alignment alignment;

  const _WatermarkPip({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: AppColors.cream,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
