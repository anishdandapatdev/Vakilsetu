import 'package:flutter/material.dart';

import '../../../app/demo_store.dart';
import '../../../design_system/ui.dart';
import '../domain/advocate_profile.dart';

class ProfilePage extends StatefulWidget {
  final DemoStore store;
  final VoidCallback onSaved;
  final ProfileRepository? repository;
  const ProfilePage({
    super.key,
    required this.store,
    required this.onSaved,
    this.repository,
  });
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, enrollment;
  late String court;
  int avatar = 0;
  bool saving = false;
  Map<String, String> courtIds = const {};
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.store.name);
    enrollment = TextEditingController(text: widget.store.enrollment);
    court = widget.store.court;
    avatar = widget.store.avatar;
    if (widget.repository != null) _loadCourts();
  }

  Future<void> _loadCourts() async {
    try {
      final result = await widget.repository!.listCourtIdsByName();
      if (mounted) setState(() => courtIds = result);
    } on Object catch (error) {
      if (mounted) toast(context, 'Could not load courts: $error');
    }
  }

  Future<void> _save() async {
    if (!(form.currentState?.validate() ?? false) || saving) return;
    if (widget.repository != null && courtIds[court] == null) {
      toast(context, 'The selected court is not available on the backend.');
      return;
    }
    setState(() => saving = true);
    try {
      if (widget.repository != null) {
        await widget.repository!.save(ProfileUpdate(
          fullName: name.text.trim(),
          enrollmentNumber: enrollment.text.trim(),
          primaryCourtId: courtIds[court]!,
        ));
      }
      widget.store.avatar = avatar;
      widget.store.updateProfile(name.text.trim(), enrollment.text.trim(), court);
      if (!mounted) return;
      toast(context, widget.repository == null
          ? 'Profile saved locally · verification pending'
          : 'Profile submitted · verification pending');
      widget.onSaved();
    } on Object catch (error) {
      if (mounted) toast(context, 'Could not save profile: $error');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    enrollment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageTitle(
        'Your advocate profile',
        'Help your colleagues find and recognize you.',
      ),
      Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Surface(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Avatar(
                        avatar == 0
                            ? 'AK'
                            : avatar == 1
                            ? 'AV'
                            : 'VS',
                        size: 74,
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Profile photo (optional)',
                              style: heading(14),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => avatar = (avatar + 1) % 3),
                              child: const Text('Choose sample avatar'),
                            ),
                            const Text(
                              'Photo upload will be connected later.',
                              style: TextStyle(fontSize: 10, color: muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Full name',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 9),
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(hintText: 'Full name'),
                    validator: (v) => (v ?? '').trim().length > 2
                        ? null
                        : 'Enter your full name.',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Bar Council enrollment number',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 9),
                  TextFormField(
                    controller: enrollment,
                    decoration: const InputDecoration(hintText: 'D/1234/2018'),
                    validator: (v) =>
                        RegExp(r'^[A-Za-z]+/\d+/\d{4}$')
                            .hasMatch((v ?? '').trim())
                        ? null
                        : 'Use a format such as D/1234/2018.',
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Primary practice court',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 9),
                  DropdownButtonFormField<String>(
                    initialValue: court,
                    isExpanded: true,
                    items: courts
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              c,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (c) => court = c!,
                  ),
                  const SizedBox(height: 24),
                  const Surface(
                    color: paleBronze,
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'Profile changes require verification. A completed form does not automatically grant a verified badge.',
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: saving ? null : _save,
                    child: Text(saving ? 'Saving…' : 'Save profile'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  );
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
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageTitle('Settings', 'Your profile and preferences.'),
      Surface(
        child: Row(
          children: [
            const Avatar('AK', size: 60),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name, style: heading(17)),
                  const SizedBox(height: 5),
                  Text(
                    store.court,
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onProfile, child: const Text('Edit profile')),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Surface(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            SwitchListTile(
              title: const Text(
                'Notification preference',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Local preference only; push delivery is not connected.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
              value: store.notifications,
              onChanged: (v) {
                store.notifications = v;
                store.refresh();
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text(
                'Read receipt preference',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Preview setting for future encrypted receipts.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
              value: store.receipts,
              onChanged: (v) {
                store.receipts = v;
                store.refresh();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.devices_outlined, color: slateBlue),
              title: const Text(
                'Linked devices',
                style: TextStyle(fontSize: 14),
              ),
              subtitle: const Text(
                'Device linking is not connected in this preview.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => info(
                context,
                'Linked devices',
                'This local preview does not register or link devices. Trusted-device linking and revocation will be integrated with the encryption provider.',
              ),
            ),
            const Divider(),
            ListTile(
              leading: const LegalIcon('verified', color: teal),
              title: const Text('Verification status'),
              subtitle: Text(
                store.pending
                    ? 'Pending verification'
                    : 'Sample profile · not a real verified account',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('About this preview', style: heading(16)),
            const SizedBox(height: 9),
            const Text(
              'Changes are kept in memory for this session. No private messages are transmitted. Authentication, E2EE and cloud storage belong to the next integration stage.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onSignOut,
              icon: const Icon(Icons.logout, size: 18),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    ],
  );
}
