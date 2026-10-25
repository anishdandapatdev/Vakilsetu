import 'dart:async';

import 'package:flutter/material.dart';

import '../../../design_system/ui.dart';
import '../data/api_auth_repository.dart';
import '../data/firebase_auth_repository.dart';
import '../domain/auth_repository.dart';
import 'auth_components.dart';
import 'signup_page.dart';

typedef SignInPage = LoginPage;

class LoginPage extends StatefulWidget {
  final AuthRepository? authRepository;
  final bool showWelcome;

  const LoginPage({
    super.key,
    this.authRepository,
    this.showWelcome = true,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Steps:
  // 0: Welcome splash on mobile (if showWelcome is true)
  // 1: Phone + Password sign-in form
  late int _step;
  bool _loading = false;
  bool _googleLoading = false;
  AuthRepository? _repository;

  @override
  void initState() {
    super.initState();
    _step = widget.showWelcome ? 0 : 1;
    _repository = widget.authRepository;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_loading || _googleLoading) return;
    setState(() => _loading = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) toast(context, 'Authentication failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterApp(AuthRepository repo) => openAppShell(context, repo);

  void _openSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignUpPage(authRepository: _repository),
      ),
    );
  }

  ApiAuthRepository _getApiRepo() {
    if (_repository is ApiAuthRepository) {
      return _repository! as ApiAuthRepository;
    }
    return ApiAuthRepository();
  }

  Future<void> _signInWithPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _runAction(() async {
      final phoneText = '+91${_phoneController.text.trim()}';
      final apiRepo = _getApiRepo();
      await apiRepo.signInWithPassword(phoneText, _passwordController.text.trim());
      if (!mounted) return;
      toast(context, 'Signed in successfully!');
      _enterApp(apiRepo);
    });
  }

  Future<void> _signInWithGoogle() async {
    if (_loading || _googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      final firebaseRepo = FirebaseAuthRepository();
      await firebaseRepo.signInWithGoogle();
      if (!mounted) return;
      toast(context, 'Signed in with Google!');
      _enterApp(firebaseRepo);
    } catch (e) {
      if (mounted) toast(context, 'Google Sign-In failed: $e');
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;

    return Scaffold(
      backgroundColor: canvas,
      body: AuthBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 1050 : 500),
            child: Row(
              children: [
                if (wide) ...[
                  const Expanded(child: AuthWelcomePanel(embedded: true)),
                  const SizedBox(width: 28),
                ],
                Expanded(
                  child: Container(
                    margin: EdgeInsets.all(wide ? 24 : 0),
                    decoration: wide
                        ? BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x160B5070),
                                blurRadius: 34,
                                offset: Offset(0, 12),
                              ),
                            ],
                          )
                        : null,
                    child: _step == 0 && !wide
                        ? AuthWelcomePanel(
                            key: const ValueKey('welcome-screen'),
                            onStart: () => setState(() => _step = 1),
                            onSignUp: _openSignUp,
                          )
                        : _buildFlowContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFlowContent() => SingleChildScrollView(
    key: ValueKey('login-step-$_step'),
    padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
    child: Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            onBack: !widget.showWelcome && Navigator.of(context).canPop()
                ? () => Navigator.of(context).pop()
                : null,
          ),
          const SizedBox(height: 24),
          _buildPhoneLoginForm(),
        ],
      ),
    ),
  );

  Widget _buildPhoneLoginForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AuthTitle(
        eyebrow: 'Welcome Back',
        title: 'Sign In',
        subtitle: 'Enter your mobile number and password to sign in',
      ),
      const SizedBox(height: 24),
      CurvedPhoneInputField(
        controller: _phoneController,
        validator: (v) => RegExp(r'^\d{10}$').hasMatch(v ?? '')
            ? null
            : 'Enter a valid 10-digit mobile number.',
      ),
      const SizedBox(height: 16),
      CurvedPasswordField(
        controller: _passwordController,
        label: 'Password *',
        hint: 'Enter your password',
        validator: (v) =>
            (v ?? '').trim().isNotEmpty ? null : 'Enter your account password.',
      ),
      const SizedBox(height: 24),
      AuthPrimaryButton(
        label: _loading ? 'Signing In…' : 'Sign In',
        loading: _loading,
        onPressed: _signInWithPassword,
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'OR',
              style: TextStyle(
                color: muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
      const SizedBox(height: 20),
      GoogleSignInButton(
        onPressed: _signInWithGoogle,
        loading: _googleLoading,
        label: 'Sign in with Google',
      ),
      const SizedBox(height: 22),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Don’t have an account?',
            style: TextStyle(color: slateBlue, fontSize: 13),
          ),
          TextButton(
            onPressed: _openSignUp,
            child: const Text(
              'Sign Up',
              style: TextStyle(
                color: Color(0xFF0870E4),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      const AuthCommunityCard(),
    ],
  );
}
