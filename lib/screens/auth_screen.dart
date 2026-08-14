import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  final Future<void> Function(AuthResult result) onAuthenticated;

  const AuthScreen({
    super.key,
    required this.onAuthenticated,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  static const AuthService _authService = AuthService();

  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();

  bool _isRegister = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Заполни имя пользователя и пароль.';
      });
      return;
    }

    if (_isRegister && email.isEmpty) {
      setState(() {
        _errorMessage = 'Укажи email.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = _isRegister
          ? await _authService.register(
              username: username,
              email: email,
              password: password,
              passwordConfirm: passwordConfirm,
            )
          : await _authService.login(
              username: username,
              password: password,
            );

      if (!mounted) return;
      await widget.onAuthenticated(result);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Не удалось подключиться к серверу.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.casino_rounded,
                    size: 58,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Domino APP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isRegister
                        ? 'Создай аккаунт, чтобы играть и хранить подарки.'
                        : 'Войди в аккаунт, чтобы продолжить.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 28),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        label: Text('Вход'),
                        icon: Icon(Icons.login_rounded),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text('Регистрация'),
                        icon: Icon(Icons.person_add_alt_1_rounded),
                      ),
                    ],
                    selected: {_isRegister},
                    onSelectionChanged: _isSubmitting
                        ? null
                        : (selection) {
                            setState(() {
                              _isRegister = selection.first;
                              _errorMessage = null;
                            });
                          },
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _usernameController,
                    enabled: !_isSubmitting,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Имя пользователя',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_isRegister) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _emailController,
                      enabled: !_isSubmitting,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    enabled: !_isSubmitting,
                    obscureText: _obscurePassword,
                    textInputAction:
                        _isRegister ? TextInputAction.next : TextInputAction.done,
                    onSubmitted: (_) {
                      if (!_isRegister) _submit();
                    },
                    decoration: InputDecoration(
                      labelText: 'Пароль',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (_isRegister) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordConfirmController,
                      enabled: !_isSubmitting,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: const InputDecoration(
                        labelText: 'Повтори пароль',
                        prefixIcon: Icon(Icons.lock_reset_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isRegister ? 'Создать аккаунт' : 'Войти',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                  ),
                  if (_isRegister) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Пароль должен содержать минимум 8 символов.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
