import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final _otpController = TextEditingController();
  final _otpFocus = FocusNode();

  // Steps:
  // 0: Welcome splash on mobile (if showWelcome is true)
  // 1: Phone input form
  // 2: Phone OTP verification
  late int _step;
  int _seconds = 30;
  bool _loading = false;
  bool _googleLoading = false;
  Timer? _timer;
  AuthRepository? _repository;
  String? _challengeId;

  @override
  void initState() {
    super.initState();
    _step = widget.showWelcome ? 0 : 1;
    _repository = widget.authRepository;
    _otpController.addListener(_refreshOtp);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.removeListener(_refreshOtp);
    _otpFocus.dispose();
    _phoneController.dispose();
    _otpController.dispose();
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

  Future<void> _sendOtp() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await _runAction(() async {
      final phoneText = '+91${_phoneController.text.trim()}';
      final apiRepo = _getApiRepo();
      _challengeId = await apiRepo.requestOtp(phoneText);
      if (!mounted) return;
      toast(context, 'Verification code sent!');
      setState(() => _step = 2);
      _startCountdown();
    });
  }

  Future<void> _verifyOtp() async {
    if (_challengeId == null || _otpController.text.length != 6) {
      toast(context, 'Enter the complete 6-digit OTP.');
      return;
    }

    await _runAction(() async {
      final apiRepo = _getApiRepo();
      await apiRepo.verifyOtp(_challengeId!, _otpController.text.trim());
      if (!mounted) return;
      toast(context, 'Signed in successfully!');
      _enterApp(apiRepo);
    });
  }

  Future<void> _resendOtp() async {
    if (_seconds > 0 || _loading || _googleLoading) return;
    await _runAction(() async {
      final apiRepo = _getApiRepo();
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
            onBack: _step > 1
                ? () => setState(() => _step = 1)
                : (!widget.showWelcome && Navigator.of(context).canPop()
                    ? () => Navigator.of(context).pop()
                    : null),
            onAction: () => showAuthHelpDialog(context),
            actionLabel: 'Need help?',
          ),
          const SizedBox(height: 24),
          if (_step <= 1) _buildPhoneLoginForm(),
          if (_step == 2) _buildOtpForm(),
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
        subtitle: 'Enter your mobile number to receive a secure OTP code',
      ),
      const SizedBox(height: 24),
      const AuthFieldLabel('Mobile Number *'),
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
          Expanded(
            child: Text(
              'A 6-digit verification code will be sent via SMS',
              style: TextStyle(color: slateBlue, fontSize: 11),
            ),
          ),
        ],
      ),
      const SizedBox(height: 24),
      AuthPrimaryButton(
        label: _loading ? 'Sending OTP…' : 'Send OTP',
        loading: _loading,
        onPressed: _sendOtp,
      ),
      const SizedBox(height: 22),
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
      const SizedBox(height: 22),
      GoogleSignInButton(
        onPressed: _signInWithGoogle,
        loading: _googleLoading,
        label: 'Sign in with Google',
      ),
      const SizedBox(height: 24),
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
        onPressed: _seconds > 0 || _loading || _googleLoading ? null : _resendOtp,
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
        'Development backend code: 123456',
        textAlign: TextAlign.center,
        style: const TextStyle(color: muted, fontSize: 11),
      ),
    ],
  );
}
