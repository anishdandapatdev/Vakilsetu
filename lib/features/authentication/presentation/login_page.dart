import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_shell.dart';
import '../../../app/demo_store.dart';
import '../../../core/config/api_config.dart';
import '../../../design_system/ui.dart';
import '../data/api_auth_repository.dart';
import '../../directory/data/api_advocates_repository.dart';
import '../../profile/domain/advocate_profile.dart';
import '../domain/auth_repository.dart';

class LoginPage extends StatefulWidget {
  final AuthRepository? authRepository;
  const LoginPage({super.key, this.authRepository});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final phone = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final otp = TextEditingController();
  final fullName = TextEditingController();
  final enrollment = TextEditingController();
  final otpFocus = FocusNode();

  int step = 0;
  int seconds = 30;
  bool emailMode = false;
  bool hidden = true;
  String selectedCourt = courts[1];
  Timer? timer;
  AuthRepository? repository;
  String? challengeId;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    repository = widget.authRepository ?? (ApiConfig.enabled ? ApiAuthRepository() : null);
    otp.addListener(_refreshOtp);
  }

  @override
  void dispose() {
    timer?.cancel();
    otp.removeListener(_refreshOtp);
    otpFocus.dispose();
    for (final controller in [
      phone,
      email,
      password,
      otp,
      fullName,
      enrollment,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _refreshOtp() => setState(() {});

  void _startCountdown() {
    timer?.cancel();
    setState(() => seconds = 30);
    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => seconds--);
      if (seconds <= 0) timer.cancel();
    });
  }

  Future<void> _resendOtp() async {
    if (seconds > 0 || loading) return;
    await _runAuthAction(() async {
      if (repository != null) {
        challengeId = await repository!.requestOtp('+91${phone.text}');
      }
      if (!mounted) return;
      otp.clear();
      _startCountdown();
      otpFocus.requestFocus();
    });
  }

  void _openShell(AuthRepository? authRepository) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AppShell(
          store: DemoStore(),
          authRepository: authRepository,
        ),
      ),
    );
  }

  void _enterApp() => _openShell(repository);

  void _enterDemo() => _openShell(null);

  Future<void> _continueLogin() async {
    if (!(form.currentState?.validate() ?? false)) return;
    if (emailMode) {
      if (repository == null) {
        setState(() => step = 3);
      } else {
        toast(context, 'Email sign-in is not available on the backend yet.');
      }
    } else {
      if (repository == null) {
        setState(() => step = 2);
        _startCountdown();
        return;
      }
      await _runAuthAction(() async {
        challengeId = await repository!.requestOtp('+91${phone.text}');
        if (!mounted) return;
        setState(() => step = 2);
        _startCountdown();
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (repository == null && otp.text != '123456') {
      toast(context, 'Use preview code 123456. No SMS is sent.');
      return;
    }
    if (repository == null) {
      setState(() => step = 3);
      return;
    }
    if (challengeId == null || otp.text.length != 6) {
      toast(context, 'Enter the complete 6-digit OTP.');
      return;
    }
    await _runAuthAction(() async {
      await repository!.verifyOtp(challengeId!, otp.text);
      final profile = await ApiAdvocatesRepository(
        repository! as ApiAuthRepository,
      ).getMine();
      if (!mounted) return;
      if (profile == null) {
        setState(() => step = 3);
      } else {
        _enterApp();
      }
    });
  }

  Future<void> _runAuthAction(Future<void> Function() action) async {
    if (loading) return;
    setState(() => loading = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) toast(context, 'Authentication failed: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _submitProfile() async {
    if (!(form.currentState?.validate() ?? false)) return;
    if (repository is! ApiAuthRepository) {
      setState(() => step = 4);
      return;
    }
    await _runAuthAction(() async {
      final profiles = ApiAdvocatesRepository(repository! as ApiAuthRepository);
      final courtIds = await profiles.listCourtIdsByName();
      final courtId = courtIds[selectedCourt];
      if (courtId == null) {
        throw const AuthenticationException('selected_court_not_available');
      }
      await profiles.save(ProfileUpdate(
        fullName: fullName.text.trim(),
        enrollmentNumber: enrollment.text.trim(),
        primaryCourtId: courtId,
      ));
      if (mounted) setState(() => step = 4);
    });
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    return Scaffold(
      backgroundColor: canvas,
      body: Stack(
        children: [
          const Positioned(top: -90, left: -80, child: _SoftCircle(size: 230)),
          const Positioned(
            bottom: -130,
            right: -100,
            child: _SoftCircle(size: 290),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: wide ? 1050 : 500),
                child: Row(
                  children: [
                    if (wide) ...[
                      const Expanded(child: _WelcomePanel(embedded: true)),
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
                        child: step == 0 && !wide
                            ? _WelcomePanel(
                                key: const ValueKey('welcome'),
                                onStart: () => setState(() => step = 1),
                                onDemo: repository == null ? _enterDemo : null,
                              )
                            : _flowPanel(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _flowPanel() => SingleChildScrollView(
    key: ValueKey('step-$step'),
    padding: const EdgeInsets.fromLTRB(22, 18, 22, 24),
    child: Form(
      key: form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (step > 1)
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => setState(() => step--),
                  icon: const Icon(Icons.arrow_back_rounded, color: navy),
                )
              else
                const VakilSetuLogo(height: 42),
              const Spacer(),
              TextButton(
                onPressed: step == 3
                    ? () => setState(() => step = 4)
                    : _enterDemo,
                child: Text(step == 3 ? 'Skip for now' : 'Need help?'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (step <= 1) _loginForm(),
          if (step == 2) _otpForm(),
          if (step == 3) _profileForm(),
          if (step == 4) _submitted(),
        ],
      ),
    ),
  );

  Widget _loginForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _AuthTitle(
        eyebrow: 'Welcome to',
        title: 'VakilSetu',
        subtitle: 'Login or sign up to continue',
      ),
      const SizedBox(height: 24),
      Row(
        children: [
          Expanded(
            child: _MethodTab(
              label: 'Mobile Number',
              selected: !emailMode,
              onTap: () => setState(() => emailMode = false),
            ),
          ),
          Expanded(
            child: _MethodTab(
              label: 'Email & Password',
              selected: emailMode,
              onTap: () => setState(() => emailMode = true),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      if (!emailMode) ...[
        TextFormField(
          controller: phone,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            prefixText: '🇮🇳  +91  ',
            hintText: 'Enter your mobile number',
            counterText: '',
          ),
          validator: (value) => RegExp(r'^\d{10}$').hasMatch(value ?? '')
              ? null
              : 'Enter a valid 10-digit number.',
        ),
        const SizedBox(height: 10),
        const Row(
          children: [
            Icon(Icons.lock_rounded, color: slateBlue, size: 15),
            SizedBox(width: 8),
            Text(
              'We’ll send you a 6-digit OTP',
              style: TextStyle(color: slateBlue, fontSize: 11),
            ),
          ],
        ),
      ] else ...[
        TextFormField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.mail_outline_rounded),
            hintText: 'Email address',
          ),
          validator: (value) => (value ?? '').contains('@')
              ? null
              : 'Enter a valid email address.',
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: password,
          obscureText: hidden,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            hintText: 'Password',
            suffixIcon: IconButton(
              onPressed: () => setState(() => hidden = !hidden),
              icon: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
          validator: (value) =>
              (value ?? '').length >= 8 ? null : 'Use at least 8 characters.',
        ),
      ],
      const SizedBox(height: 24),
      _PrimaryButton(
        label: loading ? 'Please wait…' : (emailMode ? 'Continue' : 'Send OTP'),
        onPressed: loading ? null : _continueLogin,
      ),
      const SizedBox(height: 14),
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
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () => setState(() => emailMode = !emailMode),
        icon: Icon(
          emailMode ? Icons.phone_android_rounded : Icons.mail_outline,
        ),
        label: Text(emailMode ? 'Continue with Mobile' : 'Continue with Email'),
      ),
      const SizedBox(height: 8),
      if (repository == null)
        TextButton(onPressed: _enterDemo, child: const Text('Explore the demo')),
      const SizedBox(height: 20),
      const _CommunityCard(),
    ],
  );

  Widget _otpForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _AuthTitle(
        title: 'Verify Your Number',
        subtitle: 'We’ve sent a 6-digit OTP to',
      ),
      const SizedBox(height: 4),
      Text(
        '+91 ${phone.text}',
        style: const TextStyle(color: navy, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 28),
      GestureDetector(
        onTap: otpFocus.requestFocus,
        child: Stack(
          children: [
            Row(
              children: [
                for (int index = 0; index < 6; index++) ...[
                  Expanded(
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: index == otp.text.length
                              ? const Color(0xFF0870E4)
                              : line,
                          width: index == otp.text.length ? 1.5 : 1,
                        ),
                      ),
                      child: Text(
                        index < otp.text.length ? otp.text[index] : '',
                        style: heading(20),
                      ),
                    ),
                  ),
                  if (index < 5) const SizedBox(width: 7),
                ],
              ],
            ),
            Opacity(
              opacity: .01,
              child: SizedBox(
                width: 1,
                height: 1,
                child: TextField(
                  controller: otp,
                  focusNode: otpFocus,
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
          onPressed: seconds > 0 || loading ? null : _resendOtp,
        child: Text(
          seconds > 0
              ? 'Resend in 00:${seconds.toString().padLeft(2, '0')}'
              : repository == null ? 'Resend preview code' : 'Resend code',
        ),
      ),
      const SizedBox(height: 32),
      _PrimaryButton(
        label: loading ? 'Verifying…' : 'Verify',
        onPressed: loading ? null : _verifyOtp,
      ),
      const SizedBox(height: 8),
      Text(
        repository == null
            ? 'Preview code: 123456 · No SMS is sent'
            : 'Development backend code: 123456',
        textAlign: TextAlign.center,
        style: TextStyle(color: muted, fontSize: 10),
      ),
    ],
  );

  Widget _profileForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _AuthTitle(
        title: 'Create Your Advocate Profile',
        subtitle: 'Let’s set up your professional identity',
      ),
      const SizedBox(height: 20),
      Center(
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            const Avatar('AK', size: 88),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: Color(0xFF0870E4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _FieldLabel('Full Name *'),
      TextFormField(
        controller: fullName,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.person_outline_rounded),
          hintText: 'Enter your full name',
        ),
        validator: (value) =>
            (value ?? '').trim().length >= 3 ? null : 'Enter your full name.',
      ),
      const SizedBox(height: 14),
      const _FieldLabel('Bar Council Enrollment No. *'),
      TextFormField(
        controller: enrollment,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.badge_outlined),
          hintText: 'Eg. D/1234/2020',
        ),
        validator: (value) => (value ?? '').trim().isNotEmpty
            ? null
            : 'Enter your enrollment number.',
      ),
      const SizedBox(height: 14),
      const _FieldLabel('Primary Practice Court *'),
      DropdownButtonFormField<String>(
        initialValue: selectedCourt,
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.account_balance_outlined),
        ),
        items: courts
            .map((court) => DropdownMenuItem(value: court, child: Text(court)))
            .toList(),
        onChanged: (value) => setState(() => selectedCourt = value!),
      ),
      const SizedBox(height: 16),
      const Surface(
        color: paleBlue,
        padding: EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.info_rounded, color: Color(0xFF0870E4), size: 18),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Your profile will be verified by our team. You’ll receive a verified badge once approved.',
                style: TextStyle(color: slateBlue, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      _PrimaryButton(
        label: loading ? 'Submitting…' : 'Continue',
        onPressed: loading ? null : _submitProfile,
      ),
    ],
  );

  Widget _submitted() => Column(
    children: [
      const SizedBox(height: 55),
      Container(
        width: 116,
        height: 116,
        decoration: const BoxDecoration(
          color: paleBlue,
          shape: BoxShape.circle,
        ),
        child: const Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.badge_outlined, color: Color(0xFF0870E4), size: 68),
            Positioned(
              right: 8,
              bottom: 8,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: teal,
                child: Icon(Icons.check_rounded, color: Colors.white, size: 28),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 25),
      Text('Profile Submitted!', style: heading(22)),
      const SizedBox(height: 8),
      const Text(
        'Your profile is under verification.\nWe’ll notify you once it’s approved.',
        textAlign: TextAlign.center,
        style: TextStyle(color: slateBlue, fontSize: 12, height: 1.5),
      ),
      const SizedBox(height: 26),
      const Surface(
        color: paleBlue,
        child: Column(
          children: [
            _StatusRow(
              Icons.schedule_rounded,
              'Our team will verify your details',
            ),
            SizedBox(height: 16),
            _StatusRow(
              Icons.verified_user_outlined,
              'You’ll get a verified badge',
            ),
            SizedBox(height: 16),
            _StatusRow(
              Icons.groups_outlined,
              'Start connecting with advocates',
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: _PrimaryButton(label: 'Go to Home', onPressed: _enterApp),
      ),
    ],
  );
}

class _WelcomePanel extends StatelessWidget {
  final VoidCallback? onStart;
  final VoidCallback? onDemo;
  final bool embedded;

  const _WelcomePanel({
    super.key,
    this.onStart,
    this.onDemo,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(26, embedded ? 60 : 55, 26, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Image(
            image: AssetImage('assets/images/brand/vakilsetu_logo.png'),
            height: 155,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'A Professional Network\nfor the Legal Community',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: navy,
            fontSize: 17,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 28),
        for (final item in const [
          ('advocates', 'Connect with fellow advocates'),
          ('courts', 'Get official court updates'),
          ('documents', 'Share knowledge and grow together'),
        ]) ...[
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: paleBlue,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: IllustratedIcon(item.$1, size: 35),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  item.$2,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 18),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/courts/patiala_house_courts.png',
            height: 165,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '“Stronger Together\nfor a Better Justice System”',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: navy,
            fontSize: 13,
            height: 1.4,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (onStart != null) ...[
          const SizedBox(height: 22),
          _PrimaryButton(label: 'Get Started', onPressed: onStart!),
          if (onDemo != null)
            TextButton(onPressed: onDemo, child: const Text('Explore the demo')),
        ],
      ],
    ),
  );
}

class _AuthTitle extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String subtitle;
  const _AuthTitle({this.eyebrow, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow != null)
        Text(
          eyebrow!,
          style: const TextStyle(
            color: navy,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      Text(title, style: heading(27)),
      const SizedBox(height: 4),
      Text(subtitle, style: const TextStyle(color: slateBlue, fontSize: 12)),
    ],
  );
}

class _MethodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _MethodTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? const Color(0xFF0870E4) : line,
            width: selected ? 2 : 1,
          ),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: selected ? const Color(0xFF0870E4) : slateBlue,
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
    ),
  );
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF0870E4),
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    ),
    child: Text(label),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: const TextStyle(
        color: navy,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatusRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: teal, size: 21),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: slateBlue, fontSize: 11),
        ),
      ),
    ],
  );
}

class _CommunityCard extends StatelessWidget {
  const _CommunityCard();

  @override
  Widget build(BuildContext context) => Surface(
    color: paleBlue,
    child: Row(
      children: [
        const IllustratedIcon('advocates', size: 70),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            '“Connect. Collaborate. Contribute to a stronger legal community.”',
            style: heading(13).copyWith(height: 1.45),
          ),
        ),
      ],
    ),
  );
}

class _SoftCircle extends StatelessWidget {
  final double size;
  const _SoftCircle({required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      color: Color(0x2556D5E8),
      shape: BoxShape.circle,
    ),
  );
}
