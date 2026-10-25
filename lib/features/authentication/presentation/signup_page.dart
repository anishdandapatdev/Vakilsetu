import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/ui.dart';
import '../../profile/data/firebase_profile_repository.dart';
import '../../profile/domain/advocate_profile.dart';
import '../data/api_auth_repository.dart';
import '../data/firebase_auth_repository.dart';
import '../domain/auth_repository.dart';
import 'auth_components.dart';
import 'login_page.dart';

class SignUpPage extends StatefulWidget {
  final AuthRepository? authRepository;

  const SignUpPage({super.key, this.authRepository});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _accountFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  // Steps:
  // 0: Full Legal Name & Mobile Number
  // 1: Phone OTP Verification (Code: 123456)
  // 2: Create Password & Enter Home Screen
  int _step = 0;
  bool _loading = false;
  bool _googleLoading = false;
  int _seconds = 30;
  Timer? _timer;
  String? _challengeId;
  AuthRepository? _activeRepository;

  @override
  void initState() {
    super.initState();
    _activeRepository = widget.authRepository;
    _otp.addListener(_refreshOtp);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.removeListener(_refreshOtp);
    _otpFocus.dispose();
    _fullName.dispose();
    _phone.dispose();
    _otp.dispose();
    _password.dispose();
    _confirmPassword.dispose();
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
      if (mounted) toast(context, 'Sign up error: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterApp() => openAppShell(
        context,
        _activeRepository ?? ApiAuthRepository(),
      );

  void _openSignIn() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginPage(
            authRepository: _activeRepository,
            showWelcome: false,
          ),
        ),
      );
    }
  }

  ApiAuthRepository _getApiRepo() {
    if (_activeRepository is ApiAuthRepository) {
      return _activeRepository! as ApiAuthRepository;
    }
    return ApiAuthRepository();
  }

  Future<void> _sendOtp() async {
    if (!(_accountFormKey.currentState?.validate() ?? false)) return;

    await _runAction(() async {
      final phoneText = '+91${_phone.text.trim()}';
      final apiRepo = _getApiRepo();
      _challengeId = await apiRepo.requestOtp(phoneText);
      _activeRepository = apiRepo;
      if (!mounted) return;
      toast(context, 'Verification code sent!');
      setState(() => _step = 1);
      _startCountdown();
    });
  }

  Future<void> _verifyOtp() async {
    if (_challengeId == null || _otp.text.length != 6) {
      toast(context, 'Enter the complete 6-digit OTP.');
      return;
    }

    await _runAction(() async {
      final apiRepo = _getApiRepo();
      await apiRepo.verifyOtp(_challengeId!, _otp.text.trim());
      _activeRepository = apiRepo;
      if (!mounted) return;
      toast(context, 'Phone number verified! Now set your password.');
      setState(() => _step = 2);
    });
  }

  Future<void> _resendOtp() async {
    if (_seconds > 0 || _loading || _googleLoading) return;
    await _runAction(() async {
      final apiRepo = _getApiRepo();
      _challengeId = await apiRepo.requestOtp('+91${_phone.text.trim()}');
      if (!mounted) return;
      _otp.clear();
      _startCountdown();
      _otpFocus.requestFocus();
      toast(context, 'OTP resent!');
    });
  }

  Future<void> _createPasswordAndEnter() async {
    if (!(_passwordFormKey.currentState?.validate() ?? false)) return;

    await _runAction(() async {
      final phoneText = '+91${_phone.text.trim()}';
      final apiRepo = _getApiRepo();

      await apiRepo.createPassword(
        phoneNumber: phoneText,
        password: _password.text.trim(),
        fullName: _fullName.text.trim(),
      );
      _activeRepository = apiRepo;

      try {
        final firestoreRepo = FirebaseProfileRepository();
        await firestoreRepo.save(
          ProfileUpdate(
            fullName: _fullName.text.trim(),
            enrollmentNumber: 'PENDING',
            primaryCourtId: 'delhi_high_court',
            practiceAreas: 'Civil Litigation · Corporate Law',
          ),
        );
      } catch (e) {
        debugPrint('Profile sync note: $e');
      }

      if (!mounted) return;
      toast(context, 'Account created successfully! Welcome to VakilSetu.');
      _enterApp();
    });
  }

  Future<void> _signUpWithGoogle() async {
    if (_loading || _googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      final firebaseRepo = FirebaseAuthRepository();
      await firebaseRepo.signInWithGoogle();
      _activeRepository = firebaseRepo;

      final currentUser = firebaseRepo.currentUser;
      if (currentUser?.displayName != null && _fullName.text.isEmpty) {
        _fullName.text = currentUser!.displayName!;
      }

      if (!mounted) return;
      toast(context, 'Google account linked!');
      _enterApp();
    } catch (e) {
      if (mounted) toast(context, 'Google Sign-Up failed: $e');
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
            constraints: BoxConstraints(maxWidth: wide ? 1050 : 520),
            child: Row(
              children: [
                if (wide) ...[
                  const Expanded(
                    child: AuthWelcomePanel(embedded: true),
                  ),
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
                    child: _buildStepContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    return SingleChildScrollView(
      key: ValueKey('signup-step-$_step'),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeader(
            onBack: _step > 0
                ? () {
                    setState(() {
                      if (_step == 2) {
                        _step = 1;
                      } else if (_step == 1) {
                        _step = 0;
                      }
                    });
                  }
                : (Navigator.of(context).canPop()
                    ? () => Navigator.of(context).pop()
                    : null),
          ),
          const SizedBox(height: 20),
          if (_step == 0) _buildAccountDetailsForm(),
          if (_step == 1) _buildOtpForm(),
          if (_step == 2) _buildCreatePasswordForm(),
        ],
      ),
    );
  }

  Widget _buildAccountDetailsForm() {
    return Form(
      key: _accountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthTitle(
            eyebrow: 'Join VakilSetu',
            title: 'Create Account',
            subtitle: 'Register with your mobile number or Google account',
          ),
          const SizedBox(height: 24),
          CurvedInputField(
            controller: _fullName,
            label: 'Full Legal Name *',
            hint: 'e.g. Adv. Rajesh Sharma',
            prefixIcon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v ?? '').trim().length >= 3 ? null : 'Enter your full legal name.',
          ),
          const SizedBox(height: 16),
          CurvedPhoneInputField(
            controller: _phone,
            validator: (v) => RegExp(r'^\d{10}$').hasMatch(v ?? '')
                ? null
                : 'Enter a valid 10-digit phone number.',
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.shield_outlined, color: slateBlue, size: 14),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'We will send a 6-digit OTP code to verify your number.',
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
          const SizedBox(height: 10),
          const Text(
            'Demo: Use 9999999999 with OTP 123456',
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 18),
          GoogleSignInButton(
            onPressed: _signUpWithGoogle,
            loading: _googleLoading,
            label: 'Sign up with Google',
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Already have an account?',
                style: TextStyle(color: slateBlue, fontSize: 13),
              ),
              TextButton(
                onPressed: _openSignIn,
                child: const Text(
                  'Sign In',
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
      ),
    );
  }

  Widget _buildOtpForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthTitle(
          eyebrow: 'Step 2 of 3',
          title: 'Verify Your Phone',
          subtitle: 'We sent a 6-digit verification code to',
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '+91 ${_phone.text}',
              style: const TextStyle(
                color: navy,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => setState(() => _step = 0),
              child: const Text(
                'Edit',
                style: TextStyle(
                  color: Color(0xFF0870E4),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: i == _otp.text.length
                                ? const Color(0xFF005CEE)
                                : line,
                            width: i == _otp.text.length ? 1.8 : 1,
                          ),
                        ),
                        child: Text(
                          i < _otp.text.length ? _otp.text[i] : '',
                          style: heading(20),
                        ),
                      ),
                    ),
                    if (i < 5) const SizedBox(width: 7),
                  ],
                ],
              ),
              Opacity(
                opacity: 0.01,
                child: SizedBox(
                  width: 1,
                  height: 1,
                  child: TextField(
                    controller: _otp,
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
                : 'Resend verification code',
          ),
        ),
        const SizedBox(height: 24),
        AuthPrimaryButton(
          label: _loading ? 'Verifying…' : 'Verify & Continue',
          loading: _loading,
          onPressed: _verifyOtp,
        ),
        const SizedBox(height: 10),
        const Text(
          'Development test code: 123456',
          textAlign: TextAlign.center,
          style: TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildCreatePasswordForm() {
    return Form(
      key: _passwordFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthTitle(
            eyebrow: 'Step 3 of 3',
            title: 'Create Password',
            subtitle: 'Set a password to secure your account and sign in anytime',
          ),
          const SizedBox(height: 24),
          CurvedPasswordField(
            controller: _password,
            label: 'Create Password *',
            hint: 'At least 6 characters',
            validator: (v) =>
                (v ?? '').trim().length >= 6 ? null : 'Password must be at least 6 characters.',
          ),
          const SizedBox(height: 16),
          CurvedPasswordField(
            controller: _confirmPassword,
            label: 'Confirm Password *',
            hint: 'Re-enter your password',
            validator: (v) {
              if ((v ?? '').trim().isEmpty) return 'Confirm your password.';
              if (v!.trim() != _password.text.trim()) return 'Passwords do not match.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          Surface(
            color: paleBlue,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFF005CEE), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your password will be used along with +91 ${_phone.text} to sign in to VakilSetu securely.',
                    style: const TextStyle(color: slateBlue, fontSize: 11, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          AuthPrimaryButton(
            label: _loading ? 'Creating Account…' : 'Create Password & Enter Home',
            loading: _loading,
            onPressed: _createPasswordAndEnter,
          ),
        ],
      ),
    );
  }
}
