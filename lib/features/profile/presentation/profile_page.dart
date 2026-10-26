import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../../authentication/presentation/login_page.dart';
import '../data/firebase_profile_repository.dart';
import '../domain/advocate_profile.dart';

class _AvatarTheme {
  final String name;
  final Color bgColor;
  final Color textColor;
  const _AvatarTheme(this.name, this.bgColor, this.textColor);
}

const _avatarThemes = [
  _AvatarTheme('Navy Sapphire', Color(0xFF1D3557), Color(0xFFE2F0FE)),
  _AvatarTheme('Emerald Teal', Color(0xFF0F766E), Color(0xFFCCFBF1)),
  _AvatarTheme('Warm Bronze', Color(0xFFB45309), Color(0xFFFEF3C7)),
  _AvatarTheme('Royal Slate', Color(0xFF334155), Color(0xFFF1F5F9)),
  _AvatarTheme('Ruby Crimson', Color(0xFF9F1239), Color(0xFFFFE4E6)),
  _AvatarTheme('Imperial Purple', Color(0xFF6B21A8), Color(0xFFF3E8FF)),
];

class ProfilePage extends StatefulWidget {
  final DemoStore store;
  final VoidCallback onSaved;
  final VoidCallback? onBack;
  final VoidCallback? onSignOut;
  final ProfileRepository? repository;
  final FirebaseAuth? auth;

  const ProfilePage({
    super.key,
    required this.store,
    required this.onSaved,
    this.onBack,
    this.onSignOut,
    this.repository,
    this.auth,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final form = GlobalKey<FormState>();
  late TextEditingController name;
  late TextEditingController enrollment;
  late TextEditingController practice;
  late TextEditingController bio;
  late TextEditingController phone;
  late TextEditingController experienceYears;
  late TextEditingController stateBar;
  late TextEditingController chamberAddress;
  late String court;
  int avatar = 0;
  bool saving = false;
  bool darkModePreview = false;
  Map<String, String> courtIds = const {};
  late ProfileRepository _repo;

  FirebaseAuth? get _auth {
    if (widget.auth != null) return widget.auth;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  User? get _currentUser {
    try {
      return _auth?.currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? FirebaseProfileRepository();
    name = TextEditingController(text: widget.store.name);
    enrollment = TextEditingController(text: widget.store.enrollment);
    practice = TextEditingController(text: widget.store.practiceAreas);
    bio = TextEditingController(text: widget.store.bio);
    phone = TextEditingController(text: widget.store.phone);
    experienceYears = TextEditingController(
      text: '${widget.store.experienceYears}',
    );
    stateBar = TextEditingController(text: widget.store.stateBar);
    chamberAddress = TextEditingController(text: widget.store.chamberAddress);
    court = widget.store.court;
    avatar = widget.store.avatar;
    widget.store.addListener(_onStoreChanged);
    _loadInitialData();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
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
          if (myProfile.phone != null && myProfile.phone!.isNotEmpty) {
            phone.text = myProfile.phone!;
          }
          if (myProfile.experienceYears != null) {
            experienceYears.text = '${myProfile.experienceYears}';
          }
          if (myProfile.stateBar != null && myProfile.stateBar!.isNotEmpty) {
            stateBar.text = myProfile.stateBar!;
          }
          if (myProfile.chamberAddress != null &&
              myProfile.chamberAddress!.isNotEmpty) {
            chamberAddress.text = myProfile.chamberAddress!;
          }
        });

        widget.store.updateProfile(
          name.text,
          enrollment.text,
          court,
          phone: phone.text,
          experienceYears: int.tryParse(experienceYears.text),
          stateBar: stateBar.text,
          chamberAddress: chamberAddress.text,
          practiceAreas: practice.text,
          bio: bio.text,
        );
      }
    } catch (e) {
      debugPrint('Error loading profile data: $e');
    }
  }

  Future<void> _save() async {
    final primaryCourtId = courtIds[court] ?? 'saket_district_court';
    final parsedExp = int.tryParse(experienceYears.text.trim()) ?? 7;

    setState(() => saving = true);
    try {
      await _repo.save(
        ProfileUpdate(
          fullName: name.text.trim(),
          enrollmentNumber: enrollment.text.trim(),
          primaryCourtId: primaryCourtId,
          practiceAreas: practice.text.trim(),
          bio: bio.text.trim(),
          experienceYears: parsedExp,
          phone: phone.text.trim(),
          chamberAddress: chamberAddress.text.trim(),
          stateBar: stateBar.text.trim(),
        ),
      );
      widget.store.avatar = avatar;
      widget.store.updateProfile(
        name.text.trim(),
        enrollment.text.trim(),
        court,
        phone: phone.text.trim(),
        experienceYears: parsedExp,
        stateBar: stateBar.text.trim(),
        chamberAddress: chamberAddress.text.trim(),
        practiceAreas: practice.text.trim(),
        bio: bio.text.trim(),
        avatar: avatar,
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
      await _auth?.signOut();
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

  void _openAvatarCustomizer() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final initials = (name.text.isEmpty ? widget.store.name : name.text)
              .split(' ')
              .where((s) => s.isNotEmpty)
              .map((s) => s[0].toUpperCase())
              .take(2)
              .join();
          final currentTheme = _avatarThemes[avatar % _avatarThemes.length];

          return Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    Text('Avatar Appearance', style: heading(18)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: muted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: currentTheme.bgColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: currentTheme.bgColor.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials.isEmpty ? 'AK' : initials,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                        fontSize: 26,
                        color: currentTheme.textColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    currentTheme.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: navy,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'SELECT PALETTE PRESET',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: slateBlue,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: List.generate(_avatarThemes.length, (idx) {
                    final theme = _avatarThemes[idx];
                    final isSelected = avatar == idx;
                    return GestureDetector(
                      onTap: () {
                        setSheetState(() => avatar = idx);
                        setState(() => avatar = idx);
                        widget.store.avatar = idx;
                        widget.store.refresh();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: theme.bgColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFF5B942)
                                : Colors.white,
                            width: isSelected ? 3 : 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 22,
                              )
                            : null,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: navy,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
                    hintText: 'e.g. D/1234/2018',
                  ),
                ),
                const SizedBox(height: 14),
                Text('State Bar Council', style: _fieldTitleStyle()),
                const SizedBox(height: 6),
                TextFormField(
                  controller: stateBar,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_rounded, color: navy),
                    hintText: 'e.g. Bar Council of Delhi',
                  ),
                ),
                const SizedBox(height: 14),
                Text('Primary Court', style: _fieldTitleStyle()),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: courtIds.containsKey(court)
                      ? court
                      : (courtIds.keys.firstOrNull ?? court),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.account_balance_outlined, color: navy),
                  ),
                  items: [
                    for (final c in courtIds.keys)
                      DropdownMenuItem(
                        value: c,
                        child: Text(c, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setSheetState(() => court = val);
                      setState(() => court = val);
                    }
                  },
                ),
                const SizedBox(height: 14),
                Text('Experience (Years in Practice)', style: _fieldTitleStyle()),
                const SizedBox(height: 6),
                TextFormField(
                  controller: experienceYears,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.work_history_outlined, color: navy),
                    hintText: 'e.g. 7',
                  ),
                ),
                const SizedBox(height: 14),
                Text('Contact / Mobile Number', style: _fieldTitleStyle()),
                const SizedBox(height: 6),
                TextFormField(
                  controller: phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.phone_outlined, color: navy),
                    hintText: 'e.g. +91 98101 23456',
                  ),
                ),
                const SizedBox(height: 14),
                Text('Chamber / Office Address', style: _fieldTitleStyle()),
                const SizedBox(height: 6),
                TextFormField(
                  controller: chamberAddress,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.location_on_outlined, color: navy),
                    hintText: 'e.g. Chamber 402, Lawyers Block, Saket District Court',
                  ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          await _save();
                        },
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: Text(
                    saving ? 'Saving…' : 'Save to Cloud Firestore',
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
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, height: 1.5, color: ink),
        ),
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
    widget.store.removeListener(_onStoreChanged);
    name.dispose();
    enrollment.dispose();
    practice.dispose();
    bio.dispose();
    phone.dispose();
    experienceYears.dispose();
    stateBar.dispose();
    chamberAddress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _currentUser;
    final isLoggedIn = user != null && !user.isAnonymous;
    final userEmail = user?.email ??
        (user?.isAnonymous == true
            ? 'Guest Session'
            : 'local_advocate@vakilsetu.in');
    final userUid = user?.uid ?? 'local_preview';
    final advocateName = name.text.isEmpty ? widget.store.name : name.text;
    final initials = advocateName
        .split(' ')
        .where((s) => s.isNotEmpty)
        .map((s) => s[0].toUpperCase())
        .take(2)
        .join();
    final activeTheme = _avatarThemes[avatar % _avatarThemes.length];
    final activeStateBar = stateBar.text.isNotEmpty
        ? stateBar.text
        : widget.store.stateBar;
    final activeEnrollment = enrollment.text.isNotEmpty
        ? enrollment.text
        : widget.store.enrollment;
    final activePhone = phone.text.isNotEmpty ? phone.text : widget.store.phone;
    final activeChamber = chamberAddress.text.isNotEmpty
        ? chamberAddress.text
        : widget.store.chamberAddress;
    final activeExp =
        int.tryParse(experienceYears.text) ?? widget.store.experienceYears;

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
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: navy,
                        size: 20,
                      ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      onPressed: _openLogin,
                      icon: const Icon(Icons.login_rounded, size: 15),
                      label: const Text(
                        'Log In',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Color(0xFF147BEA),
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF147BEA),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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
                    GestureDetector(
                      onTap: _openAvatarCustomizer,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            width: 66,
                            height: 66,
                            decoration: BoxDecoration(
                              color: activeTheme.bgColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: activeTheme.bgColor.withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials.isEmpty ? 'AK' : initials,
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                                color: activeTheme.textColor,
                              ),
                            ),
                          ),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: navy,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 11,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
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
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified_rounded,
                                size: 16,
                                color: Color(0xFF147BEA),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            court,
                            style: const TextStyle(
                              fontSize: 12,
                              color: muted,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Reg: $activeEnrollment',
                            style: const TextStyle(
                              fontSize: 11,
                              color: slateBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        color: navy,
                        size: 20,
                      ),
                      onPressed: _openEditPersonalInfo,
                      tooltip: 'Edit Profile Information',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. BAR COUNCIL DIGITAL ID BADGE CARD
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              activeStateBar.toUpperCase(),
                              style: const TextStyle(
                                color: Color(0xFFE2F0FE),
                                fontSize: 9,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            activeEnrollment,
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
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const LegalIcon(
                        'verified',
                        size: 32,
                        color: Color(0xFFF5B942),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. THREE STAT METRICS CARDS (100% Dynamic)
              Row(
                children: [
                  _StatCard(
                    icon: Icons.work_history_outlined,
                    color: teal,
                    label: 'EXPERIENCE',
                    value: '$activeExp Years',
                    subtitle: 'Active Practice',
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    icon: Icons.account_balance_outlined,
                    color: const Color(0xFF147BEA),
                    label: 'COURTS',
                    value: '${widget.store.joined.length} Channels',
                    subtitle: 'Real-Time Sync',
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    icon: Icons.groups_outlined,
                    color: bronze,
                    label: 'GROUPS',
                    value: '${widget.store.joinedGroupIds.length} Joined',
                    subtitle: 'Chambers & Teams',
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
                    subtitle: '$activeEnrollment · $activeStateBar',
                    onTap: () => _showInfoDialog(
                      'Bar Council Credentials',
                      'Registration Number: $activeEnrollment\nState Bar: $activeStateBar\nPrimary Court: $court\nExperience: $activeExp Years\nVerification Status: Verified Advocate\nDigitally signed via Cloud Firestore.',
                    ),
                  ),
                  _ProfileRow(
                    icon: Icons.phone_outlined,
                    iconColor: const Color(0xFF059669),
                    title: 'Contact & Phone',
                    subtitle: activePhone,
                    onTap: _openEditPersonalInfo,
                  ),
                  _ProfileRow(
                    icon: Icons.location_on_outlined,
                    iconColor: const Color(0xFFE65100),
                    title: 'Court & Chamber Address',
                    subtitle: activeChamber,
                    onTap: () => _showInfoDialog(
                      'Court & Chambers',
                      'Primary Court: $court\nChambers: $activeChamber\nCourt Channel ID: ${courtIds[court] ?? "saket_district_court"}',
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
                    subtitle:
                        '$userEmail (UID: ${userUid.substring(0, userUid.length > 12 ? 12 : userUid.length)}…)',
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
                    icon: Icons.palette_outlined,
                    iconColor: bronze,
                    title: 'Avatar Theme Preset',
                    subtitle: activeTheme.name,
                    onTap: _openAvatarCustomizer,
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

              // 10. LOG OUT BUTTON
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
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFE53935),
                    size: 20,
                  ),
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
