import 'package:flutter/material.dart';

import '../localization/app_language.dart';
import '../localization/app_localizations.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sound_effects_service.dart';
import '../widgets/cartoon_page_background.dart';

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

  Future<void> _openLanguagePicker() async {
    SoundEffectsService.button(alternate: true);
    final controller = LanguageScope.of(context);
    final selected = await showModalBottomSheet<AppLanguage>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (sheetContext) => _AuthLanguagePickerSheet(
        current: controller.language,
      ),
    );

    if (selected == null || selected == controller.language) return;
    await controller.setLanguage(selected);
  }

  void _changeMode(bool register) {
    if (_isSubmitting || _isRegister == register) return;
    SoundEffectsService.button(alternate: true);
    setState(() {
      _isRegister = register;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordConfirm = _passwordConfirmController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = context.tr('fill_username_password');
      });
      return;
    }

    if (_isRegister && email.isEmpty) {
      setState(() {
        _errorMessage = context.tr('enter_email');
      });
      return;
    }

    SoundEffectsService.button();
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
        _errorMessage = context.tr('server_connection_failed');
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
    final language = context.appLanguage;

    return CartoonPageBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 10,
                left: 14,
                child: _AuthLanguageButton(
                  language: language,
                  onTap: _openLanguagePicker,
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 82, 18, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 44),
                          padding: const EdgeInsets.fromLTRB(18, 64, 18, 22),
                          decoration: BoxDecoration(
                            color: _AuthPalette.yellow,
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(
                              color: _AuthPalette.ink,
                              width: 3.2,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: _AuthPalette.ink,
                                blurRadius: 0,
                                offset: Offset(7, 9),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                context.tr('app_name'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _AuthPalette.ink,
                                  fontSize: 31,
                                  height: 1,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.7,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                context.tr(
                                  _isRegister
                                      ? 'register_subtitle'
                                      : 'login_subtitle',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: _AuthPalette.inkSoft,
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 18),
                              _AuthModeSwitcher(
                                isRegister: _isRegister,
                                enabled: !_isSubmitting,
                                loginLabel: context.tr('login'),
                                registerLabel: context.tr('register'),
                                onChanged: _changeMode,
                              ),
                              const SizedBox(height: 18),
                              _CartoonAuthField(
                                controller: _usernameController,
                                enabled: !_isSubmitting,
                                hintText: context.tr('username'),
                                icon: Icons.person_outline_rounded,
                                accent: _AuthPalette.skyBlue,
                                textInputAction: TextInputAction.next,
                              ),
                              if (_isRegister) ...[
                                const SizedBox(height: 12),
                                _CartoonAuthField(
                                  controller: _emailController,
                                  enabled: !_isSubmitting,
                                  hintText: context.tr('email'),
                                  icon: Icons.mail_outline_rounded,
                                  accent: _AuthPalette.coral,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                ),
                              ],
                              const SizedBox(height: 12),
                              _CartoonAuthField(
                                controller: _passwordController,
                                enabled: !_isSubmitting,
                                hintText: context.tr('password'),
                                icon: Icons.lock_outline_rounded,
                                accent: _AuthPalette.mint,
                                obscureText: _obscurePassword,
                                textInputAction: _isRegister
                                    ? TextInputAction.next
                                    : TextInputAction.done,
                                onSubmitted: (_) {
                                  if (!_isRegister) _submit();
                                },
                                suffix: IconButton(
                                  onPressed: _isSubmitting
                                      ? null
                                      : () {
                                          setState(() {
                                            _obscurePassword =
                                                !_obscurePassword;
                                          });
                                        },
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_rounded
                                        : Icons.visibility_off_rounded,
                                    color: _AuthPalette.ink,
                                  ),
                                ),
                              ),
                              if (_isRegister) ...[
                                const SizedBox(height: 12),
                                _CartoonAuthField(
                                  controller: _passwordConfirmController,
                                  enabled: !_isSubmitting,
                                  hintText: context.tr('confirm_password'),
                                  icon: Icons.lock_reset_rounded,
                                  accent: _AuthPalette.cream,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => _submit(),
                                ),
                              ],
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 13),
                                _AuthErrorCard(message: _errorMessage!),
                              ],
                              const SizedBox(height: 18),
                              _CartoonSubmitButton(
                                isLoading: _isSubmitting,
                                label: context.tr(
                                  _isRegister ? 'create_account' : 'login',
                                ),
                                icon: _isRegister
                                    ? Icons.person_add_alt_1_rounded
                                    : Icons.login_rounded,
                                onTap: _isSubmitting ? null : _submit,
                              ),
                              if (_isRegister) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _AuthPalette.cream,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _AuthPalette.ink,
                                      width: 2.1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.info_outline_rounded,
                                        color: _AuthPalette.ink,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 7),
                                      Expanded(
                                        child: Text(
                                          context.tr('password_min_8'),
                                          style: const TextStyle(
                                            color: _AuthPalette.inkSoft,
                                            fontSize: 11,
                                            height: 1.3,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Positioned(
                          top: 0,
                          child: Transform.rotate(
                            angle: -0.04,
                            child: Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                color: _AuthPalette.lime,
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: _AuthPalette.ink,
                                  width: 3.2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: _AuthPalette.ink,
                                    blurRadius: 0,
                                    offset: Offset(5, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.casino_rounded,
                                color: _AuthPalette.ink,
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
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthModeSwitcher extends StatelessWidget {
  final bool isRegister;
  final bool enabled;
  final String loginLabel;
  final String registerLabel;
  final ValueChanged<bool> onChanged;

  const _AuthModeSwitcher({
    required this.isRegister,
    required this.enabled,
    required this.loginLabel,
    required this.registerLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AuthModeButton(
            selected: !isRegister,
            enabled: enabled,
            accent: _AuthPalette.skyBlue,
            icon: Icons.login_rounded,
            label: loginLabel,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AuthModeButton(
            selected: isRegister,
            enabled: enabled,
            accent: _AuthPalette.coral,
            icon: Icons.person_add_alt_1_rounded,
            label: registerLabel,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _AuthModeButton extends StatelessWidget {
  final bool selected;
  final bool enabled;
  final Color accent;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AuthModeButton({
    required this.selected,
    required this.enabled,
    required this.accent,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 58,
          decoration: BoxDecoration(
            color: selected ? accent : _AuthPalette.cream,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _AuthPalette.ink, width: 2.7),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: _AuthPalette.ink,
                      blurRadius: 0,
                      offset: Offset(4, 5),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _AuthPalette.ink, size: 21),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _AuthPalette.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.check_circle_rounded,
                  color: _AuthPalette.ink,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CartoonAuthField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final IconData icon;
  final Color accent;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autocorrect;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _CartoonAuthField({
    required this.controller,
    required this.enabled,
    required this.hintText,
    required this.icon,
    required this.accent,
    this.keyboardType,
    this.textInputAction,
    this.autocorrect = true,
    this.obscureText = false,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(19)),
        boxShadow: [
          BoxShadow(
            color: _AuthPalette.ink,
            blurRadius: 0,
            offset: Offset(4, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        autocorrect: autocorrect,
        obscureText: obscureText,
        onSubmitted: onSubmitted,
        cursorColor: _AuthPalette.ink,
        style: const TextStyle(
          color: _AuthPalette.ink,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: _AuthPalette.cream,
          hintText: hintText,
          hintStyle: const TextStyle(
            color: _AuthPalette.inkSoft,
            fontWeight: FontWeight.w700,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 64),
          prefixIcon: Padding(
            padding: const EdgeInsets.fromLTRB(7, 6, 8, 6),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _AuthPalette.ink, width: 2.5),
              ),
              child: Icon(icon, color: _AuthPalette.ink, size: 24),
            ),
          ),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 19,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide: const BorderSide(
              color: _AuthPalette.ink,
              width: 2.8,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide: const BorderSide(
              color: _AuthPalette.ink,
              width: 3.4,
            ),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(19),
            borderSide: BorderSide(
              color: _AuthPalette.ink.withValues(alpha: 0.5),
              width: 2.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _CartoonSubmitButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _CartoonSubmitButton({
    required this.isLoading,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.58 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: _AuthPalette.lime,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _AuthPalette.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: _AuthPalette.ink,
                blurRadius: 0,
                offset: Offset(5, 6),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: _AuthPalette.ink,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: _AuthPalette.ink, size: 24),
                      const SizedBox(width: 9),
                      Text(
                        label,
                        style: const TextStyle(
                          color: _AuthPalette.ink,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _AuthErrorCard extends StatelessWidget {
  final String message;

  const _AuthErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _AuthPalette.coral,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _AuthPalette.ink, width: 2.4),
        boxShadow: const [
          BoxShadow(
            color: _AuthPalette.ink,
            blurRadius: 0,
            offset: Offset(3, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _AuthPalette.ink),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _AuthPalette.ink,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthLanguageButton extends StatelessWidget {
  final AppLanguage language;
  final VoidCallback onTap;

  const _AuthLanguageButton({
    required this.language,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _AuthPalette.cream,
          shape: BoxShape.circle,
          border: Border.all(color: _AuthPalette.ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: _AuthPalette.ink,
              blurRadius: 0,
              offset: Offset(4, 5),
            ),
          ],
        ),
        child: Text(
          language.flag,
          style: const TextStyle(fontSize: 27, height: 1),
        ),
      ),
    );
  }
}

class _AuthLanguagePickerSheet extends StatelessWidget {
  final AppLanguage current;

  const _AuthLanguagePickerSheet({required this.current});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: _AuthPalette.yellow,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _AuthPalette.ink, width: 3),
          boxShadow: const [
            BoxShadow(
              color: _AuthPalette.ink,
              blurRadius: 0,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: _AuthPalette.ink,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              current == AppLanguage.az ? 'Dili seç' : 'Выбери язык',
              style: const TextStyle(
                color: _AuthPalette.ink,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            for (final language in AppLanguage.values) ...[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  SoundEffectsService.button(alternate: true);
                  Navigator.pop(context, language);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: language == current
                        ? _AuthPalette.lime
                        : _AuthPalette.cream,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _AuthPalette.ink, width: 3),
                    boxShadow: const [
                      BoxShadow(
                        color: _AuthPalette.ink,
                        blurRadius: 0,
                        offset: Offset(3, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        language.flag,
                        style: const TextStyle(fontSize: 27),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          language.label,
                          style: const TextStyle(
                            color: _AuthPalette.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (language == current)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: _AuthPalette.ink,
                          size: 25,
                        ),
                    ],
                  ),
                ),
              ),
              if (language != AppLanguage.values.last)
                const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

abstract final class _AuthPalette {
  static const ink = Color(0xFF17120D);
  static const inkSoft = Color(0xFF66564A);
  static const cream = Color(0xFFFFF3D7);
  static const yellow = Color(0xFFFFD85A);
  static const lime = Color(0xFF79FA00);
  static const skyBlue = Color(0xFF74C9F1);
  static const coral = Color(0xFFFF7D72);
  static const mint = Color(0xFF88DB78);
}
