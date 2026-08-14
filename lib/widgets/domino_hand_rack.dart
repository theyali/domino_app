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
          stops: [0, 0.42, 1],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.brass.withValues(alpha: 0.48),
          width: 1.3,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 10,
            right: 10,
            top: 5,
            child: Container(
              height: 2,
              decoration: BoxDecoration(
                color: AppColors.brassLight.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(7, 8, 7, 15),
            child: child,
          ),
          Positioned(
            left: 8,
            right: 8,
            bottom: 4,
            child: Container(
              height: 12,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF9B6840),
                    AppColors.rackWood,
                    AppColors.rackWoodDark,
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.brassDark.withValues(alpha: 0.75),
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 4,
                    offset: Offset(0, -1),
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
