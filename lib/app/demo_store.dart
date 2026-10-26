import 'package:flutter/foundation.dart';

const courts = [
  'Delhi High Court',
  'Saket District Court',
  'Tis Hazari Courts',
  'Patiala House Courts',
  'Karkardooma Courts',
  'Rohini District Court',
];

class DemoAdvocate {
  final String id, name, court, enrollment, practice;
  final String initials;
  DemoAdvocate(
    this.id,
    this.name,
    this.court,
    this.enrollment,
    this.practice,
    this.initials,
  );
}

class DemoMessage {
  final String? id;
  final String text;
  final String? senderName;
  final bool mine;
  final String? file;
  final String? attachmentId, attachmentContentType;
  final int? attachmentBytes;
  final DateTime? createdAt;
  final int recipientCount, deliveredCount, readCount;
  final String? replyToMessageId, replyBody, replySenderName;
  final bool replyDeleted;
  final DateTime? editedAt, deletedAt;
  DemoMessage(
    this.text, {
    this.senderName,
    this.id,
    this.mine = false,
    this.file,
    this.attachmentId,
    this.attachmentContentType,
    this.attachmentBytes,
    this.createdAt,
    this.recipientCount = 0,
    this.deliveredCount = 0,
    this.readCount = 0,
    this.replyToMessageId,
    this.replyBody,
    this.replySenderName,
    this.replyDeleted = false,
    this.editedAt,
    this.deletedAt,
  });
}

class DemoRoom {
  final String id, name, subtitle, initials;
  final bool group;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final List<DemoMessage> messages;
  final String? category;
  final String? description;
  final String? inviteCode;
  final int memberCount;
  final String? createdBy;
  final bool isPublic;
  int unread;
  DemoRoom(
    this.id,
    this.name,
    this.subtitle,
    this.initials, {
    this.group = false,
    this.unread = 0,
    this.lastMessagePreview,
    this.lastMessageAt,
    this.category,
    this.description,
    this.inviteCode,
    this.memberCount = 1,
    this.createdBy,
    this.isPublic = true,
    List<DemoMessage>? messages,
  }) : messages = messages ?? [];
}

class DemoNotice {
  final String court, title, body;
  DemoNotice(this.court, this.title, this.body);
}

/// UI-only in-memory state. No network, keys, real auth or durable chat history.
class DemoStore extends ChangeNotifier {
  final advocates = [
    DemoAdvocate(
      'meera',
      'Meera Sharma',
      courts[0],
      'D/1842/2016',
      'Civil litigation · Arbitration',
      'MS',
    ),
    DemoAdvocate(
      'kabir',
      'Kabir Malhotra',
      courts[1],
      'D/0921/2018',
      'Civil litigation · Family law',
      'KM',
    ),
    DemoAdvocate(
      'naina',
      'Naina Bansal',
      courts[2],
      'D/2247/2019',
      'Corporate law · Contracts',
      'NB',
    ),
    DemoAdvocate(
      'rohit',
      'Rohit Verma',
      courts[3],
      'D/1056/2015',
      'Criminal law · Appeals',
      'RV',
    ),
  ];

  late final List<DemoRoom> availableGroups = [
    DemoRoom(
      'saket',
      'Saket Chamber',
      '12 members',
      'SC',
      group: true,
      category: 'Chamber Group',
      inviteCode: 'VS-SAKET',
      memberCount: 12,
      description:
          'Civil and commercial litigation trial team for Saket District Court.',
      createdBy: 'Kabir Malhotra',
      messages: [DemoMessage('Rohit: Hearing moved to Court No. 12.')],
    ),
    DemoRoom(
      'research',
      'Research Team',
      '6 members',
      'RT',
      group: true,
      category: 'Study Circle',
      inviteCode: 'VS-RSRCH',
      memberCount: 6,
      description:
          'High Court case law citations, precedent analysis, and brief drafting.',
      createdBy: 'Meera Sharma',
      messages: [DemoMessage('Ananya: New citations added to the draft.')],
    ),
    DemoRoom(
      'high-court-juniors',
      'High Court Juniors',
      '12 members',
      'HJ',
      group: true,
      category: 'Practice Forum',
      inviteCode: 'VS-HCJUN',
      memberCount: 12,
      description:
          'Junior advocates forum for procedural guidance and roster updates.',
      createdBy: 'Rohit Verma',
      messages: [DemoMessage('Rohan: Can someone share the latest circular?')],
    ),
    DemoRoom(
      'delhi-bar',
      'Delhi High Court Bar Association',
      '240 members',
      'DH',
      group: true,
      category: 'Bar Association',
      inviteCode: 'VS-DHCBA',
      memberCount: 240,
      description:
          'Official community forum for registered advocates of Delhi High Court.',
      createdBy: 'Meera Sharma',
      messages: [
        DemoMessage(
          'Bar Notice: Digital filing seminar this Friday at 4 PM.',
        ),
      ],
    ),
    DemoRoom(
      'commercial-bench',
      'Commercial & Arbitration Bench',
      '45 members',
      'CB',
      group: true,
      category: 'Practice Forum',
      inviteCode: 'VS-ARB01',
      memberCount: 45,
      description:
          'Fast-track commercial arbitration and mediation practice group.',
      createdBy: 'Rohit Verma',
      messages: [
        DemoMessage('New draft guidelines on emergency arbitrator hearings.'),
      ],
    ),
    DemoRoom(
      'tax-society',
      'Tax & Corporate Legal Society',
      '68 members',
      'TS',
      group: true,
      category: 'Chamber Group',
      inviteCode: 'VS-TAX99',
      memberCount: 68,
      description:
          'GST disputes, direct tax assessment tribunals, and NCLT hearings.',
      createdBy: 'Naina Bansal',
      messages: [
        DemoMessage('Supreme Court ruling on input tax credit uploaded.'),
      ],
    ),
  ];

  late final Set<String> joinedGroupIds = {
    'saket',
    'research',
    'high-court-juniors',
  };

  late final List<DemoRoom> rooms = [
    DemoRoom(
      'meera',
      'Meera Sharma',
      courts[0],
      'MS',
      unread: 2,
      messages: [
        DemoMessage('Good morning, Arjun. Please review the revised petition.'),
        DemoMessage(
          'Of course. I will review it before the hearing.',
          mine: true,
        ),
        DemoMessage('Here is the latest draft.', file: 'Petition_draft.pdf'),
      ],
    ),
    DemoRoom(
      'kabir',
      'Kabir Malhotra',
      courts[1],
      'KM',
      unread: 1,
      messages: [
        DemoMessage('I have shared the court order.', file: 'Court_order.pdf'),
      ],
    ),
    DemoRoom(
      'rohit',
      'Rohit Verma',
      courts[3],
      'RV',
      messages: [
        DemoMessage("The matter is listed tomorrow. Let's coordinate."),
      ],
    ),
    availableGroups[0],
    availableGroups[1],
    availableGroups[2],
  ];
  final notices = [
    DemoNotice(
      courts[0],
      'Revised cause list',
      'The updated cause list is available for your reference. Please check your matter before attending court.',
    ),
    DemoNotice(
      courts[1],
      'Courtroom allocation updated',
      'Please review the revised courtroom allocation for the upcoming hearings.',
    ),
  ];
  final joined = {courts[0], courts[1]};
  String name = 'Arjun Khanna', enrollment = 'D/1234/2018', court = courts[1];
  String phone = '+91 98101 23456';
  int experienceYears = 7;
  String stateBar = 'Bar Council of Delhi';
  String chamberAddress = 'Chamber 402, Lawyers Block, Saket District Court';
  String practiceAreas = 'Civil litigation · Arbitration';
  String bio = 'Practicing advocate registered with Bar Council of Delhi.';
  bool notifications = true, receipts = false, pending = false;
  int avatar = 0;

  bool isGroupJoined(DemoRoom group) => joinedGroupIds.contains(group.id);

  DemoRoom? joinGroupByCode(String codeOrId) {
    final query = codeOrId.trim().toUpperCase();
    final matching = availableGroups.where(
      (g) =>
          (g.inviteCode?.toUpperCase() == query) ||
          g.id.toUpperCase() == query ||
          g.name.toUpperCase() == query,
    );
    if (matching.isEmpty) return null;
    final group = matching.first;
    joinGroup(group);
    return group;
  }

  void joinGroup(DemoRoom group) {
    joinedGroupIds.add(group.id);
    if (!rooms.any((r) => r.id == group.id)) {
      rooms.add(group);
    }
    notifyListeners();
  }

  void leaveGroup(String groupId) {
    joinedGroupIds.remove(groupId);
    rooms.removeWhere((r) => r.id == groupId);
    notifyListeners();
  }

  DemoRoom openAdvocate(DemoAdvocate a) {
    final existing = rooms.where((r) => r.id == a.id);
    if (existing.isNotEmpty) return existing.first;
    final room = DemoRoom(a.id, a.name, a.court, a.initials);
    rooms.add(room);
    notifyListeners();
    return room;
  }

  void read(DemoRoom r) {
    r.unread = 0;
    for (final room in rooms) {
      if (room.id == r.id) {
        room.unread = 0;
      }
    }
    notifyListeners();
  }

  void send(DemoRoom r, String text, {String? file}) {
    if (text.trim().isEmpty && file == null) return;
    r.messages.add(
      DemoMessage(
        text.trim(),
        mine: true,
        file: file,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  DemoRoom createGroup(
    String name,
    Set<String> members, {
    String? category,
    String? description,
    String? inviteCode,
    bool isPublic = true,
  }) {
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase())
        .take(2)
        .join();
    final effectiveInitials = initials.isEmpty ? 'GP' : initials;
    final effectiveCode = inviteCode ??
        'VS-${(DateTime.now().millisecondsSinceEpoch % 9000 + 1000)}';

    final r = DemoRoom(
      'group-${DateTime.now().millisecondsSinceEpoch}',
      name,
      '${members.length + 1} members',
      effectiveInitials,
      group: true,
      category: category ?? 'Chamber Group',
      description: description ?? 'Private chamber group',
      inviteCode: effectiveCode,
      memberCount: members.length + 1,
      createdBy: this.name,
      isPublic: isPublic,
    );
    joinedGroupIds.add(r.id);
    rooms.add(r);
    availableGroups.add(r);
    notifyListeners();
    return r;
  }

  void toggleCourt(String c) {
    joined.contains(c) ? joined.remove(c) : joined.add(c);
    notifyListeners();
  }

  void updateProfile(
    String n,
    String e,
    String c, {
    String? phone,
    int? experienceYears,
    String? stateBar,
    String? chamberAddress,
    String? practiceAreas,
    String? bio,
    int? avatar,
  }) {
    name = n;
    enrollment = e;
    court = c;
    if (phone != null) this.phone = phone;
    if (experienceYears != null) this.experienceYears = experienceYears;
    if (stateBar != null) this.stateBar = stateBar;
    if (chamberAddress != null) this.chamberAddress = chamberAddress;
    if (practiceAreas != null) this.practiceAreas = practiceAreas;
    if (bio != null) this.bio = bio;
    if (avatar != null) this.avatar = avatar;
    pending = true;
    notifyListeners();
  }

  void refresh() => notifyListeners();
}
