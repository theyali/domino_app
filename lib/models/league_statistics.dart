import '../config/api_config.dart';

class LeaguePlayerStats {
  final int userId;
  final String username;
  final String name;
  final String? avatarUrl;
  final int league;
  final String leagueRoman;
  final int leaguePoints;
  final int pointsToNextLeague;
  final int gamesPlayed;
  final int wins;
  final int losses;
  final double winRate;
  final int? rank;

  const LeaguePlayerStats({
    required this.userId,
    required this.username,
    required this.name,
    this.avatarUrl,
    required this.league,
    required this.leagueRoman,
    required this.leaguePoints,
    required this.pointsToNextLeague,
    required this.gamesPlayed,
    required this.wins,
    required this.losses,
    required this.winRate,
    this.rank,
  });

  factory LeaguePlayerStats.fromJson(Map<String, dynamic> json) {
    return LeaguePlayerStats(
      userId: json['user_id'] as int,
      username: json['username'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: ApiConfig.resolveUrl(json['avatar_url'] as String?),
      league: json['league'] as int? ?? 5,
      leagueRoman: json['league_roman'] as String? ?? 'V',
      leaguePoints: json['league_points'] as int? ?? 0,
      pointsToNextLeague: json['points_to_next_league'] as int? ?? 0,
      gamesPlayed: json['games_played'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      winRate: (json['win_rate'] as num?)?.toDouble() ?? 0,
      rank: json['rank'] as int?,
    );
  }
}

class LeagueStanding {
  final int number;
  final String roman;
  final int minPoints;
  final int? maxPoints;
  final List<LeaguePlayerStats> players;

  const LeagueStanding({
    required this.number,
    required this.roman,
    required this.minPoints,
    this.maxPoints,
    required this.players,
  });

  factory LeagueStanding.fromJson(Map<String, dynamic> json) {
    final playersJson = json['players'] as List<dynamic>? ?? const [];
    return LeagueStanding(
      number: json['number'] as int,
      roman: json['roman'] as String,
      minPoints: json['min_points'] as int? ?? 0,
      maxPoints: json['max_points'] as int?,
      players: playersJson
          .map(
            (item) => LeaguePlayerStats.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}

class LeagueStatistics {
  final int winPoints;
  final LeaguePlayerStats me;
  final List<LeagueStanding> leagues;

  const LeagueStatistics({
    required this.winPoints,
    required this.me,
    required this.leagues,
  });

  factory LeagueStatistics.fromJson(Map<String, dynamic> json) {
    final leaguesJson = json['leagues'] as List<dynamic>? ?? const [];
    return LeagueStatistics(
      winPoints: json['win_points'] as int? ?? 25,
      me: LeaguePlayerStats.fromJson(
        Map<String, dynamic>.from(json['me'] as Map),
      ),
      leagues: leaguesJson
          .map(
            (item) => LeagueStanding.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
    );
  }
}
