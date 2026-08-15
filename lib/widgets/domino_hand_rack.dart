import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DominoHandRack extends StatelessWidget {
  final Widget child;

  const DominoHandRack({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.rackWoodLight,
            AppColors.rackWood,
            AppColors.rackWoodDark,
          ],
          stops: [0, 0.48, 1],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.ink,
          width: 2.6,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            blurRadius: 0,
            offset: Offset(3, 4),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 11,
            right: 11,
            top: 6,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.brassLight.withValues(alpha: 0.46),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 9, 7, 16),
            child: child,
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 4,
            child: Container(
              height: 13,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFC97B43),
                    AppColors.rackWood,
                    AppColors.rackWoodDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.ink,
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.ink,
                    blurRadius: 0,
                    offset: Offset(0, 2),
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
