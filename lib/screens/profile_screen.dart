import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_language.dart';
import '../localization/app_localizations.dart';
import '../localization/profile_strings.dart';
import '../models/user_account.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/auth_session_store.dart';
import '../theme/app_colors.dart';
import '../widgets/cartoon_page_background.dart';
import '../widgets/game_avatar_frame.dart';

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

  String? _pickedAvatarPath;
  bool _isSaving = false;
  bool _usernameCopied = false;

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
      imageQuality: 96,
      maxWidth: 2200,
      maxHeight: 2200,
    );
    if (picked == null || !mounted) return;

    final strings = ProfileStrings.of(context);

    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        maxWidth: 1200,
        maxHeight: 1200,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 92,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: strings.cropAvatar,
            toolbarColor: AppColors.background,
            toolbarWidgetColor: Colors.white,
            backgroundColor: AppColors.background,
            activeControlsWidgetColor: AppColors.lime,
            dimmedLayerColor: Colors.black.withValues(alpha: 0.76),
            cropFrameColor: AppColors.lime,
            cropGridColor: Colors.white38,
            showCropGrid: false,
            lockAspectRatio: true,
            initAspectRatio: CropAspectRatioPreset.square,
            cropStyle: CropStyle.circle,
            aspectRatioPresets: const [
              CropAspectRatioPreset.square,
            ],
          ),
          IOSUiSettings(
            title: strings.cropAvatar,
            doneButtonTitle: strings.useAvatar,
            cancelButtonTitle: strings.cancel,
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
            showCancelConfirmationDialog: false,
            aspectRatioPresets: const [
              CropAspectRatioPreset.square,
            ],
          ),
        ],
      );

      if (cropped == null || !mounted) return;

      setState(() {
        _pickedAvatarPath = cropped.path;
      });
    } catch (_) {
      if (!mounted) return;
      _showMessage(strings.avatarCropFailed);
    }
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
        avatarPath: _pickedAvatarPath,
      );

      if (!mounted) return;
      setState(() {
        _user = updated;
        _pickedAvatarPath = null;
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

  Future<void> _copyUsername() async {
    final username = _user.username.trim();
    if (username.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: '@$username'));
    if (!mounted) return;

    setState(() {
      _usernameCopied = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;

    setState(() {
      _usernameCopied = false;
    });
  }

  InputDecoration _cartoonFieldDecoration({
    required String label,
    required IconData icon,
  }) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(18)),
      borderSide: BorderSide(color: _ProfilePalette.ink, width: 2.6),
    );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: _ProfilePalette.inkSoft,
        fontWeight: FontWeight.w700,
      ),
      prefixIcon: Icon(icon, color: _ProfilePalette.ink),
      filled: true,
      fillColor: _ProfilePalette.cream,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(
          color: _ProfilePalette.ink,
          width: 3.2,
        ),
      ),
      disabledBorder: border,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageController = LanguageScope.of(context);
    final strings = ProfileStrings.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CartoonPageBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
            children: [
              _buildProfileHeader(strings),
              const SizedBox(height: 20),
              _CartoonPanel(
                color: _ProfilePalette.skyBlue,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      strings.editProfile,
                      style: const TextStyle(
                        color: _ProfilePalette.ink,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _firstNameController,
                      enabled: !_isSaving,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        color: _ProfilePalette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _cartoonFieldDecoration(
                        label: strings.displayName,
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: _usernameController,
                      enabled: !_isSaving,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      style: const TextStyle(
                        color: _ProfilePalette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _cartoonFieldDecoration(
                        label: strings.username,
                        icon: Icons.alternate_email_rounded,
                      ),
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: _emailController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      style: const TextStyle(
                        color: _ProfilePalette.ink,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _cartoonFieldDecoration(
                        label: strings.email,
                        icon: Icons.mail_outline_rounded,
                      ),
                      onSubmitted: (_) => _saveProfile(),
                    ),
                    const SizedBox(height: 15),
                    _CartoonActionButton(
                      color: _ProfilePalette.lime,
                      onPressed: _isSaving ? null : _saveProfile,
                      child: _isSaving
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 19,
                                  height: 19,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.3,
                                    color: _ProfilePalette.ink,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(strings.saving),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_rounded, size: 22),
                                const SizedBox(width: 8),
                                Text(strings.save),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _CartoonPanel(
                color: _ProfilePalette.yellow,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _CartoonIconBadge(
                          icon: Icons.language_rounded,
                          color: _ProfilePalette.mint,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('language'),
                                style: const TextStyle(
                                  color: _ProfilePalette.ink,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('language_description'),
                                style: const TextStyle(
                                  color: _ProfilePalette.inkSoft,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
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
              const SizedBox(height: 16),
              _CartoonPanel(
                color: _ProfilePalette.mint,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    const _CartoonIconBadge(
                      icon: Icons.card_giftcard_rounded,
                      color: _ProfilePalette.coral,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr('my_gifts'),
                            style: const TextStyle(
                              color: _ProfilePalette.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            context.tr('inventory_bottom_menu'),
                            style: const TextStyle(
                              color: _ProfilePalette.inkSoft,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _CartoonActionButton(
                color: _ProfilePalette.coral,
                onPressed: _isSaving ? null : widget.onLogout,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, size: 22),
                    const SizedBox(width: 8),
                    Text(context.tr('logout')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ProfileStrings strings) {
    final avatarPath = _pickedAvatarPath;
    final avatarUrl = _user.avatarUrl;
    final letter = _user.displayName.trim().isEmpty
        ? '?'
        : _user.displayName.trim().substring(0, 1).toUpperCase();

    Widget avatarContent;
    if (avatarPath != null) {
      avatarContent = Image.file(
        File(avatarPath),
        fit: BoxFit.cover,
        width: 104,
        height: 104,
        filterQuality: FilterQuality.high,
      );
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarContent = Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        width: 104,
        height: 104,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) =>
            _AvatarLetter(letter: letter),
      );
    } else {
      avatarContent = _AvatarLetter(letter: letter);
    }

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GameAvatarFrame(
              size: 126,
              innerPadding: 15,
              child: avatarContent,
            ),
            Positioned(
              right: -1,
              bottom: 5,
              child: GestureDetector(
                onTap: _isSaving ? null : _pickAvatar,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _ProfilePalette.lime,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _ProfilePalette.ink,
                      width: 2.8,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: _ProfilePalette.ink,
                        blurRadius: 0,
                        offset: Offset(3, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: _ProfilePalette.ink,
                    size: 21,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isSaving ? null : _pickAvatar,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _ProfilePalette.cream,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _ProfilePalette.ink, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: _ProfilePalette.ink,
                  blurRadius: 0,
                  offset: Offset(2, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  size: 18,
                  color: _ProfilePalette.ink,
                ),
                const SizedBox(width: 7),
                Text(
                  strings.chooseFromGallery,
                  style: const TextStyle(
                    color: _ProfilePalette.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _copyUsername,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            scale: _usernameCopied ? 1.06 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: _usernameCopied
                    ? _ProfilePalette.lime
                    : _ProfilePalette.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _ProfilePalette.ink, width: 2.5),
                boxShadow: const [
                  BoxShadow(
                    color: _ProfilePalette.ink,
                    blurRadius: 0,
                    offset: Offset(2, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: child,
                    ),
                    child: Icon(
                      _usernameCopied
                          ? Icons.check_rounded
                          : Icons.content_copy_rounded,
                      key: ValueKey(_usernameCopied),
                      size: 18,
                      color: _ProfilePalette.ink,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    '@${_user.username}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _ProfilePalette.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CartoonPanel extends StatelessWidget {
  final Color color;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _CartoonPanel({
    required this.color,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: _ProfilePalette.ink, width: 3),
        boxShadow: const [
          BoxShadow(
            color: _ProfilePalette.ink,
            blurRadius: 0,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _CartoonActionButton extends StatelessWidget {
  final Color color;
  final VoidCallback? onPressed;
  final Widget child;

  const _CartoonActionButton({
    required this.color,
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _ProfilePalette.ink, width: 3),
            boxShadow: const [
              BoxShadow(
                color: _ProfilePalette.ink,
                blurRadius: 0,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: _ProfilePalette.ink,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
            child: IconTheme(
              data: const IconThemeData(color: _ProfilePalette.ink),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _CartoonIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _CartoonIconBadge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _ProfilePalette.ink, width: 2.6),
      ),
      child: Icon(icon, color: _ProfilePalette.ink, size: 24),
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
    return GestureDetector(
      onTap: () {
        onPressed();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? _ProfilePalette.lime : _ProfilePalette.cream,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: _ProfilePalette.ink, width: 2.7),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: _ProfilePalette.ink,
                    blurRadius: 0,
                    offset: Offset(2, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(language.flag, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                language.label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _ProfilePalette.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: _ProfilePalette.ink,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProfilePalette {
  static const Color ink = Color(0xFF111111);
  static const Color inkSoft = Color(0xFF4A4037);
  static const Color cream = Color(0xFFFFF5D9);
  static const Color skyBlue = Color(0xFF79CDF1);
  static const Color yellow = Color(0xFFFFD65C);
  static const Color mint = Color(0xFF8CDD79);
  static const Color coral = Color(0xFFFF7E70);
  static const Color lime = Color(0xFF7CFC00);
}
