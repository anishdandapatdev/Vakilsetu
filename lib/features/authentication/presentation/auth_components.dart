import 'package:flutter/material.dart';

import '../../../app/app_shell.dart';
import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../data/firebase_auth_repository.dart';
import '../domain/auth_repository.dart';

/// Navigates to the main AppShell replacing the current route.
void openAppShell(BuildContext context, AuthRepository? authRepository) {
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => AppShell(
        store: DemoStore(),
        authRepository: authRepository ?? FirebaseAuthRepository(),
      ),
    ),
  );
}

/// Decorative soft circles background used for auth screens.
class AuthBackground extends StatelessWidget {
  final Widget child;

  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(
          top: -90,
          left: -80,
          child: _SoftCircle(size: 230),
        ),
        const Positioned(
          bottom: -130,
          right: -100,
          child: _SoftCircle(size: 290),
        ),
        SafeArea(child: child),
      ],
    );
  }
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

/// Side branding panel shown on desktop / tablet (screen width >= 960)
/// or as the initial welcome screen on mobile.
class AuthWelcomePanel extends StatelessWidget {
  final VoidCallback? onStart;
  final VoidCallback? onSignUp;
  final bool embedded;

  const AuthWelcomePanel({
    super.key,
    this.onStart,
    this.onSignUp,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(26, embedded ? 60 : 50, 26, 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(
          child: Image(
            image: AssetImage('assets/images/brand/vakilsetu_logo.png'),
            height: 150,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'A Professional Network\nfor the Legal Community',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: navy,
            fontSize: 18,
            height: 1.35,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 28),
        for (final item in const [
          ('advocates', 'Connect with verified advocates across courts'),
          ('courts', 'Live case updates, cause lists & court orders'),
          ('documents', 'Secure legal file exchange & digital vault'),
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
                child: IllustratedIcon(item.$1, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  item.$2,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
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
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '“Stronger Together for a Better Justice System”',
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
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Sign In to VakilSetu',
            onPressed: onStart!,
          ),
        ],
        if (onSignUp != null) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onSignUp,
            child: const Text('Create New Advocate Account'),
          ),
        ],
      ],
    ),
  );
}

/// Header for login / signup forms with back button, logo and right actions.
class AuthHeader extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onAction;
  final String actionLabel;

  const AuthHeader({
    super.key,
    this.onBack,
    this.onAction,
    this.actionLabel = 'Need help?',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          IconButton(
            tooltip: 'Back',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: navy),
          )
        else
          const VakilSetuLogo(height: 40),
        const Spacer(),
        if (onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
      ],
    );
  }
}

/// Title block for auth views with eyebrow, bold title and descriptive subtitle.
class AuthTitle extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String subtitle;

  const AuthTitle({
    super.key,
    this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow != null)
        Text(
          eyebrow!,
          style: const TextStyle(
            color: slateBlue,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      const SizedBox(height: 2),
      Text(title, style: heading(26)),
      const SizedBox(height: 6),
      Text(
        subtitle,
        style: const TextStyle(
          color: slateBlue,
          fontSize: 13,
          height: 1.35,
        ),
      ),
    ],
  );
}

/// Tab selector for switching auth modes.
class AuthMethodTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  const AuthMethodTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: selected ? const Color(0xFF0870E4) : line,
            width: selected ? 2.5 : 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: selected ? const Color(0xFF0870E4) : slateBlue,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? const Color(0xFF0870E4) : slateBlue,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Primary action button for Auth with standard sizing and loading indicator.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: loading ? null : onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xFF0870E4),
      disabledBackgroundColor: const Color(0xFF0870E4).withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(vertical: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    child: loading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: Colors.white,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
  );
}

/// Google Sign-In button with authentic Google 4-color 'G' icon.
class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;
  final String label;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
    this.label = 'Continue with Google',
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        side: const BorderSide(color: line, width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF4285F4),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const _GoogleGLogo(size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ink,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Authentic 4-color Google G icon drawn with vector paths.
class _GoogleGLogo extends StatelessWidget {
  final double size;
  const _GoogleGLogo({this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _GoogleGLogoPainter(),
      ),
    );
  }
}

class _GoogleGLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = w / 2;
    final strokeWidth = w * 0.22;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final rect = Rect.fromCircle(
      center: center,
      radius: radius - strokeWidth / 2,
    );

    // Red (top)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.6, 1.4, false, paint);

    // Yellow (left)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -1.2, 1.4, false, paint);

    // Green (bottom)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.2, 1.4, false, paint);

    // Blue (right arc)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, 1.6, 1.0, false, paint);

    // Blue (crossbar)
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx - strokeWidth / 4,
        center.dy - strokeWidth / 2,
        radius,
        strokeWidth,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Consistent styled label for text inputs.
class AuthFieldLabel extends StatelessWidget {
  final String text;
  const AuthFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7, top: 4),
    child: Text(
      text,
      style: const TextStyle(
        color: navy,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

/// Community highlight card shown at the bottom of authentication pages.
class AuthCommunityCard extends StatelessWidget {
  const AuthCommunityCard({super.key});

  @override
  Widget build(BuildContext context) => const Surface(
    color: paleBlue,
    child: Row(
      children: [
        IllustratedIcon('advocates', size: 64),
        SizedBox(width: 14),
        Expanded(
          child: Text(
            '“Connect. Collaborate. Contribute to a stronger legal community.”',
            style: TextStyle(
              color: navy,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Shows help modal sheet.
void showAuthHelpDialog(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
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
          Text('Need Help with VakilSetu?', style: heading(18)),
          const SizedBox(height: 8),
          const Text(
            'If you are having trouble signing in, verifying your Bar Council credentials, or receiving OTPs, here are ways to get support:',
            style: TextStyle(color: slateBlue, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: paleTeal,
              child: Icon(Icons.email_outlined, color: teal),
            ),
            title: const Text(
              'Email Support',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: const Text('support@vakilsetu.in'),
            onTap: () => Navigator.pop(ctx),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: paleBlue,
              child: Icon(Icons.phone_outlined, color: navy),
            ),
            title: const Text(
              'Advocate Helpline',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            subtitle: const Text('+91 11 2345 6789 (Mon-Sat, 9AM-7PM)'),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );
}
