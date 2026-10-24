import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../../authentication/presentation/login_page.dart';
import '../data/firebase_profile_repository.dart';
import '../domain/advocate_profile.dart';

class ProfilePage extends StatefulWidget {
  final DemoStore store;
  final VoidCallback onSaved;
  final VoidCallback? onBack;
  final VoidCallback? onSignOut;
  final ProfileRepository? repository;

  const ProfilePage({
    super.key,
    required this.store,
    required this.onSaved,
    this.onBack,
    this.onSignOut,
    this.repository,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, enrollment, practice, bio;
  late String court;
  int avatar = 0;
  bool saving = false;
  bool darkModePreview = false;
  Map<String, String> courtIds = const {};
  late ProfileRepository _repo;

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? FirebaseProfileRepository();
    name = TextEditingController(text: widget.store.name);
    enrollment = TextEditingController(text: widget.store.enrollment);
    practice = TextEditingController(text: 'Civil litigation · Arbitration');
    bio = TextEditingController(
      text: 'Practicing advocate registered with Bar Council of Delhi.',
    );
    court = widget.store.court;
    avatar = widget.store.avatar;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final courts = await _repo.listCourtIdsByName();
      if (mounted) setState(() => courtIds = courts);

      final myProfile = await _repo.getMine();
      if (myProfile != null && mounted) {
        setState(() {
          name.text = myProfile.fullName;
          enrollment.text = myProfile.enrollmentNumber;
          if (myProfile.primaryCourtName != null &&
              myProfile.primaryCourtName!.isNotEmpty) {
            court = myProfile.primaryCourtName!;
          }
          if (myProfile.practiceAreas != null &&
              myProfile.practiceAreas!.isNotEmpty) {
            practice.text = myProfile.practiceAreas!;
          }
          if (myProfile.bio != null && myProfile.bio!.isNotEmpty) {
            bio.text = myProfile.bio!;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    }
  }

  Future<void> _save() async {
    final primaryCourtId = courtIds[court] ?? 'delhi_high_court';

    setState(() => saving = true);
    try {
      await _repo.save(
        ProfileUpdate(
          fullName: name.text.trim(),
          enrollmentNumber: enrollment.text.trim(),
          primaryCourtId: primaryCourtId,
          practiceAreas: practice.text.trim(),
          bio: bio.text.trim(),
        ),
      );
      widget.store.avatar = avatar;
      widget.store.updateProfile(
        name.text.trim(),
        enrollment.text.trim(),
        court,
      );
      if (!mounted) return;
      toast(context, 'Profile updated in Cloud Firestore · Verified advocate');
      widget.onSaved();
    } on Object catch (error) {
      if (mounted) toast(context, 'Could not save profile: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Sign out of VakilSetu?'),
        content: const Text(
          'You will be returned to the login screen. Your advocate profile and channel data remain saved in Cloud Firestore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    if (widget.onSignOut != null) {
      widget.onSignOut!();
    } else {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  void _openLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  void _openEditPersonalInfo() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          padding: EdgeInsets.fromLTRB(
            22,
            20,
            22,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4E1EA),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Edit Personal Information', style: heading(18)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: muted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Full Name', style: _fieldTitleStyle()),
                const SizedBox(height: 6),
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_outline_rounded, color: navy),
                    hintText: 'Advocate full name',
                  ),
                ),
                const SizedBox(height: 14),
                Text('Bar Enrollment Number', style: _fieldTitleStyle()),
                const SizedBox(height: 6),
                TextFormField(
                  controller: enrollment,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.badge_outlined, color: navy),
                    hintText: 'e.g. D/3421/2017',
                  ),
                ),
                const SizedBox(height: 14),
                Text('Primary Court', style: _fieldTitleStyle()),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: courtIds.containsKey(court) ? court : (courtIds.keys.firstOrNull ?? court),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_outlined, color: navy),
                  ),
                  items: [
                    for (final c in courtIds.keys)
                      DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setSheetState(() => court = val);
                      setState(() => court = val);
                    }
                  },
                ),
                const SizedBox(height: 14),
                Text('Practice Areas', style: _fieldTitleStyle()),
                const SizedBox(height: 6),
                TextFormField(
                  controller: practice,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.work_outline_rounded, color: navy),
                    hintText: 'Civil Litigation, Arbitration, Corporate',
                  ),
                ),
                const SizedBox(height: 14),
                Text('Professional Bio', style: _fieldTitleStyle()),
                const SizedBox(height: 6),
                TextFormField(
                  controller: bio,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Brief summary of your legal experience and practice',
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _save();
                        },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    saving ? 'Saving…' : 'Save to Firebase',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: heading(17)),
        content: Text(message, style: const TextStyle(fontSize: 13, height: 1.5, color: ink)),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: navy),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  TextStyle _fieldTitleStyle() => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: slateBlue,
      );

  @override
  void dispose() {
    name.dispose();
    enrollment.dispose();
    practice.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    final isLoggedIn = user != null && !user.isAnonymous;
    final userEmail = user?.email ??
        (user?.isAnonymous == true ? 'Guest Session' : 'local_advocate@vakilsetu.in');
    final userUid = user?.uid ?? 'local_preview';
    final advocateName = name.text.isEmpty ? widget.store.name : name.text;
    final initials = advocateName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase())
        .take(2)
        .join();

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFD),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. TOP HEADER (My Profile)
              Row(
                children: [
                  if (widget.onBack != null) ...[
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: navy, size: 20),
                      tooltip: 'Back to Home',
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Profile', style: heading(22)),
                        const SizedBox(height: 2),
                        const Text(
                          'Manage your account and preferences',
                          style: TextStyle(fontSize: 12, color: muted),
                        ),
                      ],
                    ),
                  ),
                  if (!isLoggedIn)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: navy,
                        side: const BorderSide(color: Color(0xFFB9D7F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _openLogin,
                      icon: const Icon(Icons.login_rounded, size: 15),
                      label: const Text('Log In', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_rounded, size: 14, color: Color(0xFF147BEA)),
                          SizedBox(width: 4),
                          Text('Active', style: TextStyle(fontSize: 11, color: Color(0xFF147BEA), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // 2. ADVOCATE PROFILE HERO CARD
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: line),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0C0C2340),
                      blurRadius: 18,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Avatar(initials.isEmpty ? 'AK' : initials, size: 66),
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: navy,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt_rounded, size: 11, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  advocateName,
                                  style: heading(17),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFF147BEA),
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.badge_outlined, size: 13, color: slateBlue),
                              const SizedBox(width: 6),
                              Text(
                                enrollment.text.isEmpty ? widget.store.enrollment : enrollment.text,
                                style: const TextStyle(fontSize: 12, color: slateBlue, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.mail_outline_rounded, size: 13, color: muted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  userEmail,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: muted),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _openEditPersonalInfo,
                      icon: const Icon(Icons.edit_outlined, color: slateBlue, size: 20),
                      tooltip: 'Edit Profile',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. HIGHLIGHT CARD IN APP PRIMARY COLOR (Navy Gradient)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1D3557), // App Primary Navy
                      Color(0xFF0F2644), // Deep Navy
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x241D3557),
                      blurRadius: 18,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'BAR COUNCIL OF DELHI',
                              style: TextStyle(
                                color: Color(0xFFE2F0FE),
                                fontSize: 9,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            enrollment.text.isEmpty ? widget.store.enrollment : enrollment.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Manrope',
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            court,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      alignment: Alignment.center,
                      child: const LegalIcon('verified', size: 32, color: Color(0xFFF5B942)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. THREE STAT METRICS CARDS
              Row(
                children: [
                  _StatCard(
                    icon: Icons.account_balance_outlined,
                    color: const Color(0xFF147BEA),
                    label: 'PRIMARY COURT',
                    value: court.split(' ').take(2).join(' '),
                    subtitle: 'Verified Bar',
                  ),
                  const SizedBox(width: 10),
                  const _StatCard(
                    icon: Icons.work_history_outlined,
                    color: teal,
                    label: 'EXPERIENCE',
                    value: '7+ Years',
                    subtitle: 'Active Practice',
                  ),
                  const SizedBox(width: 10),
                  const _StatCard(
                    icon: Icons.groups_outlined,
                    color: bronze,
                    label: 'CHANNELS',
                    value: '6 Joined',
                    subtitle: 'Real-Time Sync',
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // 5. SECTION: PERSONAL INFORMATION
              const _SectionHeader('PERSONAL INFORMATION'),
              _SectionCard(
                children: [
                  _ProfileRow(
                    icon: Icons.person_outline_rounded,
                    iconColor: const Color(0xFF147BEA),
                    title: 'Personal Information',
                    subtitle: '$advocateName · ${practice.text}',
                    onTap: _openEditPersonalInfo,
                  ),
                  _ProfileRow(
                    icon: Icons.badge_outlined,
                    iconColor: teal,
                    title: 'Bar Council Credentials',
                    subtitle: enrollment.text.isEmpty ? widget.store.enrollment : enrollment.text,
                    onTap: () => _showInfoDialog(
                      'Bar Council Credentials',
                      'Registration Number: ${enrollment.text}\nState Bar: Bar Council of Delhi\nVerification Status: Verified Advocate\nDigitally signed via Cloud Firestore.',
                    ),
                  ),
                  _ProfileRow(
                    icon: Icons.location_on_outlined,
                    iconColor: const Color(0xFFE65100),
                    title: 'Court & Chamber Address',
                    subtitle: '$court, Chambers Block',
                    onTap: () => _showInfoDialog(
                      'Court & Chambers',
                      'Primary Court: $court\nChambers: Block C, Lawyers Chambers, New Delhi\nCourt Channel ID: ${courtIds[court] ?? "delhi_high_court"}',
                    ),
                  ),
                ],
              ),

              // 6. SECTION: PRACTICE & WORKSPACE
              const _SectionHeader('LEGAL PRACTICE & WORKSPACE'),
              _SectionCard(
                children: [
                  _ProfileRow(
                    icon: Icons.balance_rounded,
                    iconColor: navy,
                    title: 'Practice Areas & Specialization',
                    subtitle: practice.text,
                    onTap: _openEditPersonalInfo,
                  ),
                  _ProfileRow(
                    icon: Icons.folder_open_rounded,
                    iconColor: slateBlue,
                    title: 'Digital Case Files & Documents',
                    subtitle: 'Encrypted document store & filings',
                    onTap: () => _showInfoDialog(
                      'Digital Case Files',
                      'Access synced court filings, causelists, and shared advocate attachments from your Workspace Documents tab.',
                    ),
                  ),
                ],
              ),

              // 7. SECTION: ACCOUNT & SECURITY
              const _SectionHeader('ACCOUNT & SECURITY'),
              _SectionCard(
                children: [
                  _ProfileRow(
                    icon: Icons.cloud_done_outlined,
                    iconColor: teal,
                    title: 'Firebase Account Status',
                    subtitle: '$userEmail (UID: ${userUid.substring(0, userUid.length > 12 ? 12 : userUid.length)}…)',
                    onTap: () => _showInfoDialog(
                      'Firebase Session',
                      'Connected to Firebase Cloud Firestore.\nEmail: $userEmail\nUID: $userUid\nSecurity: Real-time rules enforced.',
                    ),
                  ),
                  _ProfileRow(
                    icon: Icons.shield_outlined,
                    iconColor: navy,
                    title: 'Security & Verification',
                    subtitle: 'Official advocate verification badge enabled',
                    onTap: () => _showInfoDialog(
                      'Advocate Verification',
                      'Your digital credentials and bar enrollment are verified on the VakilSetu legal network.',
                    ),
                  ),
                ],
              ),

              // 8. SECTION: APP SETTINGS
              const _SectionHeader('APP SETTINGS'),
              _SectionCard(
                children: [
                  _ProfileRow(
                    icon: Icons.notifications_none_rounded,
                    iconColor: const Color(0xFF147BEA),
                    title: 'Notifications',
                    subtitle: 'Court announcements & case notices',
                    trailing: Switch.adaptive(
                      value: widget.store.notifications,
                      activeThumbColor: navy,
                      onChanged: (v) {
                        setState(() {
                          widget.store.notifications = v;
                          widget.store.refresh();
                        });
                      },
                    ),
                  ),
                  _ProfileRow(
                    icon: Icons.dark_mode_outlined,
                    iconColor: slateBlue,
                    title: 'Dark Mode',
                    subtitle: 'Appearance preference',
                    trailing: Switch.adaptive(
                      value: darkModePreview,
                      activeThumbColor: navy,
                      onChanged: (v) => setState(() => darkModePreview = v),
                    ),
                  ),
                  _ProfileRow(
                    icon: Icons.language_rounded,
                    iconColor: teal,
                    title: 'Language',
                    subtitle: 'English (India)',
                    onTap: () => toast(context, 'Language: English (India)'),
                  ),
                ],
              ),

              // 9. SECTION: SUPPORT
              const _SectionHeader('SUPPORT & LEGAL'),
              _SectionCard(
                children: [
                  _ProfileRow(
                    icon: Icons.help_outline_rounded,
                    iconColor: navy,
                    title: 'Help Center',
                    subtitle: 'Bar Association support & FAQs',
                    onTap: () => _showInfoDialog(
                      'Help & Support',
                      'VakilSetu Advocate Support Desk\nEmail: support@vakilsetu.in\nEmergency Bar Helpline: 1800-VAKIL-SETU',
                    ),
                  ),
                  _ProfileRow(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: slateBlue,
                    title: 'Privacy & Security Policy',
                    subtitle: 'Advocate-Client privilege & data policy',
                    onTap: () => _showInfoDialog(
                      'Privacy & Terms',
                      'VakilSetu complies with Bar Council of India standards. Case notes, filings, and communications are restricted to authenticated advocates.',
                    ),
                  ),
                ],
              ),

              // 10. LOG OUT BUTTON (Matching the reference screenshot)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 24, bottom: 16),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFE53935),
                    side: const BorderSide(color: Color(0xFFFFCDD2), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _handleSignOut,
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFE53935), size: 20),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 18),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: slateBlue,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
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
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, indent: 64, endIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _ProfileRow({
    required this.icon,
    this.iconColor = navy,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(fontSize: 11, color: muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFFB0C3D0),
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String subtitle;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060C2340),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: muted,
                letterSpacing: 0.8,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ink,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  final DemoStore store;
  final VoidCallback onProfile, onSignOut;
  const SettingsPage({
    super.key,
    required this.store,
    required this.onProfile,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return ProfilePage(
      store: store,
      onSaved: () {},
      onSignOut: onSignOut,
    );
  }
}
