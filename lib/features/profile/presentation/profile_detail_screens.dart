import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../design_system/ui.dart';

class ProfileDetailScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;

  const ProfileDetailScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: navy,
            size: 19,
          ),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: ink,
                fontFamily: 'Manrope',
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(
                subtitle!,
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ],
        ),
        actions: actions,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: line, height: 1),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
          child: body,
        ),
      ),
    );
  }
}

class DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const DetailCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060C2340),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class DetailRowItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Widget? trailing;

  const DetailRowItem({
    super.key,
    required this.icon,
    this.iconColor = navy,
    required this.label,
    required this.value,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: slateBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: ink,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// 1. Bar Council Credentials Full Screen View
class BarCouncilCredentialsScreen extends StatelessWidget {
  final String advocateName;
  final String enrollmentNumber;
  final String stateBar;
  final String primaryCourt;
  final int experienceYears;
  final VoidCallback onEdit;

  const BarCouncilCredentialsScreen({
    super.key,
    required this.advocateName,
    required this.enrollmentNumber,
    required this.stateBar,
    required this.primaryCourt,
    required this.experienceYears,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileDetailScaffold(
      title: 'Bar Council Credentials',
      subtitle: 'Official advocate verification certificate',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Verified Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1D3557), Color(0xFF0F2644)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x281D3557),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        stateBar.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFE2F0FE),
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const LegalIcon(
                      'verified',
                      size: 28,
                      color: Color(0xFFF5B942),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  advocateName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Manrope',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enrollment: $enrollmentNumber',
                  style: const TextStyle(
                    color: Color(0xFFE2F0FE),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.6),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF6EE7B7),
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Verified Advocate Standing',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Detail Attributes
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REGISTRATION DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                DetailRowItem(
                  icon: Icons.badge_outlined,
                  iconColor: teal,
                  label: 'Bar Enrollment Number',
                  value: enrollmentNumber,
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: muted,
                    ),
                    tooltip: 'Copy Enrollment',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: enrollmentNumber));
                      toast(context, 'Enrollment number copied to clipboard');
                    },
                  ),
                ),
                const Divider(height: 18, indent: 50),
                DetailRowItem(
                  icon: Icons.account_balance_outlined,
                  iconColor: const Color(0xFF147BEA),
                  label: 'State Bar Council',
                  value: stateBar,
                ),
                const Divider(height: 18, indent: 50),
                DetailRowItem(
                  icon: Icons.gavel_rounded,
                  iconColor: navy,
                  label: 'Primary Court of Practice',
                  value: primaryCourt,
                ),
                const Divider(height: 18, indent: 50),
                DetailRowItem(
                  icon: Icons.work_history_outlined,
                  iconColor: bronze,
                  label: 'Years in Active Legal Practice',
                  value: '$experienceYears Years of Standing',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Certificate Verification Card
          DetailCard(
            backgroundColor: const Color(0xFFF0FDF4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF059669),
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Digitally Verified Credential',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'This advocate registration is verified under the Advocates Act, 1961. Verified members receive official court channel broadcasts and authenticated chamber collaboration.',
                        style: TextStyle(
                          fontSize: 11,
                          color: const Color(0xFF047857).withValues(alpha: 0.9),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Edit Action Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: navy,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onEdit();
            },
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text(
              'Edit Bar Credentials',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// 2. Court & Chamber Address Full Screen View
class ChamberAddressScreen extends StatelessWidget {
  final String advocateName;
  final String primaryCourt;
  final String chamberAddress;
  final String phone;
  final VoidCallback onEdit;

  const ChamberAddressScreen({
    super.key,
    required this.advocateName,
    required this.primaryCourt,
    required this.chamberAddress,
    required this.phone,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileDetailScaffold(
      title: 'Court & Chamber Address',
      subtitle: 'Official chamber location & contact',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary Court Header Card
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF147BEA).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        color: Color(0xFF147BEA),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PRIMARY JURISDICTION',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: muted,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            primaryCourt,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              fontFamily: 'Manrope',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBF5FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 14,
                        color: Color(0xFF147BEA),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Subscribed to live causelists, notices & bench circulars',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF147BEA),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Chamber Details Card
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHAMBER OFFICE DETAILS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                DetailRowItem(
                  icon: Icons.location_on_outlined,
                  iconColor: const Color(0xFFE65100),
                  label: 'Physical Chamber Address',
                  value: chamberAddress,
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: muted,
                    ),
                    tooltip: 'Copy Address',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: chamberAddress));
                      toast(context, 'Chamber address copied to clipboard');
                    },
                  ),
                ),
                const Divider(height: 18, indent: 50),
                DetailRowItem(
                  icon: Icons.phone_outlined,
                  iconColor: const Color(0xFF059669),
                  label: 'Official Chamber Contact',
                  value: phone,
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: muted,
                    ),
                    tooltip: 'Copy Phone',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: phone));
                      toast(context, 'Contact number copied to clipboard');
                    },
                  ),
                ),
                const Divider(height: 18, indent: 50),
                const DetailRowItem(
                  icon: Icons.schedule_rounded,
                  iconColor: navy,
                  label: 'Consultation & Office Hours',
                  value: 'Monday – Saturday: 10:00 AM – 6:30 PM\nSunday: By Prior Appointment Only',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Chamber Facilities Card
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CHAMBER AMENITIES & SERVICES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in [
                  ('Client Consultation Room', 'Dedicated conference facility with video conferencing access'),
                  ('Digital Filing & Vault', 'Encrypted document scanning and e-filing facility'),
                  ('Junior & Associate Roster', 'Coordinated briefing room for chamber associates'),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.done_all_rounded,
                          color: Color(0xFF059669),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Edit Action Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: navy,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onEdit();
            },
            icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
            label: const Text(
              'Update Chamber & Contact',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// 3. Practice Areas & Specialization Full Screen View
class PracticeSpecializationScreen extends StatelessWidget {
  final String advocateName;
  final String practiceAreas;
  final String bio;
  final String primaryCourt;
  final int experienceYears;
  final VoidCallback onEdit;

  const PracticeSpecializationScreen({
    super.key,
    required this.advocateName,
    required this.practiceAreas,
    required this.bio,
    required this.primaryCourt,
    required this.experienceYears,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final areaChips = practiceAreas
        .split(RegExp(r'[,·•\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    return ProfileDetailScaffold(
      title: 'Practice & Specialization',
      subtitle: 'Legal areas of expertise & bio',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Domains of Practice
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PRACTICE SPECIALIZATIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                if (areaChips.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final area in areaChips)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.balance_rounded,
                                size: 14,
                                color: Color(0xFF1D4ED8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                area,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E40AF),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  )
                else
                  Text(
                    practiceAreas,
                    style: const TextStyle(fontSize: 13, color: ink),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Professional Bio
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PROFESSIONAL BIOGRAPHY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    bio.isNotEmpty
                        ? bio
                        : 'Practicing advocate registered with State Bar Council, representing clients in trial and appellate matters.',
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Standing and Appearances
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BAR STANDING & JURISDICTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                DetailRowItem(
                  icon: Icons.work_history_outlined,
                  iconColor: teal,
                  label: 'Experience Standing',
                  value: '$experienceYears+ Years of Active Bar Practice',
                ),
                const Divider(height: 18, indent: 50),
                DetailRowItem(
                  icon: Icons.account_balance_outlined,
                  iconColor: navy,
                  label: 'Primary Forum',
                  value: primaryCourt,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Edit Action Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: navy,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onEdit();
            },
            icon: const Icon(Icons.edit_note_rounded, size: 20),
            label: const Text(
              'Edit Practice Areas & Bio',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// 4. Account & Cloud Sync Status Full Screen View
class AccountStatusScreen extends StatelessWidget {
  final String advocateName;
  final String email;
  final String phone;
  final String uid;
  final VoidCallback onSignOut;

  const AccountStatusScreen({
    super.key,
    required this.advocateName,
    required this.email,
    required this.phone,
    required this.uid,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileDetailScaffold(
      title: 'Account & Sync Status',
      subtitle: 'Session status & encrypted sync',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Live Sync Status Card
          DetailCard(
            backgroundColor: const Color(0xFFF0FDF4),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.cloud_done_rounded,
                    color: Color(0xFF059669),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Active & Synchronized',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF065F46),
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: Color(0xFF059669),
                          ),
                        ],
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Connected to VakilSetu Secure Network',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Account Credentials
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ADVOCATE IDENTITY CREDENTIALS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                DetailRowItem(
                  icon: Icons.person_outline_rounded,
                  iconColor: navy,
                  label: 'Advocate Account',
                  value: advocateName,
                ),
                const Divider(height: 18, indent: 50),
                DetailRowItem(
                  icon: Icons.mail_outline_rounded,
                  iconColor: const Color(0xFF147BEA),
                  label: 'Registered Email',
                  value: email,
                ),
                const Divider(height: 18, indent: 50),
                DetailRowItem(
                  icon: Icons.phone_outlined,
                  iconColor: teal,
                  label: 'Verified Phone',
                  value: phone,
                ),
                const Divider(height: 18, indent: 50),
                DetailRowItem(
                  icon: Icons.fingerprint_rounded,
                  iconColor: slateBlue,
                  label: 'VakilSetu Security Identifier',
                  value: uid.length > 16 ? '${uid.substring(0, 16)}…' : uid,
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: muted),
                    tooltip: 'Copy ID',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: uid));
                      toast(context, 'Security ID copied to clipboard');
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Security & Protection Card
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DATA PRIVILEGE & ENCRYPTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in [
                  ('256-Bit Transport Encryption', 'All chamber messages and filings are transmitted over TLS 1.3 encrypted tunnels.'),
                  ('Advocate-Client Privilege', 'Data access restricted strictly to verified legal counsel.'),
                  ('Real-Time Cloud Persistence', 'Profile updates, channel subscriptions, and documents remain securely stored.'),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.shield_outlined,
                          color: navy,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Sign Out Action Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFE53935),
              side: const BorderSide(color: Color(0xFFFFCDD2), width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: onSignOut,
            icon: const Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 19),
            label: const Text(
              'Sign Out of this Device',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// 5. Security & Verification Full Screen View
class AdvocateVerificationScreen extends StatelessWidget {
  final String advocateName;
  final String enrollmentNumber;
  final String stateBar;

  const AdvocateVerificationScreen({
    super.key,
    required this.advocateName,
    required this.enrollmentNumber,
    required this.stateBar,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileDetailScaffold(
      title: 'Security & Verification',
      subtitle: 'Bar authentication & legal standards',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailCard(
            backgroundColor: const Color(0xFFFFFBEB),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const LegalIcon(
                    'verified',
                    size: 30,
                    color: Color(0xFFD97706),
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verified Advocate Standing',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF92400E),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Digital identity certified for court channels & chambers',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AUTHENTICATION ATTRIBUTES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                DetailRowItem(
                  icon: Icons.person_rounded,
                  iconColor: navy,
                  label: 'Verified Practitioner',
                  value: advocateName,
                ),
                const Divider(height: 18, indent: 50),
                DetailRowItem(
                  icon: Icons.badge_rounded,
                  iconColor: teal,
                  label: 'Bar Registration Number',
                  value: enrollmentNumber,
                ),
                const Divider(height: 18, indent: 50),
                DetailRowItem(
                  icon: Icons.account_balance_rounded,
                  iconColor: const Color(0xFF147BEA),
                  label: 'State Bar Affiliation',
                  value: stateBar,
                ),
                const Divider(height: 18, indent: 50),
                const DetailRowItem(
                  icon: Icons.verified_user_rounded,
                  iconColor: Color(0xFF059669),
                  label: 'Verification Level',
                  value: 'Tier 1 Official Bar Verification',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CONFIDENTIALITY COMPLIANCE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                for (final point in [
                  'Complies with Bar Council of India standards for digital advocate communications.',
                  'Restricted courtroom access: only verified advocates can access judge circulars and case listings.',
                  'Tamper-proof audit logging of official case filings.',
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 16,
                          color: Color(0xFF059669),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF334155),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 6. Case Files & Documents Full Screen View
class CaseFilesDocumentsScreen extends StatelessWidget {
  final VoidCallback onOpenDocuments;

  const CaseFilesDocumentsScreen({
    super.key,
    required this.onOpenDocuments,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileDetailScaffold(
      title: 'Digital Case Files',
      subtitle: 'Encrypted document vault & filings',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: slateBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.folder_shared_rounded,
                        color: slateBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LEGAL DOCUMENT VAULT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: muted,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Synced Filings & Attachments',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              fontFamily: 'Manrope',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your digital vault synchronizes official petitions, court orders, causelists, and shared advocate attachments. Files are stored securely and accessible across your mobile workspace.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SUPPORTED DOCUMENT TYPES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in [
                  ('Court Orders & Causelists', 'Official PDF notices and bench hearing orders.'),
                  ('Petition Drafts & Case Notes', 'Draft filings, affidavits, and precedent research briefs.'),
                  ('Evidence & Client Exhibits', 'Secure photographic records and scanned trial exhibits.'),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.description_outlined,
                          color: navy,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: ink,
                                ),
                              ),
                              Text(
                                item.$2,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: navy,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              onOpenDocuments();
            },
            icon: const Icon(Icons.folder_open_rounded, size: 20),
            label: const Text(
              'Open Workspace Documents Tab',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// 7. Help Center Full Screen View
class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileDetailScaffold(
      title: 'Help Center & Support',
      subtitle: 'Bar support desk & assistance',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ADVOCATE SUPPORT DESK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                DetailRowItem(
                  icon: Icons.mail_outline_rounded,
                  iconColor: const Color(0xFF147BEA),
                  label: 'Official Email Support',
                  value: 'support@vakilsetu.in',
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: muted),
                    tooltip: 'Copy Email',
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(text: 'support@vakilsetu.in'),
                      );
                      toast(context, 'Support email copied');
                    },
                  ),
                ),
                const Divider(height: 18, indent: 50),
                DetailRowItem(
                  icon: Icons.headset_mic_outlined,
                  iconColor: const Color(0xFF059669),
                  label: 'Advocate Toll-Free Helpline',
                  value: '1800-VAKIL-SETU (1800-82545-7388)',
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 16, color: muted),
                    tooltip: 'Copy Helpline',
                    onPressed: () {
                      Clipboard.setData(
                        const ClipboardData(text: '1800825457388'),
                      );
                      toast(context, 'Helpline number copied');
                    },
                  ),
                ),
                const Divider(height: 18, indent: 50),
                const DetailRowItem(
                  icon: Icons.access_time_rounded,
                  iconColor: navy,
                  label: 'Operating Hours',
                  value: 'Monday – Saturday: 9:00 AM – 8:00 PM\nSunday: Emergency Court Filings Only',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FREQUENTLY ASKED QUESTIONS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                for (final faq in [
                  ('How do I join official court channels?', 'Open the Courts tab and tap "Join" on any High Court or District Court forum.'),
                  ('How do I create a private chamber group?', 'Navigate to the Groups tab, tap "+ Create Group", and invite registered advocates.'),
                  ('Can I customize my profile credentials?', 'Yes, tap "Personal Information" on your profile screen to edit your contact and practice details.'),
                ]) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          faq.$1,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ink,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          faq.$2,
                          style: const TextStyle(
                            fontSize: 12,
                            color: muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 8. Privacy & Security Policy Full Screen View
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProfileDetailScaffold(
      title: 'Privacy & Security Policy',
      subtitle: 'Advocate-Client privilege and data governance',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADVOCATE-CLIENT PRIVILEGE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'All digital communications, case attachments, and consultation notes processed on VakilSetu are protected under professional legal privilege pursuant to the Indian Evidence Act, 1872 and the Advocates Act, 1961.\n\nCommunications exchanged between advocates, chamber associates, and clients remain strictly confidential.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.55,
                    color: Color(0xFF334155),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 16),
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DATA PROTECTION & RETENTION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  '1. Zero Third-Party Monetization: VakilSetu never sells, licenses, or monetizes advocate data.\n\n2. Cryptographic Security: All document transmissions use industry-standard encryption protocols.\n\n3. Account Deletion & Data Rights: Registered advocates maintain complete control over their uploaded drafts and filings.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.55,
                    color: Color(0xFF475569),
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

/// 9. App Language Selection Screen (Standard English Only)
class AppLanguageScreen extends StatelessWidget {
  const AppLanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ProfileDetailScaffold(
      title: 'App Language',
      subtitle: 'Official legal language & locale',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: teal.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.language_rounded,
                        color: teal,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LOCALE SETTINGS',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: muted,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Court & App Language',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              fontFamily: 'Manrope',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Under standard legal practice and Article 348 of the Constitution of India, official court listings, cause lists, orders, and advocate communications are standardized in English.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF475569),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DetailCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AVAILABLE LANGUAGES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 14),
                // Only English option provided
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'EN',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF166534),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'English (India)',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: ink,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF16A34A),
                                    borderRadius: BorderRadius.all(Radius.circular(4)),
                                  ),
                                  child: const Text(
                                    'ACTIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Standard Indian Legal & Court Terminology',
                              style: TextStyle(fontSize: 11, color: muted),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF16A34A),
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DetailCard(
            backgroundColor: const Color(0xFFF8FAFC),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: slateBlue,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Constitutional Legal Standard',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: navy,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'VakilSetu maintains English as the unified system language to guarantee precision in legal drafting, statutory citation, and inter-advocate correspondence across all State Bars.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.45,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: navy,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              toast(context, 'Language set to English (India)');
            },
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text(
              'Confirm English (Standard)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

