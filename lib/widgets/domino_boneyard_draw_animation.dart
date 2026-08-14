import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/domino.dart';
import 'domino_tile.dart';

class DominoBoneyardDrawAnimation extends StatefulWidget {
  final Domino domino;
  final Offset sourceGlobalCenter;
  final Offset targetGlobalCenter;
  final bool soundEnabled;
  final VoidCallback onCompleted;

  const DominoBoneyardDrawAnimation({
    super.key,
    required this.domino,
    required this.sourceGlobalCenter,
    required this.targetGlobalCenter,
    required this.soundEnabled,
    required this.onCompleted,
  });

  @override
  State<DominoBoneyardDrawAnimation> createState() =>
      _DominoBoneyardDrawAnimationState();
}

class _DominoBoneyardDrawAnimationState
    extends State<DominoBoneyardDrawAnimation>
    with SingleTickerProviderStateMixin {
  static const String _pickSound = 'sounds/boneyard_pick.wav';
  static const String _landingSound = 'sounds/boneyard_land.wav';

  late final AnimationController _controller;
  late final AudioPlayer _audioPlayer;

  Offset _sourceLocal = Offset.zero;
  Offset _targetLocal = Offset.zero;

  bool _isReady = false;
  bool _landingTriggered = false;

  @override
  void initState() {
    super.initState();

    _audioPlayer = AudioPlayer();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )
      ..addListener(_handleAnimationTick)
      ..addStatusListener(_handleAnimationStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareAnimation();
    });
  }

  void _prepareAnimation() {
    if (!mounted) {
      return;
    }

    final renderObject = context.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _prepareAnimation();
      });
      return;
    }

    setState(() {
      _sourceLocal = renderObject.globalToLocal(
        widget.sourceGlobalCenter,
      );
      _targetLocal = renderObject.globalToLocal(
        widget.targetGlobalCenter,
      );
      _isReady = true;
    });

    if (widget.soundEnabled) {
      unawaited(
        _audioPlayer.play(
          AssetSource(_pickSound),
          volume: 0.58,
          mode: PlayerMode.lowLatency,
        ),
      );
    }

    _controller.forward(from: 0);
  }

  void _handleAnimationTick() {
    if (!_landingTriggered && _controller.value >= 0.82) {
      _landingTriggered = true;

      HapticFeedback.selectionClick();

      if (widget.soundEnabled) {
        unawaited(
          _audioPlayer.play(
            AssetSource(_landingSound),
            volume: 0.72,
            mode: PlayerMode.lowLatency,
          ),
        );
      }
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onCompleted();
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleAnimationTick)
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();

    unawaited(_audioPlayer.dispose());

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const SizedBox.expand();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final raw = _controller.value;
        final flight = Curves.easeInOutCubic.transform(raw);

        final basePosition = Offset.lerp(
          _sourceLocal,
          _targetLocal,
          flight,
        )!;

        final arcHeight = 72 * math.sin(math.pi * flight);
        final sideDrift = 10 * math.sin(math.pi * flight * 2);

        final center = Offset(
          basePosition.dx + sideDrift,
          basePosition.dy - arcHeight,
        );

        final scale = raw < 0.78
            ? 0.58 + 0.50 * Curves.easeOutCubic.transform(raw / 0.78)
            : 1.08 - 0.08 * Curves.easeOut.transform(
                (raw - 0.78) / 0.22,
              );

        final rotation = (1 - flight) * -0.16 +
            math.sin(math.pi * flight) * 0.11;

        final flipProgress = ((raw - 0.24) / 0.46)
            .clamp(0.0, 1.0)
            .toDouble();

        final flipAngle = math.pi * (1 - flipProgress);
        final showingBack = flipAngle > math.pi / 2;
        final visualFlipAngle = showingBack
            ? flipAngle - math.pi
            : flipAngle;

        final opacity = raw < 0.08
            ? raw / 0.08
            : raw > 0.94
                ? (1 - raw) / 0.06
                : 1.0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: center.dx - 26,
              top: center.dy - 44,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0).toDouble(),
                child: Transform.rotate(
                  angle: rotation,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(visualFlipAngle)
                      ..scale(scale),
                    child: showingBack
                        ? const _FlyingDominoBack()
                        : DominoTile(
                            domino: widget.domino,
                            width: 52,
                            height: 88,
                            dotSize: 7,
                          ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _FlyingDominoBack extends StatelessWidget {
  const _FlyingDominoBack();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 88,
      decoration: BoxDecoration(
        color: const Color(0xFF66717D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white70,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 8,
            offset: Offset(2, 5),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF33404D),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white24,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
