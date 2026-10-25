import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/api_config.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _otpFocus = FocusNode();

  // Steps:
  // 0: Welcome splash on mobile (if showWelcome is true)
  // 1: Login form (Email or Mobile)
  // 2: Phone OTP verification
  late int _step;
  int _seconds = 30;
  bool _emailMode = true;
  bool _hidePassword = true;
  bool _loading = false;
  Timer? _timer;
  AuthRepository? _repository;
  String? _challengeId;

  @override
  void initState() {
    super.initState();
    _step = widget.showWelcome ? 0 : 1;
    _repository = widget.authRepository ??
        (ApiConfig.enabled ? ApiAuthRepository() : FirebaseAuthRepository());
    _otpController.addListener(_refreshOtp);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.removeListener(_refreshOtp);
    _otpFocus.dispose();
    for (final controller in [
      _phoneController,
      _emailController,
      _passwordController,
      _otpController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refreshOtp() => setState(() {});

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _seconds = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _seconds--);
      if (_seconds <= 0) timer.cancel();
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) toast(context, 'Authentication failed: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterApp() => openAppShell(context, _repository);

  void _openSignUp() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SignUpPage(authRepository: _repository),
      ),
    );
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_emailMode) {
      final emailText = _emailController.text.trim();
      final passwordText = _passwordController.text.trim();

      await _runAuthAction(() async {
        final authRepo = _repository ?? FirebaseAuthRepository();
        await authRepo.signInWithEmail(emailText, passwordText);
        if (!mounted) return;
        toast(context, 'Welcome back!');
        _enterApp();
      });
    } else {
      await _runAuthAction(() async {
        final phoneText = '+91${_phoneController.text.trim()}';
        final apiRepo = (_repository is ApiAuthRepository)
            ? (_repository as ApiAuthRepository)
            : ApiAuthRepository();
        _challengeId = await apiRepo.requestOtp(phoneText);
        if (!mounted) return;
        toast(context, 'Verification code sent!');
        setState(() => _step = 2);
        _startCountdown();
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_challengeId == null || _otpController.text.length != 6) {
      toast(context, 'Enter the complete 6-digit OTP.');
      return;
    }
    await _runAuthAction(() async {
      final apiRepo = (_repository is ApiAuthRepository)
          ? (_repository as ApiAuthRepository)
          : ApiAuthRepository();
      await apiRepo.verifyOtp(_challengeId!, _otpController.text.trim());
      if (!mounted) return;
      toast(context, 'Signed in successfully!');
      openAppShell(context, apiRepo);
    });
  }

  Future<void> _resendOtp() async {
    if (_seconds > 0 || _loading) return;
    await _runAuthAction(() async {
      final apiRepo = (_repository is ApiAuthRepository)
          ? (_repository as ApiAuthRepository)
          : ApiAuthRepository();
      _challengeId = await apiRepo.requestOtp(
        '+91${_phoneController.text.trim()}',
      );
      if (!mounted) return;
      _otpController.clear();
      _startCountdown();
      _otpFocus.requestFocus();
      toast(context, 'OTP resent!');
    });
  }

  void _showForgotPasswordSheet() {
    final resetEmailController = TextEditingController(
      text: _emailController.text.trim(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text('Reset Password', style: heading(19)),
            const SizedBox(height: 6),
            const Text(
              'Enter your registered email address and we will send you a link to reset your password.',
              style: TextStyle(color: slateBlue, fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 18),
            const AuthFieldLabel('Registered Email'),
            TextFormField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.mail_outline_rounded),
                hintText: 'advocate@example.com',
              ),
            ),
            const SizedBox(height: 20),
            AuthPrimaryButton(
              label: 'Send Reset Link',
              onPressed: () async {
                final emailToReset = resetEmailController.text.trim();
                if (emailToReset.isEmpty || !emailToReset.contains('@')) {
                  toast(context, 'Please enter a valid email address.');
                  return;
                }
                Navigator.of(ctx).pop();
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(
                    email: emailToReset,
                  );
                  if (mounted) {
                    toast(
                      context,
                      'Password reset email sent! Check your inbox.',
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    toast(context, 'Could not send reset email: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
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
                            onDemo: _enterApp,
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
            onBack: _step > 1
                ? () => setState(() => _step = 1)
                : (!widget.showWelcome && Navigator.of(context).canPop()
                    ? () => Navigator.of(context).pop()
                    : null),
            onAction: () => showAuthHelpDialog(context, onDemo: _enterApp),
            actionLabel: 'Need help?',
          ),
          const SizedBox(height: 24),
          if (_step <= 1) _buildLoginForm(),
          if (_step == 2) _buildOtpForm(),
        ],
      ),
    ),
  );

  Widget _buildLoginForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AuthTitle(
        eyebrow: 'Welcome Back',
        title: 'Sign In',
        subtitle: 'Sign in to access cases, cause lists and legal network',
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: AuthMethodTab(
              label: 'Email & Password',
              selected: _emailMode,
              icon: Icons.mail_outline_rounded,
              onTap: () => setState(() => _emailMode = true),
            ),
          ),
          Expanded(
            child: AuthMethodTab(
              label: 'Mobile OTP',
              selected: !_emailMode,
              icon: Icons.phone_android_rounded,
              onTap: () => setState(() => _emailMode = false),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (_emailMode) ...[
        const AuthFieldLabel('Email Address'),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.mail_outline_rounded),
            hintText: 'advocate@example.com',
          ),
          validator: (v) => (v ?? '').contains('@')
              ? null
              : 'Enter a valid email address.',
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const AuthFieldLabel('Password'),
            InkWell(
              onTap: _showForgotPasswordSheet,
              child: const Text(
                'Forgot password?',
                style: TextStyle(
                  color: Color(0xFF0870E4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        TextFormField(
          controller: _passwordController,
          obscureText: _hidePassword,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            hintText: 'Enter your password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          validator: (v) =>
              (v ?? '').length >= 6 ? null : 'Use at least 6 characters.',
        ),
      ] else ...[
        const AuthFieldLabel('Registered Mobile Number'),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: '🇮🇳  +91  ',
            hintText: 'Enter 10-digit mobile number',
            counterText: '',
          ),
          validator: (v) => RegExp(r'^\d{10}$').hasMatch(v ?? '')
              ? null
              : 'Enter a valid 10-digit mobile number.',
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.shield_outlined, color: slateBlue, size: 14),
            SizedBox(width: 8),
            Text(
              'A 6-digit verification code will be sent via SMS',
              style: TextStyle(color: slateBlue, fontSize: 11),
            ),
          ],
        ),
      ],
      const SizedBox(height: 24),
      AuthPrimaryButton(
        label: _loading
            ? 'Signing in…'
            : (_emailMode ? 'Sign In' : 'Send OTP'),
        loading: _loading,
        onPressed: _signIn,
      ),
      const SizedBox(height: 18),
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
      const SizedBox(height: 10),
      Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('OR', style: Theme.of(context).textTheme.bodySmall),
          ),
          const Expanded(child: Divider()),
        ],
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: _enterApp,
        icon: const Icon(Icons.explore_outlined, size: 18),
        label: const Text('Continue as Guest / Explore Demo'),
      ),
      const SizedBox(height: 20),
      const AuthCommunityCard(),
    ],
  );

  Widget _buildOtpForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AuthTitle(
        eyebrow: 'Security Verification',
        title: 'Verify OTP',
        subtitle: 'Enter the 6-digit code sent to',
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          Text(
            '+91 ${_phoneController.text}',
            style: const TextStyle(
              color: navy,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => setState(() => _step = 1),
            child: const Text(
              'Change',
              style: TextStyle(
                color: Color(0xFF0870E4),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 28),
      GestureDetector(
        onTap: _otpFocus.requestFocus,
        child: Stack(
          children: [
            Row(
              children: [
                for (int i = 0; i < 6; i++) ...[
                  Expanded(
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: i == _otpController.text.length
                              ? const Color(0xFF0870E4)
                              : line,
                          width: i == _otpController.text.length ? 1.8 : 1,
                        ),
                      ),
                      child: Text(
                        i < _otpController.text.length
                            ? _otpController.text[i]
                            : '',
                        style: heading(20),
                      ),
                    ),
                  ),
                  if (i < 5) const SizedBox(width: 7),
                ],
              ],
            ),
            Opacity(
              opacity: .01,
              child: SizedBox(
                width: 1,
                height: 1,
                child: TextField(
                  controller: _otpController,
                  focusNode: _otpFocus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Didn’t receive the code?',
        textAlign: TextAlign.center,
        style: TextStyle(color: slateBlue, fontSize: 11),
      ),
      TextButton(
        onPressed: _seconds > 0 || _loading ? null : _resendOtp,
        child: Text(
          _seconds > 0
              ? 'Resend OTP in 00:${_seconds.toString().padLeft(2, '0')}'
              : 'Resend code',
        ),
      ),
      const SizedBox(height: 28),
      AuthPrimaryButton(
        label: _loading ? 'Verifying…' : 'Verify & Sign In',
        loading: _loading,
        onPressed: _verifyOtp,
      ),
      const SizedBox(height: 10),
      Text(
        _repository == null
            ? 'Preview code: 123456 · No SMS is sent'
            : 'Development backend code: 123456',
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 11),
      ),
    ],
  );
}
