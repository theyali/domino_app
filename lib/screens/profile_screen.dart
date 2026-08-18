import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../localization/app_language.dart';
import '../localization/app_localizations.dart';
import '../localization/profile_strings.dart';
import '../models/user_account.dart';
import '../models/user_gender.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/auth_session_store.dart';
import '../theme/app_colors.dart';
import '../theme/gender_style.dart';
import '../widgets/cartoon_page_background.dart';
import 'purchased_gifts_screen.dart';

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

  UserGender? _selectedGender;
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
    _selectedGender = _user.gender;
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
    _selectedGender = user.gender;
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
      setState(() => _pickedAvatarPath = cropped.path);
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
    final gender = _selectedGender;

    if (firstName.isEmpty || username.isEmpty || email.isEmpty) {
      _showMessage(strings.fillFields);
      return;
    }

    if (gender == null) {
      _showMessage(
        context.appLanguage.code == 'az' ? 'Cinsini seç.' : 'Выбери пол.',
      );
      return;
    }

    final token = await _authStore.loadToken();
    if (!mounted) return;
    if (token == null) {
      _showMessage(strings.tokenMissing);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final updated = await _authService.updateProfile(
        token: token,
        username: username,
        email: email,
        firstName: firstName,
        gender: gender,
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
      setState(() => _isSaving = false);
      _showMessage(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
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

    setState(() => _usernameCopied = true);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() => _usernameCopied = false);
  }

  Future<void> _openPurchasedGifts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const PurchasedGiftsScreen(),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _ProfilePalette.border),
    );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: _ProfilePalette.muted,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: Icon(icon, color: _ProfilePalette.blue),
      filled: true,
      fillColor: _ProfilePalette.surface,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(
          color: _ProfilePalette.blue,
          width: 1.5,
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
    final isAz = context.appLanguage.code == 'az';

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CartoonPageBackground(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 34),
            children: [
              _buildProfileHeader(strings),
              const SizedBox(height: 20),
              _SitePanel(
                assetPath: 'assets/ui/block_1.webp',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const _SiteIconBadge(icon: Icons.manage_accounts_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.editProfile,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _firstNameController,
                      enabled: !_isSaving,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _fieldDecoration(
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
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _fieldDecoration(
                        label: strings.username,
                        icon: Icons.alternate_email_rounded,
                      ),
                    ),
                    const SizedBox(height: 11),
                    _ProfileGenderSelector(
                      selected: _selectedGender,
                      enabled: !_isSaving,
                      isAzerbaijani: isAz,
                      onSelected: (gender) {
                        setState(() => _selectedGender = gender);
                      },
                    ),
                    const SizedBox(height: 11),
                    TextField(
                      controller: _emailController,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: _fieldDecoration(
                        label: strings.email,
                        icon: Icons.mail_outline_rounded,
                      ),
                      onSubmitted: (_) => _saveProfile(),
                    ),
                    const SizedBox(height: 15),
                    _SiteActionButton(
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
                                    color: Colors.white,
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
              const SizedBox(height: 14),
              _SitePanel(
                assetPath: 'assets/ui/long_2.webp',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const _SiteIconBadge(icon: Icons.language_rounded),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.tr('language'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                context.tr('language_description'),
                                style: const TextStyle(
                                  color: _ProfilePalette.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
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
                        const SizedBox(width: 9),
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
              const SizedBox(height: 14),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _openPurchasedGifts,
                child: _SitePanel(
                  assetPath: 'assets/ui/long_3.webp',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 15,
                  ),
                  child: Row(
                    children: [
                      const _SiteIconBadge(icon: Icons.shopping_bag_rounded),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isAz ? 'Alınmış hədiyyələr' : 'Купленные подарки',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isAz
                                  ? 'Alış tarixçəsi və hədiyyə etmək üçün qalanlar'
                                  : 'История расходов и подарки, которые можно подарить',
                              style: const TextStyle(
                                color: _ProfilePalette.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _SiteActionButton(
                color: _ProfilePalette.surface,
                borderColor: _ProfilePalette.border,
                onPressed: _isSaving ? null : widget.onLogout,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout_rounded, size: 21),
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
    final genderColor = GenderStyle.colorFor(
      _user.gender,
      fallback: Colors.white,
    );
    final letter = _user.displayName.trim().isEmpty
        ? '?'
        : _user.displayName.trim().substring(0, 1).toUpperCase();

    Widget avatarContent;
    if (avatarPath != null) {
      avatarContent = Image.file(
        File(avatarPath),
        fit: BoxFit.cover,
        width: 108,
        height: 108,
        filterQuality: FilterQuality.high,
      );
    } else if (avatarUrl != null && avatarUrl.isNotEmpty) {
      avatarContent = Image.network(
        avatarUrl,
        fit: BoxFit.cover,
        width: 108,
        height: 108,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) =>
            _AvatarLetter(letter: letter, color: genderColor),
      );
    } else {
      avatarContent = _AvatarLetter(letter: letter, color: genderColor);
    }

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 124,
              height: 124,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _ProfilePalette.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _ProfilePalette.blue,
                  width: 3,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(child: avatarContent),
            ),
            Positioned(
              right: 0,
              bottom: 3,
              child: GestureDetector(
                onTap: _isSaving ? null : _pickAvatar,
                child: Container(
                  width: 39,
                  height: 39,
                  decoration: const BoxDecoration(
                    color: _ProfilePalette.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.photo_camera_rounded,
                    color: Colors.white,
                    size: 20,
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: _ProfilePalette.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _ProfilePalette.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_library_outlined,
                  size: 18,
                  color: _ProfilePalette.blue,
                ),
                const SizedBox(width: 7),
                Text(
                  strings.chooseFromGallery,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 13),
        Text(
          _user.displayName,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: genderColor,
            fontSize: 24,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 9),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _copyUsername,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _usernameCopied
                  ? _ProfilePalette.blue
                  : _ProfilePalette.surface,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _usernameCopied
                    ? _ProfilePalette.blue
                    : _ProfilePalette.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _usernameCopied
                      ? Icons.check_rounded
                      : Icons.content_copy_rounded,
                  size: 17,
                  color: _usernameCopied ? Colors.white : _ProfilePalette.blue,
                ),
                const SizedBox(width: 7),
                Text(
                  '@${_user.username}',
                  style: TextStyle(
                    color: _usernameCopied ? Colors.white : genderColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileGenderSelector extends StatelessWidget {
  final UserGender? selected;
  final bool enabled;
  final bool isAzerbaijani;
  final ValueChanged<UserGender> onSelected;

  const _ProfileGenderSelector({
    required this.selected,
    required this.enabled,
    required this.isAzerbaijani,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: _ProfilePalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ProfilePalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Text(
              isAzerbaijani ? 'Cins' : 'Пол',
              style: const TextStyle(
                color: _ProfilePalette.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              for (final gender in UserGender.values) ...[
                Expanded(
                  child: _ProfileGenderChoice(
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

class _ProfileGenderChoice extends StatelessWidget {
  final UserGender gender;
  final bool selected;
  final bool enabled;
  final bool isAzerbaijani;
  final VoidCallback onTap;

  const _ProfileGenderChoice({
    required this.gender,
    required this.selected,
    required this.enabled,
    required this.isAzerbaijani,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = GenderStyle.colorFor(gender);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          decoration: BoxDecoration(
            color: selected
                ? _ProfilePalette.blue
                : _ProfilePalette.surfaceRaised,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? _ProfilePalette.blue : _ProfilePalette.border,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                gender == UserGender.male
                    ? Icons.male_rounded
                    : Icons.female_rounded,
                color: selected ? Colors.white : color,
                size: 20,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  gender.label(isAzerbaijani: isAzerbaijani),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : color,
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

class _SitePanel extends StatelessWidget {
  final String assetPath;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SitePanel({
    required this.assetPath,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _ProfilePalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _ProfilePalette.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 18,
            offset: Offset(0, 8),
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
                  const ColoredBox(color: _ProfilePalette.surface),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _SiteActionButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color color;
  final Color? borderColor;

  const _SiteActionButton({
    required this.onPressed,
    required this.child,
    this.color = _ProfilePalette.blue,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
            border: borderColor == null ? null : Border.all(color: borderColor!),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
            child: IconTheme(
              data: const IconThemeData(color: Colors.white),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _SiteIconBadge extends StatelessWidget {
  final IconData icon;

  const _SiteIconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: _ProfilePalette.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _ProfilePalette.border),
      ),
      child: Icon(icon, color: Colors.white, size: 22),
    );
  }
}

class _AvatarLetter extends StatelessWidget {
  final String letter;
  final Color color;

  const _AvatarLetter({required this.letter, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _ProfilePalette.surface,
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: color,
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
      onTap: () => onPressed(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: selected
              ? _ProfilePalette.blue
              : _ProfilePalette.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected ? _ProfilePalette.blue : _ProfilePalette.border,
          ),
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
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 5),
              const Icon(
                Icons.check_rounded,
                size: 18,
                color: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

abstract final class _ProfilePalette {
  static const Color surface = Color(0xFF262628);
  static const Color surfaceRaised = Color(0xFF303033);
  static const Color border = Color(0xFF3A3A3E);
  static const Color blue = Color(0xFF106CFF);
  static const Color muted = Color(0xFFA7A7AD);
}
