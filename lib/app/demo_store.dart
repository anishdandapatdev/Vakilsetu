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
    DemoRoom(
      'saket',
      'Saket Chamber',
      '12 members',
      'SC',
      group: true,
      messages: [DemoMessage('Rohit: Hearing moved to Court No. 12.')],
    ),
    DemoRoom(
      'research',
      'Research team',
      '6 members',
      'RT',
      group: true,
      messages: [DemoMessage('Ananya: New citations added to the draft.')],
    ),
    DemoRoom(
      'high-court-juniors',
      'High Court Juniors',
      '12 members',
      'HJ',
      group: true,
      messages: [DemoMessage('Rohan: Can someone share the latest circular?')],
    ),
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
  bool notifications = true, receipts = false, pending = false;
  int avatar = 0;
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

  DemoRoom createGroup(String name, Set<String> members) {
    final r = DemoRoom(
      'group-${rooms.length}',
      name,
      '${members.length + 1} members',
      'GP',
      group: true,
    );
    rooms.add(r);
    notifyListeners();
    return r;
  }

  void toggleCourt(String c) {
    joined.contains(c) ? joined.remove(c) : joined.add(c);
    notifyListeners();
  }

  void updateProfile(String n, String e, String c) {
    name = n;
    enrollment = e;
    court = c;
    pending = true;
    notifyListeners();
  }

  void refresh() => notifyListeners();
}
