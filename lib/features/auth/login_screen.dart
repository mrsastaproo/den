import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);
    final auth = ref.read(authServiceProvider);

    try {
      if (_isSignUp) {
        final result = await auth.signUpWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim());
        if (result == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign up failed. Try again.')));
        }
      } else {
        final result = await auth.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text.trim());
        if (result == null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid email or password')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')));
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    final result = await ref.read(authServiceProvider).signInWithGoogle();
    if (result == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google sign in failed. Add SHA-1 to Firebase.')));
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                // Logo
                const Text('DEN',
                  style: TextStyle(color: Colors.white, fontSize: 48,
                    fontWeight: FontWeight.w900, letterSpacing: -2)),
                const Text('Your music, your world.',
                  style: TextStyle(color: Colors.white60, fontSize: 16)),

                const SizedBox(height: 60),

                Text(_isSignUp ? 'Create Account' : 'Welcome Back',
                  style: const TextStyle(color: Colors.white,
                    fontSize: 28, fontWeight: FontWeight.w800)),

                const SizedBox(height: 32),

                _buildField(_emailController,
                  'Email', Icons.email_rounded, false),
                const SizedBox(height: 16),

                _buildField(_passwordController,
                  'Password', Icons.lock_rounded, true),
                const SizedBox(height: 28),

                // Sign in/up button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleEmailAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF6B35B8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading
                      ? const CircularProgressIndicator(
                          color: Color(0xFF6B35B8), strokeWidth: 2)
                      : Text(_isSignUp ? 'Sign Up' : 'Sign In',
                          style: const TextStyle(fontSize: 16,
                            fontWeight: FontWeight.w700)),
                  ),
                ),

                const SizedBox(height: 16),

                // Divider
                const Row(children: [
                  Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                      style: TextStyle(color: Colors.white38))),
                  Expanded(child: Divider(color: Colors.white24)),
                ]),

                const SizedBox(height: 16),

                // Google sign in
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleGoogleSignIn,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.g_mobiledata_rounded,
                      size: 28, color: Colors.white),
                    label: const Text('Continue with Google',
                      style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.w600)),
                  ),
                ),

                const SizedBox(height: 24),

                // Toggle sign in/up
                Center(
                  child: TextButton(
                    onPressed: () =>
                      setState(() => _isSignUp = !_isSignUp),
                    child: Text(
                      _isSignUp
                        ? 'Already have an account? Sign In'
                        : "Don't have an account? Sign Up",
                      style: const TextStyle(
                        color: Colors.white70, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller,
      String hint, IconData icon, bool obscure) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 16),
        ),
      ),
    );
  }
}