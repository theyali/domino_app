import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class DominoPlayAnimation extends StatefulWidget {
  final Widget child;
  final Offset sourceGlobalCenter;
  final bool isDouble;
  final bool horizontal;
  final bool soundEnabled;
  final VoidCallback? onDoubleImpact;
  final VoidCallback? onCompleted;

  const DominoPlayAnimation({
    super.key,
    required this.child,
    required this.sourceGlobalCenter,
    required this.isDouble,
    required this.horizontal,
    required this.soundEnabled,
    this.onDoubleImpact,
    this.onCompleted,
  });

  @override
  State<DominoPlayAnimation> createState() => _DominoPlayAnimationState();
}

class _DominoPlayAnimationState extends State<DominoPlayAnimation>
    with SingleTickerProviderStateMixin {
  static const String _normalImpactSound = 'sounds/domino_land.wav';
  static const String _doubleImpactSound = 'sounds/domino_double_slam.wav';
  static const int _maxPrepareAttempts = 3;

  late final AnimationController _controller;
  late final AudioPlayer _audioPlayer;

  Offset _sourceOffset = Offset.zero;

  bool _isReady = false;
  bool _impactTriggered = false;
  bool _completionNotified = false;
  int _prepareAttempts = 0;

  @override
  void initState() {
    super.initState();

    _audioPlayer = AudioPlayer();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: widget.isDouble ? 900 : 650,
      ),
    )
      ..addListener(_handleAnimationTick)
      ..addStatusListener(_handleAnimationStatus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareAnimation();
    });
  }

  void _prepareAnimation() {
    if (!mounted || _completionNotified) {
      return;
    }

    final renderObject = context.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      if (_prepareAttempts < _maxPrepareAttempts) {
        _prepareAttempts++;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _prepareAnimation();
        });
      } else {
        _notifyCompleted();
      }
      return;
    }

    final targetGlobalCenter = renderObject.localToGlobal(
      renderObject.size.center(Offset.zero),
    );

    final globalOrigin = renderObject.localToGlobal(Offset.zero);
    final globalX = renderObject.localToGlobal(const Offset(1, 0));
    final globalY = renderObject.localToGlobal(const Offset(0, 1));

    final scaleX = (globalX - globalOrigin).distance;
    final scaleY = (globalY - globalOrigin).distance;

    final globalDelta = widget.sourceGlobalCenter - targetGlobalCenter;

    setState(() {
      _sourceOffset = Offset(
        scaleX == 0 ? globalDelta.dx : globalDelta.dx / scaleX,
        scaleY == 0 ? globalDelta.dy : globalDelta.dy / scaleY,
      );

      _isReady = true;
    });

    _controller.forward(from: 0);
  }

  void _handleAnimationTick() {
    final impactPoint = widget.isDouble ? 0.58 : 0.66;

    if (!_impactTriggered && _controller.value >= impactPoint) {
      _impactTriggered = true;
      _playImpactFeedback();
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _notifyCompleted();
    }
  }

  void _notifyCompleted() {
    if (_completionNotified) return;
    _completionNotified = true;
    widget.onCompleted?.call();
  }

  void _playImpactFeedback() {
    if (widget.isDouble) {
      HapticFeedback.heavyImpact();
      widget.onDoubleImpact?.call();

      if (widget.soundEnabled) {
        unawaited(
          _audioPlayer.play(
            AssetSource(_doubleImpactSound),
            volume: 1.0,
            mode: PlayerMode.lowLatency,
          ),
        );
      }
    } else {
      HapticFeedback.lightImpact();

      if (widget.soundEnabled) {
        unawaited(
          _audioPlayer.play(
            AssetSource(_normalImpactSound),
            volume: 0.72,
            mode: PlayerMode.lowLatency,
          ),
        );
      }
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

  double _flightProgress(double value) {
    final flightEnd = widget.isDouble ? 0.58 : 0.66;

    if (value >= flightEnd) {
      return 1;
    }

    return Curves.easeOutCubic.transform(value / flightEnd);
  }

  double _impactProgress(double value) {
    final impactStart = widget.isDouble ? 0.58 : 0.66;

    if (value <= impactStart) {
      return 0;
    }

    return ((value - impactStart) / (1 - impactStart))
        .clamp(0.0, 1.0)
        .toDouble();
  }

  double _waveProgress({
    required double impact,
    required double delay,
    required double duration,
  }) {
    if (impact <= delay) {
      return 0;
    }

    return ((impact - delay) / duration).clamp(0.0, 1.0).toDouble();
  }

  double _doubleImpactY(double progress) {
    if (progress < 0.20) {
      return _lerp(-14, 6, progress / 0.20);
    }

    if (progress < 0.44) {
      return _lerp(6, -4, (progress - 0.20) / 0.24);
    }

    return _lerp(-4, 0, (progress - 0.44) / 0.56);
  }

  double _normalImpactY(double progress) {
    if (progress < 0.26) {
      return _lerp(-8, 3.5, progress / 0.26);
    }

    if (progress < 0.52) {
      return _lerp(3.5, -1.8, (progress - 0.26) / 0.26);
    }

    return _lerp(-1.8, 0, (progress - 0.52) / 0.48);
  }

  double _doubleScale(double flight, double impact) {
    if (impact == 0) {
      return _lerp(0.78, 1.18, flight);
    }

    if (impact < 0.20) {
      return _lerp(1.18, 0.82, impact / 0.20);
    }

    if (impact < 0.46) {
      return _lerp(0.82, 1.08, (impact - 0.20) / 0.26);
    }

    return _lerp(1.08, 1, (impact - 0.46) / 0.54);
  }

  double _normalScale(double flight, double impact) {
    if (impact == 0) {
      return _lerp(0.84, 1.06, flight);
    }

    if (impact < 0.28) {
      return _lerp(1.06, 0.94, impact / 0.28);
    }

    if (impact < 0.55) {
      return _lerp(0.94, 1.025, (impact - 0.28) / 0.27);
    }

    return _lerp(1.025, 1, (impact - 0.55) / 0.45);
  }

  double _lerp(double start, double end, double t) {
    return start + (end - start) * t;
  }

  Widget _buildImpactWave({
    required double progress,
    required double startScale,
    required double endScale,
    required double maxOpacity,
    required double borderWidth,
  }) {
    if (progress <= 0 || progress >= 1) {
      return const SizedBox.shrink();
    }

    final opacity = (1 - progress) * maxOpacity;

    final scale = _lerp(
      startScale,
      endScale,
      Curves.easeOut.transform(progress),
    );

    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: borderWidth,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return Opacity(
        opacity: 0,
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final value = _controller.value;

        final flight = _flightProgress(value);
        final impact = _impactProgress(value);

        final approachY = widget.isDouble ? -14.0 : -8.0;

        final flightOffset = Offset.lerp(
          _sourceOffset,
          Offset(0, approachY),
          flight,
        )!;

        final arcY = -math.sin(flight * math.pi) *
            (widget.isDouble ? 54 : 38);

        final impactY = widget.isDouble
            ? _doubleImpactY(impact)
            : _normalImpactY(impact);

        final shakeX = widget.isDouble && impact > 0
            ? math.sin(impact * math.pi * 9) * (1 - impact) * 7
            : 0.0;

        final translation = impact == 0
            ? flightOffset + Offset(0, arcY)
            : Offset(shakeX, impactY);

        final startRotation = widget.horizontal
            ? -math.pi / 2
            : (widget.isDouble ? -0.10 : -0.05);

        final rotationDuringFlight = _lerp(startRotation, 0, flight);

        final impactRotation = widget.isDouble && impact > 0
            ? math.sin(impact * math.pi * 7) * (1 - impact) * 0.07
            : 0.0;

        final rotation = impact == 0 ? rotationDuringFlight : impactRotation;

        final scale = widget.isDouble
            ? _doubleScale(flight, impact)
            : _normalScale(flight, impact);

        final firstWave = widget.isDouble
            ? _waveProgress(
                impact: impact,
                delay: 0.01,
                duration: 0.58,
              )
            : 0.0;

        final secondWave = widget.isDouble
            ? _waveProgress(
                impact: impact,
                delay: 0.13,
                duration: 0.62,
              )
            : 0.0;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (widget.isDouble) ...[
              _buildImpactWave(
                progress: firstWave,
                startScale: 0.45,
                endScale: 2.25,
                maxOpacity: 0.58,
                borderWidth: 2.2,
              ),
              _buildImpactWave(
                progress: secondWave,
                startScale: 0.35,
                endScale: 1.85,
                maxOpacity: 0.30,
                borderWidth: 1.2,
              ),
            ],
            Transform.translate(
              offset: translation,
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
