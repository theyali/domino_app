import 'dart:async';

import 'package:flutter/material.dart';

import '../models/player_emotion_event.dart';
import '../services/emotion_realtime_service.dart';

class PlayerEmotionOverlay extends StatefulWidget {
  final int playerId;

  const PlayerEmotionOverlay({
    super.key,
    required this.playerId,
  });

  @override
  State<PlayerEmotionOverlay> createState() => _PlayerEmotionOverlayState();
}

class _PlayerEmotionOverlayState extends State<PlayerEmotionOverlay> {
  static const Duration _visibleDuration = Duration(milliseconds: 1800);

  StreamSubscription<PlayerEmotionEvent>? _subscription;
  final List<_VisibleEmotion> _visible = <_VisibleEmotion>[];
  final Map<String, Timer> _timers = <String, Timer>{};
  int _sequence = 0;

  @override
  void initState() {
    super.initState();
    _subscription = EmotionRealtimeService.instance.events.listen(_handleEvent);
  }

  @override
  void didUpdateWidget(covariant PlayerEmotionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerId != widget.playerId) {
      _clearVisible();
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _clearVisible(notify: false);
    super.dispose();
  }

  void _handleEvent(PlayerEmotionEvent event) {
    if (!mounted || event.playerId != widget.playerId) {
      return;
    }

    final visible = _VisibleEmotion(
      event: event,
      sequence: _sequence++,
    );

    setState(() {
      _visible.add(visible);
    });

    _timers[event.id]?.cancel();
    _timers[event.id] = Timer(_visibleDuration, () {
      _timers.remove(event.id);
      if (!mounted) return;
      setState(() {
        _visible.removeWhere((item) => item.event.id == event.id);
      });
    });
  }

  void _clearVisible({bool notify = true}) {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();

    if (notify && mounted) {
      setState(() {
        _visible.clear();
      });
    } else {
      _visible.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_visible.isEmpty) {
      return const SizedBox.expand();
    }

    return IgnorePointer(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final item in _visible)
            _EmotionBurst(
              key: ValueKey(item.event.id),
              assetPath: item.event.assetPath,
              sequence: item.sequence,
            ),
        ],
      ),
    );
  }
}

class _VisibleEmotion {
  final PlayerEmotionEvent event;
  final int sequence;

  const _VisibleEmotion({
    required this.event,
    required this.sequence,
  });
}

class _EmotionBurst extends StatefulWidget {
  final String assetPath;
  final int sequence;

  const _EmotionBurst({
    super.key,
    required this.assetPath,
    required this.sequence,
  });

  @override
  State<_EmotionBurst> createState() => _EmotionBurstState();
}

class _EmotionBurstState extends State<_EmotionBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;
  late final Animation<double> _rise;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );
    _scale = Tween<double>(begin: 0.45, end: 1.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.28, curve: Curves.easeOutBack),
      ),
    );
    _opacity = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 16,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: 58,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 26,
      ),
    ]).animate(_controller);
    _rise = Tween<double>(begin: 8, end: -24).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const slots = <Offset>[
      Offset(2, -20),
      Offset(34, -26),
      Offset(58, -12),
      Offset(-8, 8),
      Offset(52, 12),
      Offset(18, 20),
    ];
    final slot = slots[widget.sequence % slots.length];

    return Positioned(
      left: slot.dx,
      top: slot.dy,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacity.value.clamp(0.0, 1.0).toDouble(),
            child: Transform.translate(
              offset: Offset(0, _rise.value),
              child: Transform.scale(
                scale: _scale.value,
                child: child,
              ),
            ),
          );
        },
        child: Container(
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              widget.assetPath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }
}
