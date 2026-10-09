import 'package:flutter/material.dart';

import '../app/demo_store.dart';
import '../design_system/ui.dart';

/// Separate UI-only entry. No role switch is exposed in the advocate client.
class AdminPreviewApp extends StatelessWidget {
  const AdminPreviewApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'VakilSetu · Admin preview',
    theme: appTheme(),
    home: const AdminHome(),
  );
}

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final store = DemoStore();
  final title = TextEditingController(), message = TextEditingController();
  final statuses = {
    'meera': 'Verified',
    'kabir': 'Verified',
    'naina': 'Pending',
    'rohit': 'Pending',
  };
  final activity = <String>[];
  String court = courts.first, filter = 'All', section = 'User verification';
  @override
  void dispose() {
    store.dispose();
    title.dispose();
    message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width > 1000;
    final users = store.advocates
        .where((a) => filter == 'All' || statuses[a.id] == filter)
        .toList();
    final table = Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('User verification'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            children: [
              for (final f in ['All', 'Pending', 'Verified', 'Suspended'])
                ChoiceChip(
                  label: Text(f),
                  selected: filter == f,
                  onSelected: (_) => setState(() => filter = f),
                ),
            ],
          ),
          const SizedBox(height: 18),
          if (users.isEmpty)
            const EmptyState(
              'No users in this category',
              'Try a different status filter.',
            ),
          for (final a in users) ...[
            Row(
              children: [
                Avatar(a.initials),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name, style: heading(13)),
                      const SizedBox(height: 4),
                      Text(
                        '${a.enrollment} · ${a.court}',
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Tag(
                  statuses[a.id]!,
                  color: statuses[a.id] == 'Verified' ? teal : bronze,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children: [
                OutlinedButton(
                  onPressed: statuses[a.id] == 'Verified'
                      ? null
                      : () => setState(() {
                          statuses[a.id] = 'Verified';
                          activity.insert(
                            0,
                            'Approved sample profile: ${a.name}',
                          );
                        }),
                  child: const Text('Approve'),
                ),
                TextButton(
                  onPressed: statuses[a.id] == 'Suspended'
                      ? null
                      : () => setState(() {
                          statuses[a.id] = 'Suspended';
                          activity.insert(
                            0,
                            'Suspended sample profile: ${a.name}',
                          );
                        }),
                  child: const Text('Suspend'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
    final broadcast = Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New court announcement', style: heading(18)),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: court,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Court'),
            items: courts
                .map(
                  (c) => DropdownMenuItem(
                    value: c,
                    child: Text(
                      c,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => court = v!,
          ),
          const SizedBox(height: 18),
          TextField(
            controller: title,
            maxLength: 100,
            decoration: const InputDecoration(
              labelText: 'Title',
              hintText: 'Announcement title',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: message,
            maxLength: 1000,
            minLines: 4,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Write your court announcement',
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () {
              if (title.text.trim().isEmpty || message.text.trim().isEmpty) {
                toast(context, 'Enter an announcement title and message.');
                return;
              }
              setState(() {
                store.notices.insert(
                  0,
                  DemoNotice(court, title.text.trim(), message.text.trim()),
                );
                activity.insert(0, 'Published sample announcement to $court');
                title.clear();
                message.clear();
              });
              toast(context, 'Announcement added to this admin preview only.');
            },
            icon: const Icon(Icons.campaign_outlined, size: 18),
            label: const Text('Publish announcement'),
          ),
          const SizedBox(height: 25),
          Text('Recent announcements', style: heading(15)),
          const SizedBox(height: 14),
          for (final n in store.notices.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Row(
                children: [
                  const LegalIcon('courts', size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          n.court,
                          style: const TextStyle(fontSize: 10, color: muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    final audit = Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('Activity'),
          if (activity.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Local approval and publishing actions will appear here.',
                style: TextStyle(color: muted),
              ),
            ),
          for (final a in activity)
            ListTile(
              leading: const Icon(Icons.history, size: 18, color: teal),
              title: Text(a, style: const TextStyle(fontSize: 12)),
              trailing: const Text(
                'Just now',
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ),
        ],
      ),
    );
    return Scaffold(
      appBar: wide ? null : AppBar(title: const Brand(small: true)),
      body: Row(
        children: [
          if (wide)
            Container(
              width: 235,
              color: Colors.white,
              child: Column(
                children: [
                  const Padding(padding: EdgeInsets.all(24), child: Brand()),
                  for (final s in [
                    'User verification',
                    'Court broadcasts',
                    'Activity',
                  ])
                    ListTile(
                      selected: section == s,
                      selectedTileColor: paleBlue,
                      leading: Icon(
                        s == 'User verification'
                            ? Icons.verified_user_outlined
                            : s == 'Activity'
                            ? Icons.history
                            : Icons.campaign_outlined,
                        size: 21,
                      ),
                      title: Text(s, style: const TextStyle(fontSize: 12)),
                      onTap: () => setState(() => section = s),
                    ),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Tag('ADMIN UI PREVIEW'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PageBody(
              children: [
                const PageTitle(
                  'Administration',
                  'Manage sample profiles and court announcements.',
                  action: Tag('Local demo'),
                ),
                if (!wide)
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in [
                        'User verification',
                        'Court broadcasts',
                        'Activity',
                      ])
                        ChoiceChip(
                          label: Text(s),
                          selected: section == s,
                          onSelected: (_) => setState(() => section = s),
                        ),
                    ],
                  ),
                const SizedBox(height: 16),
                if (section == 'Activity')
                  audit
                else if (section == 'Court broadcasts')
                  broadcast
                else if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 6, child: table),
                      const SizedBox(width: 20),
                      Expanded(flex: 4, child: broadcast),
                    ],
                  )
                else
                  table,
                const SizedBox(height: 22),
                const Text(
                  'Isolated admin preview. No real approvals or broadcasts occur; private chats and encryption keys are never exposed here.',
                  style: TextStyle(fontSize: 11, color: muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
