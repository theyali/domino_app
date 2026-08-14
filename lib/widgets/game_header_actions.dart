import 'package:flutter/material.dart';

import '../localization/game_action_strings.dart';
import '../theme/app_colors.dart';

const _surrenderIconAsset = 'assets/icons/white-flag.png';
const _exitIconAsset = 'assets/icons/remove.png';

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
      width: 88,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _HeaderAssetButton(
            tooltip: strings.surrender,
            assetPath: _surrenderIconAsset,
            enabled: surrenderEnabled,
            onTap: onSurrender,
          ),
          const SizedBox(width: 8),
          _HeaderAssetButton(
            tooltip: strings.exitGame,
            assetPath: _exitIconAsset,
            enabled: exitEnabled,
            onTap: onExit,
          ),
        ],
      ),
    );
  }
}

class _HeaderAssetButton extends StatelessWidget {
  final String tooltip;
  final String assetPath;
  final bool enabled;
  final VoidCallback onTap;

  const _HeaderAssetButton({
    required this.tooltip,
    required this.assetPath,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 38,
            height: 42,
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: enabled ? 1 : 0.28,
                child: Image.asset(
                  assetPath,
                  width: 30,
                  height: 30,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
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
  final title = surrender ? strings.surrenderTitle : strings.exitTitle;
  final description =
      surrender ? strings.surrenderDescription : strings.exitDescription;
  final confirmText = surrender ? strings.surrender : strings.exitConfirm;
  final iconAsset = surrender ? _surrenderIconAsset : _exitIconAsset;

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
              Image.asset(
                iconAsset,
                width: 48,
                height: 48,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
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
