import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/multiplayer_game_state.dart';
import '../models/restaurant.dart';
import '../models/user_account.dart';
import '../services/active_game_session_store.dart';
import '../services/api_service.dart';
import '../services/sound_effects_service.dart';
import '../widgets/cartoon_page_background.dart';
import 'main_shell_screen.dart';
import 'multiplayer_game_screen.dart';

class AppStartupScreen extends StatefulWidget {
  final UserAccount user;
  final Future<void> Function() onLogout;

  const AppStartupScreen({
    super.key,
    required this.user,
    required this.onLogout,
  });

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen> {
  final ApiService _apiService = const ApiService();
  final ActiveGameSessionStore _sessionStore = ActiveGameSessionStore();

  SavedActiveGameSession? _savedSession;
  MultiplayerGameState? _gameState;
  Restaurant? _restaurant;

  bool _isLoading = true;
  bool _isLeaving = false;
  bool _skipRecoveryForThisLaunch = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedGame();
  }

  Future<void> _loadSavedGame() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final savedSession = await _sessionStore.load();
    if (!mounted) return;

    if (savedSession == null) {
      setState(() {
        _savedSession = null;
        _gameState = null;
        _restaurant = null;
        _isLoading = false;
      });
      return;
    }

    try {
      final gameState = await _apiService.fetchGameState(
        roomId: savedSession.roomId,
        playerId: savedSession.playerId,
      );

      if (!gameState.myPlayer.isActive) {
        await _sessionStore.clear();
        if (!mounted) return;
        setState(() {
          _savedSession = null;
          _gameState = null;
          _restaurant = null;
          _isLoading = false;
        });
        return;
      }

      final room = await _apiService.fetchRoom(savedSession.roomId);
      final restaurants = await _apiService.fetchRestaurants();

      Restaurant? restaurant;
      for (final candidate in restaurants) {
        if (candidate.id == room.restaurantId) {
          restaurant = candidate;
          break;
        }
      }

      restaurant ??= Restaurant(
        id: room.restaurantId,
        name: context.tr(
          'restaurant_fallback',
          arguments: {'id': room.restaurantId},
        ),
        players: 0,
        active: true,
      );

      if (!mounted) return;
      setState(() {
        _savedSession = savedSession;
        _gameState = gameState;
        _restaurant = restaurant;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (error.statusCode == 403 || error.statusCode == 404) {
        await _sessionStore.clear();
        if (!mounted) return;
        setState(() {
          _savedSession = null;
          _gameState = null;
          _restaurant = null;
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _savedSession = savedSession;
        _gameState = null;
        _restaurant = null;
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _savedSession = savedSession;
        _gameState = null;
        _restaurant = null;
        _errorMessage = context.tr('saved_game_check_failed');
        _isLoading = false;
      });
    }
  }

  Future<void> _resumeGame() async {
    final gameState = _gameState;
    final restaurant = _restaurant;
    if (gameState == null || restaurant == null) return;

    SoundEffectsService.button(alternate: true);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MultiplayerGameScreen(
          restaurant: restaurant,
          initialGameState: gameState,
        ),
      ),
    );

    if (!mounted) return;
    await _loadSavedGame();
  }

  Future<void> _leaveSavedGame() async {
    final savedSession = _savedSession;
    if (savedSession == null || _isLeaving) return;

    SoundEffectsService.button();
    setState(() {
      _isLeaving = true;
      _errorMessage = null;
    });

    try {
      await _apiService.leaveRoom(
        roomId: savedSession.roomId,
        playerId: savedSession.playerId,
      );
      await _sessionStore.clear();

      if (!mounted) return;
      setState(() {
        _savedSession = null;
        _gameState = null;
        _restaurant = null;
        _isLeaving = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLeaving = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLeaving = false;
        _errorMessage = context.tr('saved_game_leave_failed');
      });
    }
  }

  void _openRestaurants() {
    SoundEffectsService.button();
    setState(() {
      _skipRecoveryForThisLaunch = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _StartupLoading();
    }

    if (_skipRecoveryForThisLaunch || _savedSession == null) {
      return MainShellScreen(
        user: widget.user,
        onLogout: widget.onLogout,
      );
    }

    final canResume = _gameState != null && _restaurant != null;

    return CartoonPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 28, 18, 30),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 42),
                      padding: const EdgeInsets.fromLTRB(18, 58, 18, 20),
                      decoration: BoxDecoration(
                        color: _RecoveryPalette.yellow,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: _RecoveryPalette.ink,
                          width: 3.2,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: _RecoveryPalette.ink,
                            blurRadius: 0,
                            offset: Offset(7, 9),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.tr('unfinished_game'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _RecoveryPalette.ink,
                              fontSize: 27,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _RestaurantCard(
                            restaurantName:
                                _restaurant?.name ?? context.tr('saved_table'),
                            tableLabel: context.tr(
                              'table_number',
                              arguments: {'number': _savedSession!.roomId},
                            ),
                          ),
                          if (_gameState != null) ...[
                            const SizedBox(height: 12),
                            _RoundInfoCard(
                              text: context.tr(
                                'player_round',
                                arguments: {
                                  'player': _gameState!.myPlayer.name,
                                  'round': _gameState!.roundNumber,
                                },
                              ),
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _ErrorCard(message: _errorMessage!),
                          ],
                          const SizedBox(height: 18),
                          _CartoonRecoveryButton(
                            backgroundColor: _RecoveryPalette.lime,
                            icon: canResume
                                ? Icons.play_arrow_rounded
                                : Icons.refresh_rounded,
                            label: context.tr(
                              canResume ? 'return_to_game' : 'check_again',
                            ),
                            onTap: _isLeaving
                                ? null
                                : canResume
                                    ? _resumeGame
                                    : _loadSavedGame,
                          ),
                          const SizedBox(height: 12),
                          _CartoonRecoveryButton(
                            backgroundColor: _RecoveryPalette.coral,
                            icon: Icons.logout_rounded,
                            label: context.tr(
                              _isLeaving ? 'leaving' : 'leave_game',
                            ),
                            onTap: _isLeaving ? null : _leaveSavedGame,
                            loading: _isLeaving,
                          ),
                          const SizedBox(height: 12),
                          _CartoonRecoveryButton(
                            backgroundColor: _RecoveryPalette.skyBlue,
                            icon: Icons.restaurant_menu_rounded,
                            label: context.tr('open_restaurants'),
                            onTap: _isLeaving ? null : _openRestaurants,
                            compact: true,
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: _RecoveryPalette.cream,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: _RecoveryPalette.ink,
                                width: 2.2,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: _RecoveryPalette.ink,
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr('saved_game_note'),
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                      color: _RecoveryPalette.inkSoft,
                                      fontSize: 11,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 0,
                      child: Transform.rotate(
                        angle: -0.05,
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: _RecoveryPalette.lime,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _RecoveryPalette.ink,
                              width: 3.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: _RecoveryPalette.ink,
                                blurRadius: 0,
                                offset: Offset(5, 6),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: _RecoveryPalette.ink,
                            size: 51,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final String restaurantName;
  final String tableLabel;

  const _RestaurantCard({
    required this.restaurantName,
    required this.tableLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: _RecoveryPalette.cream,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: _RecoveryPalette.ink, width: 2.6),
        boxShadow: const [
          BoxShadow(
            color: _RecoveryPalette.ink,
            blurRadius: 0,
            offset: Offset(3, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _RecoveryPalette.skyBlue,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _RecoveryPalette.ink, width: 2.4),
            ),
            child: const Icon(
              Icons.table_restaurant_rounded,
              color: _RecoveryPalette.ink,
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurantName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _RecoveryPalette.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tableLabel,
                  style: const TextStyle(
                    color: _RecoveryPalette.inkSoft,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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

class _RoundInfoCard extends StatelessWidget {
  final String text;

  const _RoundInfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: _RecoveryPalette.mint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _RecoveryPalette.ink, width: 2.3),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.sports_esports_rounded,
            color: _RecoveryPalette.ink,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _RecoveryPalette.ink,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _RecoveryPalette.coralSoft,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _RecoveryPalette.ink, width: 2.2),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: _RecoveryPalette.ink,
            size: 21,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _RecoveryPalette.ink,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartoonRecoveryButton extends StatelessWidget {
  final Color backgroundColor;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final bool compact;

  const _CartoonRecoveryButton({
    required this.backgroundColor,
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: compact ? 52 : 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(compact ? 17 : 19),
            border: Border.all(color: _RecoveryPalette.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: _RecoveryPalette.ink,
                blurRadius: 0,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: _RecoveryPalette.ink,
                  ),
                )
              else
                Icon(icon, color: _RecoveryPalette.ink, size: compact ? 22 : 25),
              const SizedBox(width: 9),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _RecoveryPalette.ink,
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return CartoonPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 34),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              decoration: BoxDecoration(
                color: _RecoveryPalette.cream,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: _RecoveryPalette.ink, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: _RecoveryPalette.ink,
                    blurRadius: 0,
                    offset: Offset(5, 7),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: _RecoveryPalette.lime,
                      shape: BoxShape.circle,
                      border: Border.all(color: _RecoveryPalette.ink, width: 2.7),
                    ),
                    padding: const EdgeInsets.all(15),
                    child: const CircularProgressIndicator(
                      strokeWidth: 4,
                      color: _RecoveryPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr('checking_active_game'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _RecoveryPalette.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _RecoveryPalette {
  static const ink = Color(0xFF111111);
  static const inkSoft = Color(0xFF57483C);
  static const cream = Color(0xFFFFF4D7);
  static const yellow = Color(0xFFFFD45A);
  static const lime = Color(0xFF76F400);
  static const skyBlue = Color(0xFF78CEF2);
  static const mint = Color(0xFF8DDD79);
  static const coral = Color(0xFFFF7A70);
  static const coralSoft = Color(0xFFFFC1B7);
}
