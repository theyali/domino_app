import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_language.dart';
import '../localization/app_localizations.dart';
import '../localization/profile_strings.dart';
import '../models/user_account.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/auth_session_store.dart';
import '../theme/app_colors.dart';

class ProfileScreen extends StatefulWidget {
  final UserAccount user;
  final ValueChanged<UserAccount> onUserUpdated;
  final Future<void> Function() onLogout;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const AuthService _authService = AuthService();

  final AuthSessionStore _authStore = AuthSessionStore();
  final ImagePicker _imagePicker = ImagePicker();

  late UserAccount _user;
  late final TextEditingController _firstNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;

  XFile? _pickedAvatar;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _firstNameController = TextEditingController(text: _user.firstName);
    _usernameController = TextEditingController(text: _user.username);
    _emailController = TextEditingController(text: _user.email);
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user && !_isSaving) {
      _setUser(widget.user);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _setUser(UserAccount user) {
    _user = user;
    _firstNameController.text = user.firstName;
    _usernameController.text = user.username;
    _emailController.text = user.email;
  }

  Future<void> _pickAvatar() async {
    if (_isSaving) return;

    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _pickedAvatar = picked;
    });
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;

    final strings = ProfileStrings.of(context);
    final firstName = _firstNameController.text.trim();
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();

    if (firstName.isEmpty || username.isEmpty || email.isEmpty) {
      _showMessage(strings.fillFields);
      return;
    }

    final token = await _authStore.loadToken();
    if (!mounted) return;
    if (token == null) {
      _showMessage(strings.tokenMissing);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final updated = await _authService.updateProfile(
        token: token,
        username: username,
        email: email,
        firstName: firstName,
        avatarPath: _pickedAvatar?.path,
      );

      if (!mounted) return;
      setState(() {
        _user = updated;
        _pickedAvatar = null;
        _isSaving = false;
      });
      _setUser(updated);
      widget.onUserUpdated(updated);
      _showMessage(strings.saved);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      _showMessage(strings.saveFailed);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final languageController = LanguageScope.of(context);
    final strings = ProfileStrings.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
        children: [
          _buildProfileHeader(strings),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceRaised,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppColors.brass.withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.editProfile,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _firstNameController,
                  enabled: !_isSaving,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: strings.displayName,
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _usernameController,
                  enabled: !_isSaving,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: strings.username,
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _emailController,
                  enabled: !_isSaving,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: strings.email,
                    prefixIcon: const Icon(Icons.mail_outline_rounded),
                  ),
                  onSubmitted: (_) => _saveProfile(),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _saveProfile,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.3,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      _isSaving ? strings.saving : strings.save,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.language_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.tr('language'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              context.tr('language_description'),
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _LanguageChoiceButton(
                          language: AppLanguage.az,
                          selected:
                              languageController.language == AppLanguage.az,
                          onPressed: () => languageController.setLanguage(
                            AppLanguage.az,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LanguageChoiceButton(
                          language: AppLanguage.ru,
                          selected:
                              languageController.language == AppLanguage.ru,
                          onPressed: () => languageController.setLanguage(
                            AppLanguage.ru,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.card_giftcard_rounded),
              title: Text(context.tr('my_gifts')),
              subtitle: Text(context.tr('inventory_bottom_menu')),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isSaving ? null : widget.onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: Text(context.tr('logout')),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(ProfileStrings strings) {
    final avatar = _pickedAvatar;
    final avatarUrl = _user.avatarUrl;
    final letter = _user.displayName.trim().isEmpty
        ? '?'
        : _user.displayName.trim().substring(0, 1).toUpperCase();

    Widget avatarContent;
    if (avatar != null) {
      avatarContent = Image.file(
        File(avatar.path),
        fit: BoxFit.cover,
        width: 104,
        height: 104,
      );
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarContent = Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        width: 104,
        height: 104,
        errorBuilder: (context, error, stackTrace) => _AvatarLetter(letter: letter),
      );
    } else {
      avatarContent = _AvatarLetter(letter: letter);
    }

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 112,
              height: 112,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.brass,
                  width: 2,
                ),
                color: AppColors.surfaceRaised,
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: ClipOval(child: avatarContent),
            ),
            Positioned(
              right: -3,
              bottom: 3,
              child: Material(
                color: AppColors.lime,
                shape: const CircleBorder(),
                child: InkWell(
                  onTap: _isSaving ? null : _pickAvatar,
                  customBorder: const CircleBorder(),
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.photo_camera_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: _isSaving ? null : _pickAvatar,
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: Text(strings.chooseFromGallery),
        ),
        Text(
          strings.avatarHint,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _user.displayName,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 3),
        Text(
          '@${_user.username}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white54),
        ),
      ],
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
      child: Text(
        letter,
        style: const TextStyle(
          color: Color(0xFF6242A3),
          fontSize: 38,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _LanguageChoiceButton extends StatelessWidget {
  final AppLanguage language;
  final bool selected;
  final Future<void> Function() onPressed;

  const _LanguageChoiceButton({
    required this.language,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(language.flag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            language.label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 5),
          const Icon(Icons.check_rounded, size: 18),
        ],
      ],
    );

    if (selected) {
      return FilledButton.tonal(
        onPressed: onPressed,
        child: child,
      );
    }

    return OutlinedButton(
      onPressed: onPressed,
      child: child,
    );
  }
}
