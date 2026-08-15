import 'package:flutter/material.dart';

import '../localization/statistics_strings.dart';
import '../models/league_statistics.dart';
import '../services/api_service.dart';
import '../services/statistics_service.dart';
import '../theme/app_colors.dart';

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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

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
      appBar: AppBar(
        title: Text(strings.title),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(strings),
      ),
    );
  }

  Widget _buildBody(StatisticsStrings strings) {
    final statistics = _statistics;

    if (_isLoading && statistics == null) {
      return const ListView(
        physics: AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 280),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_errorMessage != null && statistics == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 190),
          const Icon(Icons.leaderboard_rounded, size: 62, color: AppColors.brass),
          const SizedBox(height: 14),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (statistics == null) {
      return const ListView();
    }

    final selectedStanding = _selectedStanding(statistics);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
      children: [
        _MyLeagueCard(statistics: statistics, strings: strings),
        const SizedBox(height: 18),
        Text(
          strings.leaderboard,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 11),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: statistics.leagues.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
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
        const SizedBox(height: 14),
        if (selectedStanding == null || selectedStanding.players.isEmpty)
          _EmptyLeague(strings: strings)
        else
          for (final player in selectedStanding.players)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _LeaderboardPlayer(
                player: player,
                isMe: player.userId == statistics.me.userId,
                strings: strings,
              ),
            ),
      ],
    );
  }
}

class _MyLeagueCard extends StatelessWidget {
  final LeagueStatistics statistics;
  final StatisticsStrings strings;

  const _MyLeagueCard({required this.statistics, required this.strings});

  @override
  Widget build(BuildContext context) {
    final me = statistics.me;
    final currentLeague = statistics.leagues.firstWhere(
      (league) => league.number == me.league,
      orElse: () => statistics.leagues.last,
    );
    final nextLeague = statistics.leagues
        .where((league) => league.number == me.league - 1)
        .firstOrNull;

    final progress = nextLeague == null
        ? 1.0
        : ((me.leaguePoints - currentLeague.minPoints) /
                (nextLeague.minPoints - currentLeague.minPoints))
            .clamp(0.0, 1.0)
            .toDouble();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.panelTop, AppColors.panelBottom],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.brass.withValues(alpha: 0.65), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 18, offset: Offset(0, 9)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _LeagueMedal(roman: me.leagueRoman, size: 72),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.yourLeague,
                      style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${strings.league} ${me.leagueRoman}',
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${me.leaguePoints} ${strings.points}',
                      style: const TextStyle(color: AppColors.lime, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              if (me.rank != null)
                Text(
                  '#${me.rank}',
                  style: const TextStyle(color: AppColors.brassLight, fontSize: 23, fontWeight: FontWeight.w900),
                ),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.black38,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              nextLeague == null
                  ? strings.maxLeague
                  : strings.pointsUntilNext(me.pointsToNextLeague, nextLeague.roman),
              style: const TextStyle(color: Colors.white60, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _MiniStat(value: '${me.gamesPlayed}', label: strings.games)),
              const SizedBox(width: 7),
              Expanded(child: _MiniStat(value: '${me.wins}', label: strings.wins)),
              const SizedBox(width: 7),
              Expanded(child: _MiniStat(value: '${me.losses}', label: strings.losses)),
              const SizedBox(width: 7),
              Expanded(child: _MiniStat(value: '${me.winRate.toStringAsFixed(0)}%', label: strings.winRate)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            strings.winReward(statistics.winPoints),
            style: const TextStyle(color: AppColors.brassLight, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;

  const _MiniStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.cream)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: Colors.white54)),
        ],
      ),
    );
  }
}

class _LeagueChip extends StatelessWidget {
  final LeagueStanding league;
  final bool selected;
  final VoidCallback onTap;

  const _LeagueChip({required this.league, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: selected ? AppColors.lime : AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? AppColors.ink : AppColors.brass.withValues(alpha: 0.30)),
        ),
        alignment: Alignment.center,
        child: Text(
          '${league.roman}  ·  ${league.players.length}',
          style: TextStyle(
            color: selected ? Colors.black : Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _LeaderboardPlayer extends StatelessWidget {
  final LeaguePlayerStats player;
  final bool isMe;
  final StatisticsStrings strings;

  const _LeaderboardPlayer({required this.player, required this.isMe, required this.strings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.lime.withValues(alpha: 0.10) : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isMe ? AppColors.lime.withValues(alpha: 0.62) : AppColors.brass.withValues(alpha: 0.18),
          width: isMe ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 31,
            child: Text(
              '#${player.rank ?? '-'}',
              style: TextStyle(
                color: (player.rank ?? 99) <= 3 ? AppColors.brassLight : Colors.white54,
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
                  style: TextStyle(
                    color: isMe ? AppColors.limeSoft : Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${player.wins} ${strings.wins.toLowerCase()} · ${player.losses} ${strings.losses.toLowerCase()}',
                  style: const TextStyle(color: Colors.white54, fontSize: 10.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${player.leaguePoints}',
                style: const TextStyle(color: AppColors.lime, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              Text(strings.points, style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
            ],
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

    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.brass),
      child: ClipOval(
        child: player.avatarUrl?.isNotEmpty == true
            ? Image.network(
                player.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _AvatarLetter(letter: letter),
              )
            : _AvatarLetter(letter: letter),
      ),
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  final String letter;

  const _AvatarLetter({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cream,
      alignment: Alignment.center,
      child: Text(letter, style: const TextStyle(color: AppColors.ink, fontSize: 17, fontWeight: FontWeight.w900)),
    );
  }
}

class _LeagueMedal extends StatelessWidget {
  final String roman;
  final double size;

  const _LeagueMedal({required this.roman, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brassLight, AppColors.brass, AppColors.brassDark],
        ),
        border: Border.all(color: AppColors.cream, width: 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 9, offset: Offset(0, 5))],
      ),
      alignment: Alignment.center,
      child: Text(
        roman,
        style: TextStyle(color: AppColors.ink, fontSize: size * 0.34, fontWeight: FontWeight.w900),
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
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events_outlined, size: 48, color: AppColors.brass),
          const SizedBox(height: 10),
          Text(strings.noPlayers, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
