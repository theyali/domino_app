import 'package:flutter/material.dart';

import '../localization/statistics_strings.dart';
import '../models/league_statistics.dart';
import '../services/api_service.dart';
import '../services/statistics_service.dart';
import '../widgets/cartoon_page_background.dart';
import '../widgets/game_avatar_frame.dart';
import '../widgets/league_badge.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const StatisticsService _statisticsService = StatisticsService();

  LeagueStatistics? _statistics;
  int? _selectedLeague;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final statistics = await _statisticsService.fetchStatistics();
      if (!mounted) return;
      setState(() {
        _statistics = statistics;
        _selectedLeague ??= statistics.me.league;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = StatisticsStrings.of(context).loadFailed;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  LeagueStanding? _selectedStanding(LeagueStatistics statistics) {
    final selected = _selectedLeague ?? statistics.me.league;
    for (final league in statistics.leagues) {
      if (league.number == selected) return league;
    }
    return statistics.leagues.isEmpty ? null : statistics.leagues.first;
  }

  @override
  Widget build(BuildContext context) {
    final strings = StatisticsStrings.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CartoonPageBackground(
        child: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: _StatsPalette.ink,
            backgroundColor: Colors.white,
            onRefresh: _load,
            child: _buildBody(strings),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(StatisticsStrings strings) {
    final statistics = _statistics;

    if (_isLoading && statistics == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 280),
          Center(
            child: CircularProgressIndicator(
              color: _StatsPalette.ink,
              strokeWidth: 3,
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null && statistics == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 120, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _StatsPalette.yellow,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _StatsPalette.ink, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: _StatsPalette.ink,
                  blurRadius: 0,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.leaderboard_rounded,
                  size: 58,
                  color: _StatsPalette.ink,
                ),
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _StatsPalette.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _load,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _StatsPalette.ink,
                    side: const BorderSide(
                      color: _StatsPalette.ink,
                      width: 3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(strings.loadFailed),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (statistics == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
      );
    }

    final selectedStanding = _selectedStanding(statistics);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      children: [
        _MyLeagueCard(statistics: statistics, strings: strings),
        const SizedBox(height: 20),
        _SectionTitle(text: strings.leaderboard),
        const SizedBox(height: 12),
        SizedBox(
          height: 68,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: statistics.leagues.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final league = statistics.leagues[index];
              final selected = league.number ==
                  (_selectedLeague ?? statistics.me.league);
              return _LeagueChip(
                league: league,
                selected: selected,
                onTap: () {
                  setState(() {
                    _selectedLeague = league.number;
                  });
                },
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (selectedStanding == null || selectedStanding.players.isEmpty)
          _EmptyLeague(strings: strings)
        else
          for (var index = 0;
              index < selectedStanding.players.length;
              index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 11),
              child: _LeaderboardPlayer(
                player: selectedStanding.players[index],
                isMe: selectedStanding.players[index].userId ==
                    statistics.me.userId,
                strings: strings,
                colorIndex: index,
              ),
            ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _StatsPalette.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _StatsPalette.ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: _StatsPalette.ink,
              blurRadius: 0,
              offset: Offset(3, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: _StatsPalette.ink,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MyLeagueCard extends StatelessWidget {
  final LeagueStatistics statistics;
  final StatisticsStrings strings;

  const _MyLeagueCard({required this.statistics, required this.strings});

  LeagueStanding? _nextLeagueFor(LeaguePlayerStats me) {
    for (final league in statistics.leagues) {
      if (league.number == me.league - 1) return league;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final me = statistics.me;
    final currentLeague = statistics.leagues.firstWhere(
      (league) => league.number == me.league,
      orElse: () => statistics.leagues.last,
    );
    final nextLeague = _nextLeagueFor(me);

    final progress = nextLeague == null
        ? 1.0
        : ((me.leaguePoints - currentLeague.minPoints) /
                (nextLeague.minPoints - currentLeague.minPoints))
            .clamp(0.0, 1.0)
            .toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _StatsPalette.skyBlue,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _StatsPalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _StatsPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: _StatsPalette.ink, width: 3),
                ),
                child: LeagueBadge(league: me.league, size: 72),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.yourLeague,
                      style: const TextStyle(
                        color: _StatsPalette.inkSoft,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${strings.league} ${me.leagueRoman}',
                      style: const TextStyle(
                        color: _StatsPalette.ink,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _StatsPalette.lime,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _StatsPalette.ink,
                          width: 2.4,
                        ),
                      ),
                      child: Text(
                        '${me.leaguePoints} ${strings.points}',
                        style: const TextStyle(
                          color: _StatsPalette.ink,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (me.rank != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _StatsPalette.yellow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _StatsPalette.ink, width: 3),
                  ),
                  child: Text(
                    '#${me.rank}',
                    style: const TextStyle(
                      color: _StatsPalette.ink,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 16,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: _StatsPalette.ink, width: 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  _StatsPalette.lime,
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              nextLeague == null
                  ? strings.maxLeague
                  : strings.pointsUntilNext(
                      me.pointsToNextLeague,
                      nextLeague.roman,
                    ),
              style: const TextStyle(
                color: _StatsPalette.inkSoft,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  value: '${me.gamesPlayed}',
                  label: strings.games,
                  color: _StatsPalette.cream,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MiniStat(
                  value: '${me.wins}',
                  label: strings.wins,
                  color: _StatsPalette.mint,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MiniStat(
                  value: '${me.losses}',
                  label: strings.losses,
                  color: _StatsPalette.peach,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MiniStat(
                  value: '${me.winRate.toStringAsFixed(0)}%',
                  label: strings.winRate,
                  color: _StatsPalette.yellowSoft,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _StatsPalette.yellow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _StatsPalette.ink, width: 2.5),
            ),
            child: Text(
              strings.winReward(statistics.winPoints),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _StatsPalette.ink,
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _StatsPalette.ink, width: 2.5),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: _StatsPalette.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _StatsPalette.inkSoft,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeagueChip extends StatelessWidget {
  final LeagueStanding league;
  final bool selected;
  final VoidCallback onTap;

  const _LeagueChip({
    required this.league,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(9, 5, 13, 5),
        decoration: BoxDecoration(
          color: selected ? _StatsPalette.yellow : _StatsPalette.cream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _StatsPalette.ink, width: 3),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: _StatsPalette.ink,
                    blurRadius: 0,
                    offset: Offset(3, 4),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LeagueBadge(league: league.number, size: 38),
            const SizedBox(width: 7),
            Text(
              '${league.roman} · ${league.players.length}',
              style: const TextStyle(
                color: _StatsPalette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaderboardPlayer extends StatelessWidget {
  final LeaguePlayerStats player;
  final bool isMe;
  final StatisticsStrings strings;
  final int colorIndex;

  const _LeaderboardPlayer({
    required this.player,
    required this.isMe,
    required this.strings,
    required this.colorIndex,
  });

  Color get _cardColor {
    if (isMe) return _StatsPalette.yellow;

    switch (colorIndex % 4) {
      case 0:
        return _StatsPalette.skyBlue;
      case 1:
        return _StatsPalette.mint;
      case 2:
        return _StatsPalette.peach;
      default:
        return _StatsPalette.cream;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _StatsPalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _StatsPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: Text(
              '#${player.rank ?? '-'}',
              style: const TextStyle(
                color: _StatsPalette.ink,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _StatsAvatar(player: player),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  player.name.isEmpty ? player.username : player.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _StatsPalette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${player.wins} ${strings.wins.toLowerCase()} · '
                  '${player.losses} ${strings.losses.toLowerCase()}',
                  style: const TextStyle(
                    color: _StatsPalette.inkSoft,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _StatsPalette.ink, width: 2.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${player.leaguePoints}',
                  style: const TextStyle(
                    color: _StatsPalette.green,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  strings.points,
                  style: const TextStyle(
                    color: _StatsPalette.inkSoft,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsAvatar extends StatelessWidget {
  final LeaguePlayerStats player;

  const _StatsAvatar({required this.player});

  @override
  Widget build(BuildContext context) {
    final letter = player.name.trim().isEmpty
        ? (player.username.isEmpty ? '?' : player.username[0].toUpperCase())
        : player.name.trim()[0].toUpperCase();

    final avatar = player.avatarUrl?.isNotEmpty == true
        ? Image.network(
            player.avatarUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _AvatarLetter(letter: letter),
          )
        : _AvatarLetter(letter: letter);

    return GameAvatarFrame(
      size: 46,
      innerPadding: 7,
      child: avatar,
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  final String letter;

  const _AvatarLetter({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _StatsPalette.cream,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: _StatsPalette.ink,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyLeague extends StatelessWidget {
  final StatisticsStrings strings;

  const _EmptyLeague({required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: _StatsPalette.cream,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _StatsPalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _StatsPalette.ink,
            blurRadius: 0,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            size: 50,
            color: _StatsPalette.ink,
          ),
          const SizedBox(height: 10),
          Text(
            strings.noPlayers,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _StatsPalette.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsPalette {
  static const Color ink = Color(0xFF16110D);
  static const Color inkSoft = Color(0xFF514B45);

  static const Color cream = Color(0xFFFFF4D8);
  static const Color yellow = Color(0xFFFFD85A);
  static const Color yellowSoft = Color(0xFFFFE8A3);
  static const Color skyBlue = Color(0xFF67C8EE);
  static const Color mint = Color(0xFF89D875);
  static const Color peach = Color(0xFFFF8A79);
  static const Color lime = Color(0xFF7CFC00);
  static const Color green = Color(0xFF4EA900);
}
