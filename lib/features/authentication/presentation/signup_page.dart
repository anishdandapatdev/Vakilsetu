import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/demo_store.dart';
import '../../../core/config/api_config.dart';
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
  final _profileFormKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  final _enrollment = TextEditingController();
  final _practiceAreas = TextEditingController(text: 'Civil Litigation · Corporate Law');
  final _otp = TextEditingController();
  final _otpFocus = FocusNode();

  // Steps:
  // 0: Account Details (Email or Mobile)
  // 1: Phone OTP Verification (only if mobile mode)
  // 2: Advocate Bar Profile Setup
  // 3: Submitted / Verification Confirmation
  int _step = 0;
  bool _emailMode = true;
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _loading = false;
  int _seconds = 30;
  Timer? _timer;
  String _selectedCourt = courts.first;
  String? _challengeId;
  AuthRepository? _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.authRepository ??
        (ApiConfig.enabled ? ApiAuthRepository() : FirebaseAuthRepository());
    _otp.addListener(_refreshOtp);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.removeListener(_refreshOtp);
    _otpFocus.dispose();
    for (final c in [
      _fullName,
      _email,
      _phone,
      _password,
      _confirmPassword,
      _enrollment,
      _practiceAreas,
      _otp,
    ]) {
      c.dispose();
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

  Future<void> _runAction(Future<void> Function() action) async {
    if (_loading) return;
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
        !_emailMode
            ? ((_repository is ApiAuthRepository)
                ? _repository
                : ApiAuthRepository())
            : (_repository ?? FirebaseAuthRepository()),
      );

  void _openSignIn() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => LoginPage(
            authRepository: _repository,
            showWelcome: false,
          ),
        ),
      );
    }
  }

  Future<void> _continueToNextStep() async {
    if (!(_accountFormKey.currentState?.validate() ?? false)) return;

    if (_emailMode) {
      if (_password.text != _confirmPassword.text) {
        toast(context, 'Passwords do not match.');
        return;
      }
      // In email mode, proceed to Advocate Profile step
      setState(() => _step = 2);
    } else {
      // In phone mode, send OTP and move to OTP step
      await _runAction(() async {
        final phoneText = '+91${_phone.text.trim()}';
        final apiRepo = (_repository is ApiAuthRepository)
            ? (_repository as ApiAuthRepository)
            : ApiAuthRepository();
        _challengeId = await apiRepo.requestOtp(phoneText);
        if (!mounted) return;
        toast(context, 'Verification code sent!');
        setState(() => _step = 1);
        _startCountdown();
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (_challengeId == null || _otp.text.length != 6) {
      toast(context, 'Enter the complete 6-digit OTP.');
      return;
    }
    await _runAction(() async {
      final apiRepo = (_repository is ApiAuthRepository)
          ? (_repository as ApiAuthRepository)
          : ApiAuthRepository();
      await apiRepo.verifyOtp(_challengeId!, _otp.text.trim());
      if (!mounted) return;
      toast(context, 'Phone number verified!');
      setState(() => _step = 2);
    });
  }

  Future<void> _resendOtp() async {
    if (_seconds > 0 || _loading) return;
    await _runAction(() async {
      final apiRepo = (_repository is ApiAuthRepository)
          ? (_repository as ApiAuthRepository)
          : ApiAuthRepository();
      _challengeId = await apiRepo.requestOtp('+91${_phone.text.trim()}');
      if (!mounted) return;
      _otp.clear();
      _startCountdown();
      _otpFocus.requestFocus();
      toast(context, 'OTP resent!');
    });
  }

  Future<void> _completeRegistration() async {
    if (!(_profileFormKey.currentState?.validate() ?? false)) return;

    await _runAction(() async {
      final authRepo = _repository ?? FirebaseAuthRepository();

      // If user registered with email mode, create their account now
      if (_emailMode) {
        if (authRepo is FirebaseAuthRepository) {
          try {
            await authRepo.registerWithEmail(
              _email.text.trim(),
              _password.text.trim(),
            );
          } catch (_) {
            // If already registered or fallback needed, try standard sign in
            await authRepo.signInWithEmail(
              _email.text.trim(),
              _password.text.trim(),
            );
          }
        }
      }

      // Save Advocate Profile details in Firestore
      try {
        final firestoreRepo = FirebaseProfileRepository();
        final courtIds = await firestoreRepo.listCourtIdsByName();
        final courtId = courtIds[_selectedCourt] ?? 'delhi_high_court';

        await firestoreRepo.save(
          ProfileUpdate(
            fullName: _fullName.text.trim(),
            enrollmentNumber: _enrollment.text.trim(),
            primaryCourtId: courtId,
            practiceAreas: _practiceAreas.text.trim(),
          ),
        );
      } catch (e) {
        debugPrint('Profile save note: $e');
      }

      if (mounted) setState(() => _step = 3);
    });
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
                      if (_step == 2 && !_emailMode) {
                        _step = 1;
                      } else if (_step == 1) {
                        _step = 0;
                      } else if (_step == 2 && _emailMode) {
                        _step = 0;
                      }
                    });
                  }
                : (Navigator.of(context).canPop()
                    ? () => Navigator.of(context).pop()
                    : null),
            onAction: _step == 2
                ? () => setState(() => _step = 3)
                : () => showAuthHelpDialog(context, onDemo: _enterApp),
            actionLabel: _step == 2 ? 'Skip for now' : 'Need help?',
          ),
          const SizedBox(height: 20),
          if (_step == 0) _buildAccountDetailsForm(),
          if (_step == 1) _buildOtpForm(),
          if (_step == 2) _buildAdvocateProfileForm(),
          if (_step == 3) _buildSuccessView(),
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
            subtitle: 'Register as an advocate or legal professional',
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
          const AuthFieldLabel('Full Name *'),
          TextFormField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline_rounded),
              hintText: 'e.g. Adv. Rajesh Sharma',
            ),
            validator: (v) =>
                (v ?? '').trim().length >= 3 ? null : 'Enter your full name.',
          ),
          const SizedBox(height: 14),
          if (_emailMode) ...[
            const AuthFieldLabel('Email Address *'),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.mail_outline_rounded),
                hintText: 'advocate@example.com',
              ),
              validator: (v) => (v ?? '').contains('@') && (v ?? '').contains('.')
                  ? null
                  : 'Enter a valid email address.',
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel('Mobile Number (Optional)'),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                prefixText: '🇮🇳  +91  ',
                hintText: '10-digit number',
                counterText: '',
              ),
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel('Create Password *'),
            TextFormField(
              controller: _password,
              obscureText: _hidePassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                hintText: 'At least 6 characters',
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
                  (v ?? '').length >= 6 ? null : 'Minimum 6 characters required.',
            ),
            const SizedBox(height: 14),
            const AuthFieldLabel('Confirm Password *'),
            TextFormField(
              controller: _confirmPassword,
              obscureText: _hideConfirmPassword,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_reset_rounded),
                hintText: 'Re-enter your password',
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _hideConfirmPassword = !_hideConfirmPassword,
                  ),
                  icon: Icon(
                    _hideConfirmPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
              ),
              validator: (v) {
                if ((v ?? '').isEmpty) return 'Confirm your password.';
                if (v != _password.text) return 'Passwords do not match.';
                return null;
              },
            ),
          ] else ...[
            const AuthFieldLabel('Mobile Number *'),
            TextFormField(
              controller: _phone,
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
                  : 'Enter a valid 10-digit phone number.',
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Icon(Icons.shield_outlined, color: slateBlue, size: 14),
                SizedBox(width: 6),
                Text(
                  'We will send a 6-digit OTP for number verification.',
                  style: TextStyle(color: slateBlue, fontSize: 11),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: _loading
                ? 'Processing…'
                : (_emailMode ? 'Continue to Bar Details' : 'Send Verification OTP'),
            loading: _loading,
            onPressed: _continueToNextStep,
          ),
          const SizedBox(height: 18),
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
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _enterApp,
              icon: const Icon(Icons.explore_outlined, size: 18),
              label: const Text('Explore Demo as Guest'),
            ),
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
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: i == _otp.text.length
                                ? const Color(0xFF0870E4)
                                : line,
                            width: i == _otp.text.length ? 2 : 1,
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
          style: TextStyle(color: slateBlue, fontSize: 12),
        ),
        TextButton(
          onPressed: _seconds > 0 || _loading ? null : _resendOtp,
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
        Text(
          _repository == null
              ? 'Preview code: 123456 · SMS simulated'
              : 'Development test code: 123456',
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildAdvocateProfileForm() {
    return Form(
      key: _profileFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthTitle(
            eyebrow: 'Professional Credentials',
            title: 'Advocate Profile',
            subtitle: 'Complete your Bar Council profile details',
          ),
          const SizedBox(height: 20),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Avatar(
                  _fullName.text.isNotEmpty
                      ? _fullName.text
                          .trim()
                          .split(' ')
                          .map((e) => e.isNotEmpty ? e[0] : '')
                          .take(2)
                          .join()
                          .toUpperCase()
                      : 'AK',
                  size: 88,
                ),
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0870E4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AuthFieldLabel('Full Legal Name *'),
          TextFormField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person_outline_rounded),
              hintText: 'Advocate full legal name',
            ),
            validator: (v) =>
                (v ?? '').trim().length >= 3 ? null : 'Enter your full name.',
          ),
          const SizedBox(height: 14),
          const AuthFieldLabel('Bar Council Enrollment No. *'),
          TextFormField(
            controller: _enrollment,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.badge_outlined),
              hintText: 'e.g. D/1234/2020 or MAH/5678/2018',
            ),
            validator: (v) => (v ?? '').trim().isNotEmpty
                ? null
                : 'Enter your Bar Council enrollment number.',
          ),
          const SizedBox(height: 14),
          const AuthFieldLabel('Primary Practice Court *'),
          DropdownButtonFormField<String>(
            initialValue: _selectedCourt,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.account_balance_outlined),
            ),
            items: courts
                .map((court) => DropdownMenuItem(value: court, child: Text(court)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedCourt = value);
            },
          ),
          const SizedBox(height: 14),
          const AuthFieldLabel('Practice Areas'),
          TextFormField(
            controller: _practiceAreas,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.gavel_rounded),
              hintText: 'e.g. Civil Litigation, Constitutional Law, NCLT',
            ),
          ),
          const SizedBox(height: 16),
          const Surface(
            color: paleBlue,
            padding: EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.verified_user_outlined, color: Color(0xFF0870E4), size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your enrollment number will be verified with the official Bar Council roster. Verified badges are granted post review.',
                    style: TextStyle(color: slateBlue, fontSize: 11, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          AuthPrimaryButton(
            label: _loading ? 'Registering…' : 'Submit & Complete Registration',
            loading: _loading,
            onPressed: _completeRegistration,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 35),
        Center(
          child: Container(
            width: 110,
            height: 110,
            decoration: const BoxDecoration(
              color: paleBlue,
              shape: BoxShape.circle,
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.badge_outlined, color: Color(0xFF0870E4), size: 64),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: teal,
                    child: Icon(Icons.check_rounded, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Registration Submitted!',
          textAlign: TextAlign.center,
          style: heading(22),
        ),
        const SizedBox(height: 8),
        Text(
          'Welcome to VakilSetu, ${_fullName.text.trim().isNotEmpty ? _fullName.text.trim() : "Advocate"}!\nYour profile is queued for Bar Council verification.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: slateBlue, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 26),
        const Surface(
          color: paleBlue,
          child: Column(
            children: [
              _StatusItem(
                Icons.schedule_rounded,
                'Bar verification in progress',
                'Our verification desk checks your enrollment details with the Bar Council.',
              ),
              SizedBox(height: 16),
              _StatusItem(
                Icons.verified_user_outlined,
                'Verified Advocate Badge',
                'Unlocked upon confirmation to boost credibility across the network.',
              ),
              SizedBox(height: 16),
              _StatusItem(
                Icons.groups_outlined,
                'Instant Access',
                'Start exploring court rooms, cause lists, and legal channels immediately.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        AuthPrimaryButton(
          label: 'Enter Dashboard',
          onPressed: _enterApp,
        ),
      ],
    );
  }
}

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _StatusItem(this.icon, this.title, this.description);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: teal, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: navy,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              description,
              style: const TextStyle(color: slateBlue, fontSize: 11, height: 1.3),
            ),
          ],
        ),
      ),
    ],
  );
}
