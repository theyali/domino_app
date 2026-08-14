import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/app_localizations.dart';
import '../models/user_account.dart';
import '../services/active_game_session_store.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/auth_session_store.dart';
import 'app_startup_screen.dart';
import 'auth_screen.dart';
import 'language_selection_screen.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  static const AuthService _authService = AuthService();

  final AuthSessionStore _authStore = AuthSessionStore();
  final ActiveGameSessionStore _gameSessionStore = ActiveGameSessionStore();

  bool _isLoading = true;
  String? _token;
  UserAccount? _user;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final token = await _authStore.loadToken();
    if (!mounted) return;

    if (token == null) {
      setState(() {
        _token = null;
        _user = null;
        _isLoading = false;
      });
      return;
    }

    try {
      final user = await _authService.fetchMe(token);
      if (!mounted) return;

      setState(() {
        _token = token;
        _user = user;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _authStore.clear();
        await _gameSessionStore.clear();
        if (!mounted) return;
        setState(() {
          _token = null;
          _user = null;
          _isLoading = false;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = context.tr('auth_check_failed');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAuthenticated(AuthResult result) async {
    await _authStore.saveToken(result.token);
    if (!mounted) return;

    setState(() {
      _token = result.token;
      _user = result.user;
      _errorMessage = null;
    });
  }

  Future<void> _logout() async {
    final token = _token;

    if (token != null) {
      try {
        await _authService.logout(token);
      } catch (_) {
        // Local logout must still work even if the backend is unavailable.
      }
    }

    await _authStore.clear();
    await _gameSessionStore.clear();

    if (!mounted) return;
    setState(() {
      _token = null;
      _user = null;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final languageController = LanguageScope.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final user = _user;
    if (user != null && _token != null) {
      return AppStartupScreen(
        user: user,
        onLogout: _logout,
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded, size: 58),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _restoreSession,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(context.tr('retry')),
                  ),
                  TextButton(
                    onPressed: () async {
                      await _authStore.clear();
                      await _gameSessionStore.clear();
                      if (!mounted) return;
                      setState(() {
                        _token = null;
                        _user = null;
                        _errorMessage = null;
                      });
                    },
                    child: Text(context.tr('login_again')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (!languageController.hasSelectedLanguage) {
      return LanguageSelectionScreen(
        onSelected: languageController.setLanguage,
      );
    }

    return AuthScreen(onAuthenticated: _handleAuthenticated);
  }
}
