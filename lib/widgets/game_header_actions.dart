import 'package:flutter/material.dart';

import '../localization/game_action_strings.dart';
import '../services/sound_effects_service.dart';

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
      width: 94,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _HeaderAssetButton(
            tooltip: strings.surrender,
            assetPath: _surrenderIconAsset,
            enabled: surrenderEnabled,
            onTap: onSurrender,
            backgroundColor: _GameActionPalette.yellow,
          ),
          const SizedBox(width: 8),
          _HeaderAssetButton(
            tooltip: strings.exitGame,
            assetPath: _exitIconAsset,
            enabled: exitEnabled,
            onTap: onExit,
            backgroundColor: _GameActionPalette.coral,
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
  final Color backgroundColor;

  const _HeaderAssetButton({
    required this.tooltip,
    required this.assetPath,
    required this.enabled,
    required this.onTap,
    required this.backgroundColor,
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
          onTap: enabled
              ? () {
                  SoundEffectsService.button();
                  onTap();
                }
              : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 160),
            opacity: enabled ? 1 : 0.35,
            child: Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: _GameActionPalette.ink,
                  width: 2.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: _GameActionPalette.ink,
                    blurRadius: 0,
                    offset: Offset(2, 3),
                  ),
                ],
              ),
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
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
    barrierColor: Colors.black.withValues(alpha: 0.68),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 390),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          decoration: BoxDecoration(
            color: _GameActionPalette.cream,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _GameActionPalette.ink,
              width: 3,
            ),
            boxShadow: const [
              BoxShadow(
                color: _GameActionPalette.ink,
                blurRadius: 0,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: surrender ? -0.07 : 0.06,
                child: Container(
                  width: 74,
                  height: 74,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: surrender
                        ? _GameActionPalette.yellow
                        : _GameActionPalette.coral,
                    borderRadius: BorderRadius.circular(21),
                    border: Border.all(
                      color: _GameActionPalette.ink,
                      width: 3,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: _GameActionPalette.ink,
                        blurRadius: 0,
                        offset: Offset(4, 5),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    iconAsset,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _GameActionPalette.ink,
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _GameActionPalette.inkSoft,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _CartoonDialogButton(
                      label: strings.keepPlaying,
                      color: _GameActionPalette.lime,
                      alternateSound: true,
                      onTap: () => Navigator.of(dialogContext).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CartoonDialogButton(
                      label: confirmText,
                      color: _GameActionPalette.coral,
                      quitSound: true,
                      onTap: () => Navigator.of(dialogContext).pop(true),
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

class _CartoonDialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool alternateSound;
  final bool quitSound;

  const _CartoonDialogButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.alternateSound = false,
    this.quitSound = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (quitSound) {
          SoundEffectsService.quitGame();
        } else {
          SoundEffectsService.button(alternate: alternateSound);
        }
        onTap();
      },
      child: Container(
        height: 54,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _GameActionPalette.ink,
            width: 2.7,
          ),
          boxShadow: const [
            BoxShadow(
              color: _GameActionPalette.ink,
              blurRadius: 0,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _GameActionPalette.ink,
            fontSize: 15,
            height: 1.05,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _GameActionPalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF574C42);
  static const Color cream = Color(0xFFFFE8B6);
  static const Color lime = Color(0xFF7CFC00);
  static const Color yellow = Color(0xFFFFD65C);
  static const Color coral = Color(0xFFFF7A70);
}
