import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../localization/app_language.dart';
import '../localization/app_localizations.dart';
import '../models/user_gender.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/sound_effects_service.dart';
import '../theme/gender_style.dart';
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

  UserGender? _selectedGender;
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

  void _selectGender(UserGender gender) {
    if (_isSubmitting) return;
    SoundEffectsService.button(alternate: true);
    setState(() {
      _selectedGender = gender;
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

    if (_isRegister && _selectedGender == null) {
      setState(() {
        _errorMessage = context.appLanguage.code == 'az'
            ? 'Cinsini seç.'
            : 'Выбери пол.';
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
              gender: _selectedGender!,
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
    final isAz = language.code == 'az';
    final blockAsset = _isRegister
        ? 'assets/ui/block_2.webp'
        : 'assets/ui/block_1.webp';

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
                  padding: const EdgeInsets.fromLTRB(18, 76, 18, 28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: _AuthPanel(
                      assetPath: blockAsset,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _DominoBrand(),
                          const SizedBox(height: 10),
                          Text(
                            context.tr(
                              _isRegister
                                  ? 'register_subtitle'
                                  : 'login_subtitle',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _AuthPalette.muted,
                              fontSize: 13,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          _AuthModeSwitcher(
                            isRegister: _isRegister,
                            enabled: !_isSubmitting,
                            loginLabel: context.tr('login'),
                            registerLabel: context.tr('register'),
                            onChanged: _changeMode,
                          ),
                          const SizedBox(height: 16),
                          _SiteAuthField(
                            controller: _usernameController,
                            enabled: !_isSubmitting,
                            hintText: context.tr('username'),
                            icon: Icons.person_outline_rounded,
                            textInputAction: TextInputAction.next,
                          ),
                          if (_isRegister) ...[
                            const SizedBox(height: 11),
                            _SiteAuthField(
                              controller: _emailController,
                              enabled: !_isSubmitting,
                              hintText: context.tr('email'),
                              icon: Icons.mail_outline_rounded,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                            ),
                            const SizedBox(height: 11),
                            _GenderSelector(
                              selected: _selectedGender,
                              enabled: !_isSubmitting,
                              isAzerbaijani: isAz,
                              onSelected: _selectGender,
                            ),
                          ],
                          const SizedBox(height: 11),
                          _SiteAuthField(
                            controller: _passwordController,
                            enabled: !_isSubmitting,
                            hintText: context.tr('password'),
                            icon: Icons.lock_outline_rounded,
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
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (_isRegister) ...[
                            const SizedBox(height: 11),
                            _SiteAuthField(
                              controller: _passwordConfirmController,
                              enabled: !_isSubmitting,
                              hintText: context.tr('confirm_password'),
                              icon: Icons.lock_reset_rounded,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                            ),
                          ],
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 12),
                            _AuthErrorCard(message: _errorMessage!),
                          ],
                          const SizedBox(height: 17),
                          _SubmitButton(
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
                            const SizedBox(height: 11),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: _AuthPalette.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _AuthPalette.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline_rounded,
                                    color: _AuthPalette.blue,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      context.tr('password_min_8'),
                                      style: const TextStyle(
                                        color: _AuthPalette.muted,
                                        fontSize: 11,
                                        height: 1.3,
                                        fontWeight: FontWeight.w600,
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

class _AuthPanel extends StatelessWidget {
  final String assetPath;
  final Widget child;

  const _AuthPanel({required this.assetPath, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _AuthPalette.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _AuthPalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: _AuthPalette.surface),
            ),
          ),
          const Positioned.fill(
            child: ColoredBox(color: Color(0xB3121212)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _DominoBrand extends StatelessWidget {
  const _DominoBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/ui/logo.svg',
          width: 38,
          height: 38,
        ),
        const SizedBox(width: 10),
        const Text(
          'Domino',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.9,
          ),
        ),
      ],
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
          child: _ModeButton(
            selected: !isRegister,
            enabled: enabled,
            icon: Icons.login_rounded,
            label: loginLabel,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _ModeButton(
            selected: isRegister,
            enabled: enabled,
            icon: Icons.person_add_alt_1_rounded,
            label: registerLabel,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  final bool selected;
  final bool enabled;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ModeButton({
    required this.selected,
    required this.enabled,
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
          height: 52,
          decoration: BoxDecoration(
            color: selected ? _AuthPalette.blue : _AuthPalette.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _AuthPalette.blue : _AuthPalette.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 17,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GenderSelector extends StatelessWidget {
  final UserGender? selected;
  final bool enabled;
  final bool isAzerbaijani;
  final ValueChanged<UserGender> onSelected;

  const _GenderSelector({
    required this.selected,
    required this.enabled,
    required this.isAzerbaijani,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _AuthPalette.surface,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _AuthPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              isAzerbaijani ? 'Cins' : 'Пол',
              style: const TextStyle(
                color: _AuthPalette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final gender in UserGender.values) ...[
                Expanded(
                  child: _GenderChoiceButton(
                    gender: gender,
                    selected: selected == gender,
                    enabled: enabled,
                    isAzerbaijani: isAzerbaijani,
                    onTap: () => onSelected(gender),
                  ),
                ),
                if (gender != UserGender.values.last)
                  const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GenderChoiceButton extends StatelessWidget {
  final UserGender gender;
  final bool selected;
  final bool enabled;
  final bool isAzerbaijani;
  final VoidCallback onTap;

  const _GenderChoiceButton({
    required this.gender,
    required this.selected,
    required this.enabled,
    required this.isAzerbaijani,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = GenderStyle.colorFor(gender);
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 46,
          decoration: BoxDecoration(
            color: selected ? _AuthPalette.blue : _AuthPalette.surfaceRaised,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _AuthPalette.blue : _AuthPalette.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                gender == UserGender.male
                    ? Icons.male_rounded
                    : Icons.female_rounded,
                color: selected ? Colors.white : accent,
                size: 21,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  gender.label(isAzerbaijani: isAzerbaijani),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : accent,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
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

class _SiteAuthField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final String hintText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool autocorrect;
  final bool obscureText;
  final ValueChanged<String>? onSubmitted;
  final Widget? suffix;

  const _SiteAuthField({
    required this.controller,
    required this.enabled,
    required this.hintText,
    required this.icon,
    this.keyboardType,
    this.textInputAction,
    this.autocorrect = true,
    this.obscureText = false,
    this.onSubmitted,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _AuthPalette.border),
    );

    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autocorrect: autocorrect,
      obscureText: obscureText,
      onSubmitted: onSubmitted,
      cursorColor: _AuthPalette.blue,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: _AuthPalette.surface,
        hintText: hintText,
        hintStyle: const TextStyle(
          color: _AuthPalette.muted,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: const SizedBox(width: 52),
        prefixIconConstraints: const BoxConstraints(minWidth: 52),
        prefix: Padding(
          padding: const EdgeInsets.only(right: 9),
          child: Icon(icon, color: _AuthPalette.blue, size: 21),
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: _AuthPalette.blue, width: 1.5),
        ),
        disabledBorder: border,
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _SubmitButton({
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
          height: 54,
          decoration: BoxDecoration(
            color: _AuthPalette.blue,
            borderRadius: BorderRadius.circular(17),
            boxShadow: const [
              BoxShadow(
                color: Color(0x44000000),
                blurRadius: 14,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, color: Colors.white, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
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
        color: const Color(0xFF3A2024),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF66333B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF7E70)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                height: 1.3,
                fontWeight: FontWeight.w700,
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
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _AuthPalette.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _AuthPalette.border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x44000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          language.flag,
          style: const TextStyle(fontSize: 24, height: 1),
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
          color: _AuthPalette.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: _AuthPalette.border),
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
                color: _AuthPalette.muted,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              current == AppLanguage.az ? 'Dili seç' : 'Выбери язык',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 21,
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
                        ? _AuthPalette.blue
                        : _AuthPalette.surfaceRaised,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: language == current
                          ? _AuthPalette.blue
                          : _AuthPalette.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(language.flag, style: const TextStyle(fontSize: 27)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          language.label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (language == current)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 24,
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
  static const background = Color(0xFF121212);
  static const surface = Color(0xFF262628);
  static const surfaceRaised = Color(0xFF303033);
  static const border = Color(0xFF3A3A3E);
  static const blue = Color(0xFF106CFF);
  static const muted = Color(0xFFA7A7AD);
}
