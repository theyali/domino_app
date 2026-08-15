import 'package:flutter/material.dart';

class LeagueBadge extends StatelessWidget {
  final int league;
  final double size;

  const LeagueBadge({
    super.key,
    required this.league,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    final normalizedLeague = league.clamp(1, 5);

    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/ui/league_$normalizedLeague.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => Center(
          child: Text(
            '$normalizedLeague',
            style: TextStyle(
              fontSize: size * 0.34,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
