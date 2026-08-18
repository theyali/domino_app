import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../localization/statistics_strings.dart';
import '../models/league_statistics.dart';
import '../models/social.dart';
import '../services/api_service.dart';
import '../services/social_service.dart';
import '../services/statistics_service.dart';
import '../theme/play_palette.dart';
import '../widgets/cartoon_page_background.dart';
import '../widgets/league_badge.dart';
import '../widgets/site_image_panel.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  static const StatisticsService _statisticsService = StatisticsService();
  static const SocialService _socialService = SocialService();

  LeagueStatistics? _statistics;
  int? _selectedLeague;
  bool _isLoading = true;
  String? _errorMessage;

  bool get _isAz => context.appLanguage.code == 'az';

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
      setState(() => _errorMessage = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = StatisticsStrings.of(context).loadFailed;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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

  Future<void> _openPlayerMenu(LeaguePlayerStats player) async {
    final statistics = _statistics;
    if (statistics == null || player.userId == statistics.me.userId) return;

    try {
      final results = await _socialService.searchUsers(player.username);
      if (!mounted) return;

      SocialUser? user;
      for (final item in results) {
        if (item.id == player.userId) {
          user = item;
          break;
        }
      }

      if (user == null) {
        _showMessage(
          _isAz
              ? 'Bu oyunçu hazırda sosial menyuda əlçatan deyil.'
              : 'Этот игрок сейчас недоступен в социальном меню.',
        );
        return;
      }

      final changed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.72),
        builder: (context) => _LeaguePlayerActionSheet(
          player: player,
          user: user!,
          isAz: _isAz,
        ),
      );

      if (!mounted || changed != true) return;
      _showMessage(
        _isAz ? 'Dostluq məlumatı yeniləndi.' : 'Данные дружбы обновлены.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage(
        _isAz
            ? 'Oyunçunun menyusunu açmaq mümkün olmadı.'
            : 'Не удалось открыть меню игрока.',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final strings = StatisticsStrings.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CartoonPageBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _StatisticsHeader(
                title: strings.title,
                subtitle: strings.leaderboard,
                loading: _isLoading,
                onRefresh: _isLoading ? null : _load,
              ),
              Expanded(
                child: RefreshIndicator(
                  color: PlayPalette.blue,
                  backgroundColor: _StatsPalette.surface,
                  onRefresh: _load,
                  child: _buildBody(strings),
                ),
              ),
            ],
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
          SizedBox(height: 230),
          Center(
            child: CircularProgressIndicator(
              color: PlayPalette.blue,
              strokeWidth: 3,
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null && statistics == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 72, 16, 130),
        children: [
          SiteImagePanel(
            assetPath: 'assets/ui/long_5.webp',
            overlayColor: const Color(0xD0121212),
            borderColor: _StatsPalette.border,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
            child: Column(
              children: [
                const _StateIcon(
                  icon: Icons.cloud_off_rounded,
                  color: _StatsPalette.coral,
                ),
                const SizedBox(height: 18),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 18),
                _PrimaryButton(
                  label: _isAz ? 'Yenidən yoxla' : 'Повторить',
                  icon: Icons.refresh_rounded,
                  onTap: _load,
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (statistics == null) {
      return ListView(physics: const AlwaysScrollableScrollPhysics());
    }

    final selectedStanding = _selectedStanding(statistics);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 118),
      children: [
        _MyLeagueCard(statistics: statistics, strings: strings),
        const SizedBox(height: 24),
        _SectionHeader(
          title: strings.leaderboard,
          count: selectedStanding?.players.length,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
            itemCount: statistics.leagues.length,
            separatorBuilder: (context, index) => const SizedBox(width: 9),
            itemBuilder: (context, index) {
              final league = statistics.leagues[index];
              final selected = league.number ==
                  (_selectedLeague ?? statistics.me.league);

              return _LeagueChip(
                league: league,
                selected: selected,
                onTap: () {
                  setState(() => _selectedLeague = league.number);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 13),
        if (selectedStanding == null || selectedStanding.players.isEmpty)
          _EmptyLeague(strings: strings)
        else
          for (var index = 0;
              index < selectedStanding.players.length;
              index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Builder(
                builder: (context) {
                  final player = selectedStanding.players[index];
                  final isMe = player.userId == statistics.me.userId;

                  return _LeaderboardPlayer(
                    player: player,
                    isMe: isMe,
                    strings: strings,
                    onTap: isMe ? null : () => _openPlayerMenu(player),
                  );
                },
              ),
            ),
      ],
    );
  }
}

class _StatisticsHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onRefresh;

  const _StatisticsHeader({
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: _StatsPalette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRefresh,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: loading ? 0.55 : 1,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _StatsPalette.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _StatsPalette.border),
                ),
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: PlayPalette.blue,
                        ),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const _SectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.35,
            ),
          ),
        ),
        if (count != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _StatsPalette.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _StatsPalette.border),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: _StatsPalette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
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

  LeagueStanding? _leagueByNumber(int number) {
    for (final league in statistics.leagues) {
      if (league.number == number) return league;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final me = statistics.me;
    final currentLeague = _leagueByNumber(me.league);
    final nextLeague = _leagueByNumber(me.league - 1);
    final currentMinPoints = currentLeague?.minPoints ?? 0;
    final nextMinPoints = nextLeague?.minPoints;

    final progress = nextMinPoints == null
        ? 1.0
        : nextMinPoints <= currentMinPoints
            ? 0.0
            : ((me.leaguePoints - currentMinPoints) /
                    (nextMinPoints - currentMinPoints))
                .clamp(0.0, 1.0)
                .toDouble();

    return SiteImagePanel(
      assetPath: 'assets/ui/long_4.webp',
      borderRadius: 28,
      overlayColor: const Color(0xBC121212),
      borderColor: const Color(0x66106CFF),
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 82,
                height: 82,
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xD9262628),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0x77106CFF),
                    width: 1.4,
                  ),
                ),
                child: LeagueBadge(league: me.league, size: 68),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.yourLeague,
                      style: const TextStyle(
                        color: _StatsPalette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${strings.league} ${me.leagueRoman}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x22106CFF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0x66106CFF)),
                      ),
                      child: Text(
                        '${me.leaguePoints} ${strings.points}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (me.rank != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: PlayPalette.blue,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '#${me.rank}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 17),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0x33FFFFFF),
                valueColor: const AlwaysStoppedAnimation<Color>(PlayPalette.blue),
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
                color: _StatsPalette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
                  accent: Colors.white,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MiniStat(
                  value: '${me.wins}',
                  label: strings.wins,
                  accent: _StatsPalette.green,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MiniStat(
                  value: '${me.losses}',
                  label: strings.losses,
                  accent: _StatsPalette.coral,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MiniStat(
                  value: '${me.winRate.toStringAsFixed(0)}%',
                  label: strings.winRate,
                  accent: _StatsPalette.yellow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x1FFFFFFF),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _StatsPalette.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  color: _StatsPalette.yellow,
                  size: 18,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    strings.winReward(statistics.winPoints),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
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

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color accent;

  const _MiniStat({
    required this.value,
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 68),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xCC262628),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _StatsPalette.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _StatsPalette.muted,
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
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(8, 5, 12, 5),
        decoration: BoxDecoration(
          color: selected ? PlayPalette.blue : _StatsPalette.surface,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? PlayPalette.blue : _StatsPalette.border,
          ),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x44106CFF),
                    blurRadius: 14,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LeagueBadge(league: league.number, size: 39),
            const SizedBox(width: 7),
            Text(
              '${league.roman} · ${league.players.length}',
              style: TextStyle(
                color: selected ? Colors.white : _StatsPalette.textSoft,
                fontSize: 14,
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
  final VoidCallback? onTap;

  const _LeaderboardPlayer({
    required this.player,
    required this.isMe,
    required this.strings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: isMe ? const Color(0x24106CFF) : _StatsPalette.surface,
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: isMe ? const Color(0xAA106CFF) : _StatsPalette.border,
            width: isMe ? 1.4 : 1,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x31000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: player.rank == 1
                    ? _StatsPalette.yellow
                    : isMe
                        ? PlayPalette.blue
                        : _StatsPalette.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '#${player.rank ?? '-'}',
                style: TextStyle(
                  color: player.rank == 1
                      ? _StatsPalette.ink
                      : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            _StatsAvatar(player: player),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          player.name.isEmpty ? player.username : player.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: PlayPalette.blue,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            context.appLanguage.code == 'az' ? 'SƏN' : 'ТЫ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${player.wins} ${strings.wins.toLowerCase()} · '
                    '${player.losses} ${strings.losses.toLowerCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _StatsPalette.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 62),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
              decoration: BoxDecoration(
                color: _StatsPalette.surfaceRaised,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _StatsPalette.border),
              ),
              child: Column(
                children: [
                  Text(
                    '${player.leaguePoints}',
                    style: const TextStyle(
                      color: _StatsPalette.green,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    strings.points,
                    style: const TextStyle(
                      color: _StatsPalette.muted,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (!isMe) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.more_horiz_rounded,
                color: _StatsPalette.muted,
                size: 21,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatsAvatar extends StatelessWidget {
  final LeaguePlayerStats player;

  const _StatsAvatar({required this.player});

  @override
  Widget build(BuildContext context) {
    final trimmedName = player.name.trim();
    final letter = trimmedName.isNotEmpty
        ? trimmedName[0].toUpperCase()
        : player.username.isNotEmpty
            ? player.username[0].toUpperCase()
            : '?';

    return Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _StatsPalette.surfaceRaised,
        border: Border.all(color: const Color(0x77106CFF), width: 1.4),
      ),
      child: ClipOval(
        child: player.avatarUrl?.isNotEmpty == true
            ? Image.network(
                player.avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _AvatarLetter(letter: letter),
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
    return ColoredBox(
      color: _StatsPalette.surfaceRaised,
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
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
    return SiteImagePanel(
      assetPath: 'assets/ui/long_5.webp',
      overlayColor: const Color(0xD0121212),
      borderColor: _StatsPalette.border,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(
        children: [
          const _StateIcon(
            icon: Icons.emoji_events_rounded,
            color: PlayPalette.blue,
          ),
          const SizedBox(height: 14),
          Text(
            strings.noPlayers,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaguePlayerActionSheet extends StatefulWidget {
  final LeaguePlayerStats player;
  final SocialUser user;
  final bool isAz;

  const _LeaguePlayerActionSheet({
    required this.player,
    required this.user,
    required this.isAz,
  });

  @override
  State<_LeaguePlayerActionSheet> createState() =>
      _LeaguePlayerActionSheetState();
}

class _LeaguePlayerActionSheetState extends State<_LeaguePlayerActionSheet> {
  static const SocialService _service = SocialService();

  bool _busy = false;
  String? _error;

  Future<void> _runFriendAction() async {
    final user = widget.user;
    if (_busy || user.isFriend || user.requestOutgoing) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (user.requestIncoming && user.friendshipId != null) {
        await _service.acceptFriendRequest(user.friendshipId!);
      } else {
        await _service.sendFriendRequest(user.id);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = widget.isAz
            ? 'Dostluq əməliyyatı alınmadı.'
            : 'Не удалось выполнить действие с друзьями.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _actionLabel {
    final user = widget.user;
    if (user.isFriend) return widget.isAz ? 'Artıq dostsunuz' : 'Уже в друзьях';
    if (user.requestOutgoing) {
      return widget.isAz ? 'Sorğu göndərilib' : 'Заявка отправлена';
    }
    if (user.requestIncoming) {
      return widget.isAz ? 'Sorğunu qəbul et' : 'Принять заявку';
    }
    return widget.isAz ? 'Dostlara əlavə et' : 'Добавить в друзья';
  }

  IconData get _actionIcon {
    final user = widget.user;
    if (user.isFriend) return Icons.people_alt_rounded;
    if (user.requestOutgoing) return Icons.schedule_rounded;
    return Icons.person_add_alt_1_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final disabled = widget.user.isFriend || widget.user.requestOutgoing;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: _StatsPalette.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _StatsPalette.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: _StatsPalette.muted,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _StatsAvatar(player: widget.player),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.player.name.isEmpty
                            ? widget.player.username
                            : widget.player.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '@${widget.player.username}',
                        style: const TextStyle(
                          color: _StatsPalette.muted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0x22FF6475),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0x55FF6475)),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: _StatsPalette.coral,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: disabled || _busy ? null : _runFriendAction,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: disabled ? 0.55 : 1,
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: disabled
                        ? _StatsPalette.surfaceRaised
                        : PlayPalette.blue,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: disabled
                          ? _StatsPalette.border
                          : PlayPalette.blue,
                    ),
                  ),
                  child: _busy
                      ? const Center(
                          child: SizedBox(
                            width: 21,
                            height: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(_actionIcon, color: Colors.white, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              _actionLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StateIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _StateIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Icon(icon, color: color, size: 32),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: PlayPalette.blue,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsPalette {
  static const Color ink = Color(0xFF121212);
  static const Color surface = Color(0xFF262628);
  static const Color surfaceRaised = Color(0xFF323234);
  static const Color border = Color(0xFF3A3A3E);
  static const Color muted = Color(0xFFA7A7AD);
  static const Color textSoft = Color(0xFFE2E2E5);
  static const Color green = Color(0xFF5FE2A0);
  static const Color coral = Color(0xFFFF6475);
  static const Color yellow = Color(0xFFFFD35A);
}
