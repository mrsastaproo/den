import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/profile_service.dart';
import '../../core/theme/app_theme.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});
  @override
  ConsumerState<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  final _nameFocus = FocusNode();
  final _picker    = ImagePicker();
  File? _image;
  bool _loading    = false;
  bool _nameChanged = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).value;
    _nameCtrl = TextEditingController(
        text: user?.displayName ?? '');
    _nameCtrl.addListener(() {
      final changed =
          _nameCtrl.text.trim() != (user?.displayName ?? '');
      if (changed != _nameChanged) {
        setState(() => _nameChanged = changed);
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  bool get _hasChanges => _nameChanged || _image != null;

  Future<void> _pickImage(ImageSource src) async {
    try {
      final picked = await _picker.pickImage(
        source: src,
        maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (picked != null) {
        setState(() => _image = File(picked.path));
      }
    } catch (e) {
      _snack('Could not pick image: $e');
    }
  }

  Future<void> _save() async {
    // Validate name
    if (_nameChanged && _nameCtrl.text.trim().isEmpty) {
      setState(() => _nameError = 'Name cannot be empty');
      return;
    }
    setState(() { _loading = true; _nameError = null; });
    HapticFeedback.mediumImpact();

    final profile = ref.read(profileServiceProvider);
    bool ok = true;

    if (_nameChanged && _nameCtrl.text.trim().isNotEmpty) {
      ok = await profile.updateDisplayName(
          _nameCtrl.text.trim());
    }

    if (_image != null) {
      final url = await profile.uploadProfilePhoto(_image!);
      if (url == null) ok = false;
    }

    setState(() => _loading = false);

    if (ok) {
      _snack('Profile updated âœ…');
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) Navigator.pop(context, true);
    } else {
      _snack('Something went wrong. Try again.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.black.withOpacity(0.85),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _showPhotoSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28)),
              border: Border.all(
                  color: Colors.white.withOpacity(0.08))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text('Update Photo',
                  style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                _PhotoOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  colors: [AppTheme.pink, AppTheme.pinkDeep],
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                _PhotoOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Choose from Gallery',
                  colors: [AppTheme.purple, AppTheme.purpleDeep],
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_image != null || 
                    (ref.read(authStateProvider).value?.photoURL?.isNotEmpty ?? false)) ...[
                  const SizedBox(height: 10),
                  _PhotoOption(
                    icon: Icons.delete_rounded,
                    label: 'Remove Photo',
                    colors: [Colors.red.shade400, Colors.red.shade600],
                    onTap: () {
                      setState(() => _image = null);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(children: [

          // Subtle gradient bg
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.pink.withOpacity(0.08),
                  Colors.black,
                  Colors.black,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(children: [

              // â”€â”€ Top Bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white.withOpacity(0.7)),
                      onPressed: () => Navigator.pop(context)),
                    const Text('Edit Profile',
                      style: TextStyle(color: Colors.white,
                        fontSize: 18, fontWeight: FontWeight.w700)),
                    // Save button
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: _hasChanges ? 1.0 : 0.3,
                      child: GestureDetector(
                        onTap: _hasChanges && !_loading ? _save : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: _hasChanges
                                ? AppTheme.primaryGradient : null,
                            color: _hasChanges
                                ? null : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: _hasChanges ? [
                              BoxShadow(
                                color: AppTheme.pink.withOpacity(0.35),
                                blurRadius: 12, spreadRadius: -3),
                            ] : null,
                          ),
                          child: _loading
                              ? const SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                              : const Text('Save',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // â”€â”€ Avatar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      Center(
                        child: GestureDetector(
                          onTap: _showPhotoSheet,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow ring
                              Container(
                                width: 110, height: 110,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.pink.withOpacity(0.4),
                                      blurRadius: 24, spreadRadius: -4),
                                  ],
                                ),
                              ),
                              // Avatar
                              ClipOval(
                                child: SizedBox(
                                  width: 104, height: 104,
                                  child: _image != null
                                      ? Image.file(_image!, fit: BoxFit.cover)
                                      : (user?.photoURL?.isNotEmpty ?? false)
                                          ? CachedNetworkImage(
                                              imageUrl: user!.photoURL!,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  _AvatarPlaceholder(user: user))
                                          : _AvatarPlaceholder(user: user),
                                ),
                              ),
                              // Camera overlay
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  width: 32, height: 32,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.primaryGradient,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.black, width: 2)),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      color: Colors.white, size: 15)),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(duration: 400.ms)
                          .scale(begin: const Offset(0.9, 0.9),
                            duration: 400.ms, curve: Curves.easeOutBack),

                      const SizedBox(height: 6),
                      Center(
                        child: Text('Tap to change photo',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 12)),
                      ),

                      const SizedBox(height: 32),

                      // â”€â”€ Name field â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      _FieldLabel(label: 'DISPLAY NAME'),
                      const SizedBox(height: 8),
                      _InputField(
                        controller: _nameCtrl,
                        focusNode: _nameFocus,
                        hint: 'Your name',
                        icon: Icons.person_outline_rounded,
                        error: _nameError,
                        suffix: _nameChanged
                            ? GestureDetector(
                                onTap: () {
                                  _nameCtrl.text =
                                      user?.displayName ?? '';
                                  setState(() {
                                    _nameChanged = false;
                                    _nameError = null;
                                  });
                                },
                                child: Icon(Icons.close_rounded,
                                  color: Colors.white.withOpacity(0.4),
                                  size: 18))
                            : null,
                      ).animate().fadeIn(delay: 100.ms, duration: 350.ms)
                          .slideY(begin: 0.05, end: 0, delay: 100.ms),

                      const SizedBox(height: 20),

                      // â”€â”€ Email (read-only) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      _FieldLabel(label: 'EMAIL'),
                      const SizedBox(height: 8),
                      _InputField(
                        controller: TextEditingController(
                            text: user?.email ?? ''),
                        hint: 'Email',
                        icon: Icons.email_outlined,
                        readOnly: true,
                        suffix: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8)),
                          child: Text('Verified',
                            style: TextStyle(
                              color: Colors.green.shade400,
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                      ).animate().fadeIn(delay: 150.ms, duration: 350.ms),

                      const SizedBox(height: 20),

                      // â”€â”€ Account info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      _FieldLabel(label: 'ACCOUNT'),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.08))),
                            child: Column(children: [
                              _InfoRow(
                                icon: Icons.calendar_today_rounded,
                                label: 'Member since',
                                value: user?.metadata.creationTime != null
                                    ? _formatDate(
                                        user!.metadata.creationTime!)
                                    : 'Unknown'),
                              Divider(height: 1,
                                  color: Colors.white.withOpacity(0.05)),
                              _InfoRow(
                                icon: Icons.login_rounded,
                                label: 'Last sign in',
                                value: user?.metadata.lastSignInTime != null
                                    ? _formatDate(
                                        user!.metadata.lastSignInTime!)
                                    : 'Unknown'),
                              Divider(height: 1,
                                  color: Colors.white.withOpacity(0.05)),
                              _InfoRow(
                                icon: Icons.badge_rounded,
                                label: 'User ID',
                                value: (user?.uid ?? '').length > 12
                                    ? '${user!.uid.substring(0, 12)}...'
                                    : (user?.uid ?? 'â€”')),
                            ]),
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 350.ms),

                      const SizedBox(height: 32),

                      // â”€â”€ Danger zone â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
                      _DangerZone(),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}

// â”€â”€â”€ AVATAR PLACEHOLDER â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _AvatarPlaceholder extends StatelessWidget {
  final dynamic user;
  const _AvatarPlaceholder({this.user});

  @override
  Widget build(BuildContext context) {
    final letter = (user?.email?.isNotEmpty ?? false)
        ? user!.email![0].toUpperCase()
        : 'D';
    return Container(
      color: AppTheme.bgTertiary,
      child: Center(
        child: Text(letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800))));
  }
}

// â”€â”€â”€ FIELD LABEL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label,
      style: TextStyle(
        color: Colors.white.withOpacity(0.4),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5));
  }
}

// â”€â”€â”€ INPUT FIELD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _InputField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final bool readOnly;
  final Widget? suffix;
  final String? error;

  const _InputField({
    required this.controller,
    this.focusNode,
    required this.hint,
    required this.icon,
    this.readOnly = false,
    this.suffix,
    this.error,
  });

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode?.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode!.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasErr = widget.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasErr
                  ? Colors.red.withOpacity(0.5)
                  : _focused
                      ? AppTheme.pink.withOpacity(0.45)
                      : Colors.white.withOpacity(0.08),
              width: _focused || hasErr ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.white.withOpacity(
                    widget.readOnly ? 0.02 : _focused ? 0.06 : 0.04),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  readOnly: widget.readOnly,
                  style: TextStyle(
                    color: widget.readOnly
                        ? Colors.white.withOpacity(0.4)
                        : Colors.white,
                    fontSize: 15),
                  cursorColor: AppTheme.pink,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.25),
                      fontSize: 15),
                    prefixIcon: ShaderMask(
                      shaderCallback: (b) => (_focused
                              ? AppTheme.primaryGradient
                              : LinearGradient(colors: [
                                  Colors.white.withOpacity(0.3),
                                  Colors.white.withOpacity(0.3),
                                ]))
                          .createShader(b),
                      child: Icon(widget.icon,
                          color: Colors.white, size: 20)),
                    suffixIcon: widget.suffix != null
                        ? Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: widget.suffix)
                        : null,
                    suffixIconConstraints: const BoxConstraints(),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (hasErr)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 5),
            child: Text(widget.error!,
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 12, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}

// â”€â”€â”€ INFO ROW â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Icon(icon, color: Colors.white.withOpacity(0.35), size: 18),
        const SizedBox(width: 12),
        Text(label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 13)),
        const Spacer(),
        Text(value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// â”€â”€â”€ PHOTO OPTION â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PhotoOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const _PhotoOption({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            colors[0].withOpacity(0.15),
            colors[1].withOpacity(0.08),
          ]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: colors[0].withOpacity(0.25))),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 18)),
          const SizedBox(width: 12),
          Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
            color: Colors.white.withOpacity(0.3), size: 18),
        ]),
      ),
    );
  }
}

// â”€â”€â”€ DANGER ZONE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _DangerZone extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DANGER ZONE',
          style: TextStyle(
            color: Colors.red.withOpacity(0.55),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _showDeleteDialog(context, ref),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.red.withOpacity(0.1),
                Colors.red.withOpacity(0.05),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: Colors.red.withOpacity(0.2))),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_forever_rounded,
                    color: Colors.red, size: 18)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Delete Account',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                    Text('Permanently remove your account and all data',
                      style: TextStyle(
                        color: Colors.red, fontSize: 11),
                      overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                color: Colors.red.withOpacity(0.4), size: 18),
            ]),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms, duration: 350.ms);
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.85),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: Colors.white.withOpacity(0.08))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.15),
                        shape: BoxShape.circle),
                      child: const Icon(Icons.warning_rounded,
                          color: Colors.red, size: 20)),
                    const SizedBox(width: 12),
                    const Text('Delete Account',
                      style: TextStyle(color: Colors.white,
                        fontSize: 18, fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 14),
                  Text(
                    'This will permanently delete your account, '
                    'playlists, liked songs, and all history.\n\n'
                    'This action cannot be undone.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14, height: 1.5)),
                  const SizedBox(height: 24),
                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(14)),
                          child: const Center(
                            child: Text('Cancel',
                              style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          Navigator.pop(context);
                          final ok = await ref
                              .read(profileServiceProvider)
                              .deleteAccount();
                          if (ok && context.mounted) {
                            Navigator.of(context)
                                .popUntil((r) => r.isFirst);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 13),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [
                              Color(0xFFFF4444),
                              Color(0xFFCC0000),
                            ]),
                            borderRadius: BorderRadius.circular(14)),
                          child: const Center(
                            child: Text('Delete',
                              style: TextStyle(color: Colors.white,
                                fontWeight: FontWeight.w700))),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
