import 'package:flutter/material.dart';

import '../localization/game_action_strings.dart';
import '../theme/app_colors.dart';

class GameHeaderActions extends StatelessWidget {
  final bool surrenderEnabled;
  final bool exitEnabled;
  final VoidCallback onSurrender;
  final VoidCallback onExit;

  const GameHeaderActions({
    super.key,
    required this.surrenderEnabled,
    required this.exitEnabled,
    required this.onSurrender,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final strings = GameActionStrings.of(context);

    return SizedBox(
      width: 94,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _CartoonHeaderButton(
            tooltip: strings.surrender,
            icon: Icons.outlined_flag_rounded,
            iconColor: AppColors.cream,
            borderColor: AppColors.brass.withValues(alpha: 0.72),
            enabled: surrenderEnabled,
            onTap: onSurrender,
          ),
          const SizedBox(width: 7),
          _CartoonHeaderButton(
            tooltip: strings.exitGame,
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFFFF5B5B),
            borderColor: const Color(0xFFFF5B5B),
            enabled: exitEnabled,
            onTap: onExit,
          ),
        ],
      ),
    );
  }
}

class _CartoonHeaderButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final bool enabled;
  final VoidCallback onTap;

  const _CartoonHeaderButton({
    required this.tooltip,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = enabled ? iconColor : Colors.white24;
    final effectiveBorderColor = enabled
        ? borderColor
        : Colors.white.withValues(alpha: 0.10);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1D3042),
                  Color(0xFF0A1622),
                ],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: effectiveBorderColor,
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 7,
                  right: 7,
                  top: 4,
                  child: Container(
                    height: 1.5,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    icon,
                    color: effectiveIconColor,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<bool> showGameActionConfirmDialog(
  BuildContext context, {
  required bool surrender,
}) async {
  final strings = GameActionStrings.of(context);
  final accent = surrender ? AppColors.cream : const Color(0xFFFF5B5B);
  final icon = surrender ? Icons.outlined_flag_rounded : Icons.logout_rounded;
  final title = surrender ? strings.surrenderTitle : strings.exitTitle;
  final description =
      surrender ? strings.surrenderDescription : strings.exitDescription;
  final confirmText = surrender ? strings.surrender : strings.exitConfirm;

  final result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.72),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 390),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.panelTop,
                AppColors.panelBottom,
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.brass.withValues(alpha: 0.72),
              width: 1.7,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF263E52),
                      Color(0xFF0C1824),
                    ],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.88),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(height: 13),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(dialogContext).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          strings.keepPlaying,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: FilledButton(
                        onPressed: () => Navigator.of(dialogContext).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: surrender
                              ? AppColors.cream
                              : const Color(0xFFFF5B5B),
                          foregroundColor: surrender
                              ? AppColors.ink
                              : Colors.white,
                          elevation: 6,
                          shadowColor: Colors.black54,
                          side: BorderSide(
                            color: surrender
                                ? AppColors.brass
                                : const Color(0xFF7D2020),
                            width: 1.6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          confirmText,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  return result == true;
}
