import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailFocus    = FocusNode();
  final _passwordFocus = FocusNode();

  bool _loading   = false;
  bool _isSignUp  = false;
  bool _showPass  = false;
  String? _emailError;
  String? _passError;

  late AnimationController _bgOrb1;
  late AnimationController _bgOrb2;
  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _bgOrb1 = AnimationController(
      vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
    _bgOrb2 = AnimationController(
      vsync: this, duration: const Duration(seconds: 11))..repeat(reverse: true);

    _shakeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -8.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: -6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 6.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6.0, end: 0.0),  weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _emailCtrl.dispose(); _passwordCtrl.dispose();
    _emailFocus.dispose(); _passwordFocus.dispose();
    _bgOrb1.dispose(); _bgOrb2.dispose(); _shakeCtrl.dispose();
    super.dispose();
  }

  bool _validate() {
    setState(() { _emailError = null; _passError = null; });
    bool ok = true;
    if (_emailCtrl.text.trim().isEmpty ||
        !_emailCtrl.text.contains('@')) {
      setState(() => _emailError = 'Enter a valid email');
      ok = false;
    }
    if (_passwordCtrl.text.length < 6) {
      setState(() => _passError = 'At least 6 characters');
      ok = false;
    }
    if (!ok) _shakeCtrl.forward(from: 0);
    return ok;
  }

  Future<void> _handleEmail() async {
    if (!_validate()) return;
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    try {
      final auth = ref.read(authServiceProvider);
      final result = _isSignUp
          ? await auth.signUpWithEmail(
              _emailCtrl.text.trim(), _passwordCtrl.text.trim())
          : await auth.signInWithEmail(
              _emailCtrl.text.trim(), _passwordCtrl.text.trim());
      if (result == null && mounted) {
        _shakeCtrl.forward(from: 0);
        _showError(_isSignUp
            ? 'Sign up failed. Try a different email.'
            : 'Wrong email or password.');
      }
    } catch (e) {
      if (mounted) _showError('$e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _handleGoogle() async {
    setState(() => _loading = true);
    HapticFeedback.mediumImpact();
    final result = await ref.read(authServiceProvider).signInWithGoogle();
    if (result == null && mounted) {
      _showError('Google sign-in failed. Check SHA-1 in Firebase.');
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: Colors.red.shade900.withOpacity(0.9),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(fit: StackFit.expand, children: [

        // ── Animated orb background ──────────────────────────
        AnimatedBuilder(
          animation: Listenable.merge([_bgOrb1, _bgOrb2]),
          builder: (_, __) => Stack(children: [
            // Orb 1
            Positioned(
              top: -100 + 60 * _bgOrb1.value,
              left: -80 + 40 * _bgOrb2.value,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.pink.withOpacity(0.35),
                      AppTheme.purple.withOpacity(0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // Orb 2
            Positioned(
              bottom: -120 + 50 * _bgOrb2.value,
              right: -60 + 30 * _bgOrb1.value,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.purple.withOpacity(0.3),
                      AppTheme.pink.withOpacity(0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ]),
        ),

        // Blur overlay
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
          child: Container(color: Colors.black.withOpacity(0.55))),

        // ── Content ──────────────────────────────────────────
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(_shakeAnim.value, 0),
                child: child),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 48),

                  // ── Logo ──────────────────────────────────
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppTheme.primaryGradient.createShader(b),
                    child: const Text('DEN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -3,
                        height: 1)),
                  ).animate().fadeIn(duration: 600.ms)
                      .slideY(begin: -0.2, end: 0, duration: 600.ms),

                  const SizedBox(height: 6),

                  Text('Your music, your world.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ).animate().fadeIn(delay: 100.ms, duration: 500.ms),

                  const SizedBox(height: 48),

                  // ── Title ────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _isSignUp ? 'Create Account' : 'Welcome Back',
                      key: ValueKey(_isSignUp),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                        height: 1.1),
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: 8),

                  Text(
                    _isSignUp
                        ? 'Join DEN and discover your sound'
                        : 'Sign in to continue listening',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(delay: 250.ms, duration: 400.ms),

                  const SizedBox(height: 32),

                  // ── Email field ───────────────────────────
                  _Field(
                    controller: _emailCtrl,
                    focusNode: _emailFocus,
                    hint: 'Email address',
                    icon: Icons.email_outlined,
                    error: _emailError,
                    keyboardType: TextInputType.emailAddress,
                    onSubmit: (_) => _passwordFocus.requestFocus(),
                  ).animate().fadeIn(delay: 300.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 300.ms),

                  const SizedBox(height: 12),

                  // ── Password field ────────────────────────
                  _Field(
                    controller: _passwordCtrl,
                    focusNode: _passwordFocus,
                    hint: 'Password',
                    icon: Icons.lock_outline_rounded,
                    error: _passError,
                    obscure: !_showPass,
                    suffix: GestureDetector(
                      onTap: () => setState(() => _showPass = !_showPass),
                      child: Icon(
                        _showPass
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: Colors.white.withOpacity(0.4),
                        size: 20),
                    ),
                    onSubmit: (_) => _handleEmail(),
                  ).animate().fadeIn(delay: 350.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 350.ms),

                  // Forgot password
                  if (!_isSignUp) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => _showForgotSheet(),
                        child: Text('Forgot password?',
                          style: TextStyle(
                            color: AppTheme.pink.withOpacity(0.85),
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // ── Primary CTA ───────────────────────────
                  _PrimaryBtn(
                    label: _isSignUp ? 'Create Account' : 'Sign In',
                    loading: _loading,
                    onTap: _handleEmail,
                  ).animate().fadeIn(delay: 400.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0, duration: 400.ms, delay: 400.ms),

                  const SizedBox(height: 20),

                  // ── Divider ───────────────────────────────
                  Row(children: [
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('or continue with',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 12))),
                    Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                  ]).animate().fadeIn(delay: 450.ms),

                  const SizedBox(height: 20),

                  // ── Google Button ─────────────────────────
                  _GoogleBtn(
                    loading: _loading,
                    onTap: _handleGoogle,
                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

                  const SizedBox(height: 28),

                  // ── Toggle sign in / sign up ──────────────
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _isSignUp = !_isSignUp;
                          _emailError = null;
                          _passError  = null;
                        });
                      },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 14),
                          children: [
                            TextSpan(text: _isSignUp
                                ? 'Already have an account? '
                                : "Don't have an account? "),
                            TextSpan(
                              text: _isSignUp ? 'Sign In' : 'Sign Up',
                              style: const TextStyle(
                                color: AppTheme.pink,
                                fontWeight: FontWeight.w700)),
                          ]),
                      ),
                    ),
                  ).animate().fadeIn(delay: 550.ms),

                  const SizedBox(height: 16),

                  // Terms
                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms & Privacy Policy',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.2),
                        fontSize: 11),
                    ),
                  ).animate().fadeIn(delay: 600.ms),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ]),
    );
  }

  void _showForgotSheet() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: Colors.white.withOpacity(0.08))),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 20),
                  const Text('Reset Password',
                    style: TextStyle(color: Colors.white,
                      fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text("We'll send a reset link to your email.",
                    style: TextStyle(color: Colors.white.withOpacity(0.45),
                      fontSize: 14)),
                  const SizedBox(height: 20),
                  _Field(
                    controller: ctrl,
                    hint: 'Email address',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  Consumer(builder: (ctx, ref, _) =>
                    _PrimaryBtn(
                      label: 'Send Reset Link',
                      loading: false,
                      onTap: () async {
                        if (ctrl.text.trim().isEmpty) return;
                        final ok = await ref
                            .read(authServiceProvider)
                            .sendPasswordResetEmail(ctrl.text.trim());
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                            content: Text(ok
                              ? 'Reset link sent to ${ctrl.text.trim()}'
                              : 'Could not send. Check your email.',
                              style: const TextStyle(color: Colors.white)),
                            backgroundColor: ok
                              ? Colors.black.withOpacity(0.85)
                              : Colors.red.shade900,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          ));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── FIELD ────────────────────────────────────────────────────

class _Field extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hint;
  final IconData icon;
  final String? error;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmit;

  const _Field({
    required this.controller,
    this.focusNode,
    required this.hint,
    required this.icon,
    this.error,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
    this.onSubmit,
  });

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
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
    final hasError = widget.error != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasError
                  ? Colors.red.withOpacity(0.6)
                  : _focused
                      ? AppTheme.pink.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
              width: _focused || hasError ? 1.5 : 1,
            ),
            boxShadow: _focused ? [
              BoxShadow(
                color: hasError
                    ? Colors.red.withOpacity(0.1)
                    : AppTheme.pink.withOpacity(0.1),
                blurRadius: 16, spreadRadius: -4),
            ] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.white.withOpacity(_focused ? 0.06 : 0.04),
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  obscureText: widget.obscure,
                  keyboardType: widget.keyboardType,
                  onSubmitted: widget.onSubmit,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                  cursorColor: AppTheme.pink,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3), fontSize: 15),
                    prefixIcon: Icon(widget.icon,
                      color: _focused
                          ? AppTheme.pink.withOpacity(0.8)
                          : Colors.white.withOpacity(0.35),
                      size: 20),
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
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 5),
            child: Text(widget.error!,
              style: TextStyle(
                color: Colors.red.shade400,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }
}

// ─── PRIMARY BUTTON ───────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryBtn({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          gradient: loading ? null : AppTheme.primaryGradient,
          color: loading ? Colors.white.withOpacity(0.1) : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: loading ? null : [
            BoxShadow(
              color: AppTheme.pink.withOpacity(0.35),
              blurRadius: 20, spreadRadius: -5,
              offset: const Offset(0, 6)),
          ],
        ),
        child: Center(
          child: loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3)),
        ),
      ),
    );
  }
}

// ─── GOOGLE BUTTON ────────────────────────────────────────────

class _GoogleBtn extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _GoogleBtn({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity, height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.12))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Google G
                Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                  child: const Center(
                    child: Text('G',
                      style: TextStyle(
                        color: Color(0xFF4285F4),
                        fontSize: 14,
                        fontWeight: FontWeight.w800)))),
                const SizedBox(width: 12),
                Text('Continue with Google',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}