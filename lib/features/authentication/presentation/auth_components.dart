import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  final VoidCallback? onExplore;
  final bool embedded;

  const AuthWelcomePanel({
    super.key,
    this.onStart,
    this.onSignUp,
    this.onExplore,
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
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
            ),
            onPressed: onSignUp,
            child: const Text('Create New Advocate Account'),
          ),
        ],
        if (onExplore != null) ...[
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onExplore,
            icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: slateBlue),
            label: const Text(
              'Explore VakilSetu as Guest Advocate',
              style: TextStyle(
                color: slateBlue,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

/// Header for login / signup forms with back button and logo.
/// Notice: "Need help?" has been completely removed.
class AuthHeader extends StatelessWidget {
  final VoidCallback? onBack;
  final VoidCallback? onAction;
  final String? actionLabel;

  const AuthHeader({
    super.key,
    this.onBack,
    this.onAction,
    this.actionLabel,
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
        if (onAction != null && actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
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

/// Curved pill-shaped phone number input matching the requested design:
/// Rounded border (radius 32), "+91" prefix, vertical divider "|",
/// stacked "Mobile number" label on top and text input below.
class CurvedPhoneInputField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;
  final bool autofocus;

  const CurvedPhoneInputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.onChanged,
    this.validator,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (v) => validator != null ? validator!(controller.text) : null,
      initialValue: controller.text,
      builder: (state) {
        final hasError = state.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: hasError ? const Color(0xFFE53935) : const Color(0xFFCBD5E1),
                  width: hasError ? 1.4 : 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text(
                    '+91',
                    style: TextStyle(
                      color: ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 1,
                    height: 26,
                    color: const Color(0xFFCBD5E1),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mobile number',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        TextField(
                          controller: controller,
                          focusNode: focusNode,
                          autofocus: autofocus,
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          onChanged: (val) {
                            state.didChange(val);
                            onChanged?.call(val);
                          },
                          style: const TextStyle(
                            color: ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            counterText: '',
                            hintText: '1234567890',
                            hintStyle: TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 6),
                child: Text(
                  state.errorText ?? '',
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// General curved pill-shaped input field for Name, Bar Council Enrollment, etc.
class CurvedInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData? prefixIcon;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final Widget? suffix;

  const CurvedInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.prefixIcon,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (v) => validator != null ? validator!(controller.text) : null,
      initialValue: controller.text,
      builder: (state) {
        final hasError = state.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: hasError ? const Color(0xFFE53935) : const Color(0xFFCBD5E1),
                  width: hasError ? 1.4 : 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (prefixIcon != null) ...[
                    Icon(prefixIcon, color: slateBlue, size: 20),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        TextField(
                          controller: controller,
                          textCapitalization: textCapitalization,
                          onChanged: (val) => state.didChange(val),
                          style: const TextStyle(
                            color: ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: hint,
                            hintStyle: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (suffix != null) suffix!,
                ],
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 6),
                child: Text(
                  state.errorText ?? '',
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Curved dropdown field matching the pill style.
class CurvedDropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final IconData? prefixIcon;

  const CurvedDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: const Color(0xFFCBD5E1),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (prefixIcon != null) ...[
            Icon(prefixIcon, color: slateBlue, size: 20),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isDense: true,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: slateBlue),
                    style: const TextStyle(
                      color: ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    items: items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text(item, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: onChanged,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Curved password input field with visibility toggle icon and pill stadium design.
class CurvedPasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final FocusNode? focusNode;

  const CurvedPasswordField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.focusNode,
  });

  @override
  State<CurvedPasswordField> createState() => _CurvedPasswordFieldState();
}

class _CurvedPasswordFieldState extends State<CurvedPasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (v) => widget.validator != null ? widget.validator!(widget.controller.text) : null,
      initialValue: widget.controller.text,
      builder: (state) {
        final hasError = state.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 64,
              padding: const EdgeInsets.only(left: 20, right: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: hasError ? const Color(0xFFE53935) : const Color(0xFFCBD5E1),
                  width: hasError ? 1.4 : 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x06000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline_rounded, color: slateBlue, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          obscureText: _obscure,
                          onChanged: (val) => state.didChange(val),
                          style: const TextStyle(
                            color: ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            hintText: widget.hint,
                            hintStyle: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: slateBlue,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ],
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 6),
                child: Text(
                  state.errorText ?? '',
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}


/// Primary action button for Auth styled with full curved pill shape (radius 32)
/// and vibrant blue color (Color(0xFF005CEE)) matching Image 2.
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
      backgroundColor: const Color(0xFF005CEE),
      disabledBackgroundColor: const Color(0xFF005CEE).withValues(alpha: 0.6),
      padding: const EdgeInsets.symmetric(vertical: 17),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
  );
}

/// Google Sign-In button with authentic Google 4-color 'G' icon and curved pill shape.
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
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
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
