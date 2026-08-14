import 'package:flutter/material.dart';

import '../models/multiplayer_game_state.dart';
import '../models/restaurant.dart';
import '../models/user_account.dart';
import '../services/active_game_session_store.dart';
import '../services/api_service.dart';
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
        name: 'Ресторан #${room.restaurantId}',
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
        _errorMessage = 'Не удалось проверить сохранённую игру.';
        _isLoading = false;
      });
    }
  }

  void _resumeGame() {
    final gameState = _gameState;
    final restaurant = _restaurant;
    if (gameState == null || restaurant == null) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => MultiplayerGameScreen(
          restaurant: restaurant,
          initialGameState: gameState,
        ),
      ),
    );
  }

  Future<void> _leaveSavedGame() async {
    final savedSession = _savedSession;
    if (savedSession == null || _isLeaving) return;

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
        _errorMessage = 'Не удалось выйти из сохранённой игры.';
      });
    }
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

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF142638),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      color: Colors.greenAccent,
                      size: 46,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Есть незавершённая игра',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _restaurant?.name ?? 'Сохранённый стол',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Стол #${_savedSession!.roomId}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white54),
                    ),
                    if (_gameState != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          'Игрок: ${_gameState!.myPlayer.name}  ·  '
                          'Раунд ${_gameState!.roundNumber}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.orangeAccent),
                        ),
                        child: Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_gameState != null && _restaurant != null)
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _isLeaving ? null : _resumeGame,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text(
                            'Вернуться в игру',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _isLeaving ? null : _loadSavedGame,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text(
                            'Проверить снова',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _isLeaving ? null : _leaveSavedGame,
                      icon: _isLeaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.logout_rounded),
                      label: Text(
                        _isLeaving ? 'Выходим...' : 'Выйти из этой игры',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _isLeaving
                          ? null
                          : () {
                              setState(() {
                                _skipRecoveryForThisLaunch = true;
                              });
                            },
                      child: const Text('Открыть список ресторанов'),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Если открыть рестораны, сохранённая игра не удалится. '
                      'Она снова будет предложена при следующем запуске приложения.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        height: 1.35,
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

class _StartupLoading extends StatelessWidget {
  const _StartupLoading();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.greenAccent),
            SizedBox(height: 14),
            Text(
              'Проверяем активную игру...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
