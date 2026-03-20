import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
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
  late TextEditingController _nameController;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isLoading = false;
  bool _nameChanged = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authStateProvider).value;
    _nameController = TextEditingController(
      text: user?.displayName ?? '');
    _nameController.addListener(() {
      setState(() => _nameChanged =
        _nameController.text != (user?.displayName ?? ''));
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (e) {
      _showSnack('Could not pick image');
    }
  }

  Future<void> _saveChanges() async {
    if (!_nameChanged && _selectedImage == null) return;

    setState(() => _isLoading = true);
    final profile = ref.read(profileServiceProvider);
    bool success = true;

    // Update name
    if (_nameChanged && _nameController.text.trim().isNotEmpty) {
      success = await profile.updateDisplayName(
        _nameController.text.trim());
    }

    // Upload photo
    if (_selectedImage != null) {
      final url = await profile.uploadProfilePhoto(_selectedImage!);
      if (url == null) success = false;
    }

    setState(() => _isLoading = false);

    if (success) {
      _showSnack('Profile updated! ✅');
      // Refresh auth state
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) Navigator.pop(context, true);
    } else {
      _showSnack('Something went wrong. Try again.');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFF1E1E1E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.12),
                  Colors.white.withOpacity(0.06),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28)),
              border: Border.all(
                color: Colors.white.withOpacity(0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 20),
                const Text('Choose Photo',
                  style: TextStyle(color: Colors.white,
                    fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                _ImageSourceBtn(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  colors: [AppTheme.pink, AppTheme.pinkDeep],
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 12),
                _ImageSourceBtn(
                  icon: Icons.photo_library_rounded,
                  label: 'Choose from Gallery',
                  colors: [AppTheme.purple, AppTheme.purpleDeep],
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 32),
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
    final hasChanges = _nameChanged || _selectedImage != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.black,
              const Color(0xFF0D0D0D),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white.withOpacity(0.7)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('Edit Profile',
                      style: TextStyle(color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
                    // Save button
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: hasChanges ? 1.0 : 0.3,
                      child: GestureDetector(
                        onTap: hasChanges && !_isLoading
                          ? _saveChanges : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: hasChanges
                              ? AppTheme.primaryGradient : null,
                            color: hasChanges
                              ? null
                              : Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: hasChanges ? [
                              BoxShadow(
                                color: AppTheme.pink
                                  .withOpacity(0.4),
                                blurRadius: 12,
                                spreadRadius: -3),
                            ] : null,
                          ),
                          child: _isLoading
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
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
              ),

              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),

                      // Avatar
                      GestureDetector(
                        onTap: _showImageSourceSheet,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppTheme.primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.pink
                                      .withOpacity(0.4),
                                    blurRadius: 30,
                                    spreadRadius: -5),
                                ],
                              ),
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.transparent,
                                child: _selectedImage != null
                                  ? ClipOval(child: Image.file(
                                      _selectedImage!,
                                      width: 120, height: 120,
                                      fit: BoxFit.cover))
                                  : user?.photoURL != null
                                    ? ClipOval(
                                        child: CachedNetworkImage(
                                          imageUrl: user!.photoURL!,
                                          width: 120, height: 120,
                                          fit: BoxFit.cover))
                                    : Text(
                                        user?.email?.substring(0, 1)
                                          .toUpperCase() ?? 'D',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 48,
                                          fontWeight:
                                            FontWeight.w800)),
                              ),
                            ),
                            // Edit icon
                            Positioned(
                              bottom: 4, right: 4,
                              child: Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  gradient:
                                    AppTheme.primaryGradient,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.black,
                                    width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.pink
                                        .withOpacity(0.4),
                                      blurRadius: 10,
                                      spreadRadius: -2),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ).animate()
                        .scale(begin: const Offset(0.8, 0.8),
                          duration: 500.ms,
                          curve: Curves.easeOutBack),

                      const SizedBox(height: 12),
                      Text('Tap to change photo',
                        style: TextStyle(
                          color: AppTheme.pink,
                          fontSize: 12,
                          fontWeight: FontWeight.w500)),

                      const SizedBox(height: 36),

                      // Name field
                      _GlassField(
                        controller: _nameController,
                        label: 'Display Name',
                        icon: Icons.person_rounded,
                        hint: 'Enter your name',
                      ).animate()
                        .fadeIn(duration: 400.ms, delay: 100.ms)
                        .slideY(begin: 0.2),

                      const SizedBox(height: 16),

                      // Email (read only)
                      _GlassField(
                        controller: TextEditingController(
                          text: user?.email ?? ''),
                        label: 'Email',
                        icon: Icons.email_rounded,
                        hint: 'Email address',
                        readOnly: true,
                        suffix: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.green
                                .withOpacity(0.3))),
                          child: const Text('Verified',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                        ),
                      ).animate()
                        .fadeIn(duration: 400.ms, delay: 200.ms)
                        .slideY(begin: 0.2),

                      const SizedBox(height: 16),

                      // UID (read only)
                      _GlassField(
                        controller: TextEditingController(
                          text: user?.uid ?? ''),
                        label: 'User ID',
                        icon: Icons.fingerprint_rounded,
                        hint: 'User ID',
                        readOnly: true,
                      ).animate()
                        .fadeIn(duration: 400.ms, delay: 300.ms)
                        .slideY(begin: 0.2),

                      const SizedBox(height: 40),

                      // Account actions
                      _AccountActions(),
                    ],
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

class _GlassField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String hint;
  final bool readOnly;
  final Widget? suffix;

  const _GlassField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.hint,
    this.readOnly = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5)),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.08),
                    Colors.white.withOpacity(0.04),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1)),
              ),
              child: TextField(
                controller: controller,
                readOnly: readOnly,
                style: TextStyle(
                  color: readOnly
                    ? Colors.white.withOpacity(0.4)
                    : Colors.white,
                  fontSize: 15),
                cursorColor: AppTheme.pink,
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.2)),
                  prefixIcon: ShaderMask(
                    shaderCallback: (b) =>
                      AppTheme.primaryGradient.createShader(b),
                    child: Icon(icon,
                      color: Colors.white, size: 20)),
                  suffixIcon: suffix != null
                    ? Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: suffix)
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
      ],
    );
  }
}

class _ImageSourceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const _ImageSourceBtn({
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
          horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors[0].withOpacity(0.2),
              colors[1].withOpacity(0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colors[0].withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colors[0].withOpacity(0.3),
                    blurRadius: 8, spreadRadius: -2),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Text(label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
              color: Colors.white.withOpacity(0.3), size: 16),
          ],
        ),
      ),
    );
  }
}

class _AccountActions extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text('DANGER ZONE',
            style: TextStyle(
              color: Colors.red.withOpacity(0.6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5)),
        ),
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
                color: Colors.red.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.delete_forever_rounded,
                    color: Colors.red, size: 18),
                ),
                const SizedBox(width: 12),
                const Text('Delete Account',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded,
                  color: Colors.red.withOpacity(0.4), size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Account',
          style: TextStyle(color: Colors.white,
            fontWeight: FontWeight.w800)),
        content: Text(
          'This will permanently delete your account, '
          'liked songs, playlists and history. '
          'This cannot be undone.',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
              style: TextStyle(
                color: Colors.white.withOpacity(0.5)))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await ref
                .read(profileServiceProvider)
                .deleteAccount();
              if (success && context.mounted) {
                Navigator.of(context)
                  .popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
            child: const Text('Delete',
              style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}