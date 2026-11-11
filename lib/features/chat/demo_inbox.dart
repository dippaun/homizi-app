import 'package:homizi/features/chat/domain/thread_state.dart';

/// Sample threads for the public demo. No phone, email, or street address.
class DemoInboxSeed {
  const DemoInboxSeed({
    required this.matchId,
    required this.name,
    required this.listingTitle,
    required this.avatarUrl,
    required this.otherUserId,
    required this.messages,
  });

  final String matchId;
  final String name;
  final String listingTitle;
  final String avatarUrl;
  final String otherUserId;
  final List<ChatMessage> messages;
}

/// Built from [now] so Today and Yesterday stay correct whenever the app opens.
List<DemoInboxSeed> demoInboxSeeds(DateTime now) {
  final todayMorning = DateTime(now.year, now.month, now.day, 9, 40);
  final todayEarly = DateTime(now.year, now.month, now.day, 8, 5);
  final yesterday = todayMorning.subtract(const Duration(days: 1, hours: 1));
  final twoDays = todayMorning.subtract(const Duration(days: 2, hours: 3));

  ChatMessage line({
    required String id,
    required String body,
    required DateTime at,
    required bool mine,
    String sender = 'demo-host',
  }) {
    return ChatMessage(
      id: id,
      senderId: mine ? 'demo-self' : sender,
      body: body,
      createdAt: at.toUtc(),
      mine: mine,
    );
  }

  return [
    DemoInboxSeed(
      matchId: 'demo-chat-ananya',
      name: 'Ananya Iyer',
      listingTitle: 'Sunlit 2BHK in Koramangala',
      avatarUrl: 'assets/avatars/avatar_01.webp',
      otherUserId: 'demo-host-ananya',
      messages: [
        line(
          id: 'ananya-1',
          body: 'The 2BHK is free from 1 Dec. Rent is ₹18,000.',
          at: twoDays,
          mine: false,
          sender: 'demo-host-ananya',
        ),
        line(
          id: 'ananya-2',
          body: 'Is the 4th floor room still open?',
          at: twoDays.add(const Duration(minutes: 12)),
          mine: true,
        ),
        line(
          id: 'ananya-3',
          body: 'Yes. Saturday morning works for a visit.',
          at: yesterday,
          mine: false,
          sender: 'demo-host-ananya',
        ),
        line(
          id: 'ananya-4',
          body: 'Pin code 560034 is the area, not a door number.',
          at: todayEarly,
          mine: false,
          sender: 'demo-host-ananya',
        ),
      ],
    ),
    DemoInboxSeed(
      matchId: 'demo-chat-rohan',
      name: 'Rohan Mehta',
      listingTitle: 'Room in a 3BHK, Indiranagar',
      avatarUrl: 'assets/avatars/avatar_02.webp',
      otherUserId: 'demo-host-rohan',
      messages: [
        line(
          id: 'rohan-1',
          body: 'The room faces east and has a balcony.',
          at: yesterday.subtract(const Duration(hours: 2)),
          mine: false,
          sender: 'demo-host-rohan',
        ),
        line(
          id: 'rohan-2',
          body: 'I can visit on Sunday after 4.',
          at: todayEarly.add(const Duration(minutes: 20)),
          mine: true,
        ),
      ],
    ),
    DemoInboxSeed(
      matchId: 'demo-chat-meera',
      name: 'Meera Krishnan',
      listingTitle: 'Furnished 1BHK in HSR Layout',
      avatarUrl: 'assets/avatars/avatar_03.webp',
      otherUserId: 'demo-host-meera',
      messages: [
        line(
          id: 'meera-1',
          body: 'Maintenance is separate from the rent.',
          at: yesterday,
          mine: true,
        ),
        line(
          id: 'meera-2',
          body: 'Noted. The 1BHK is on floor 2 of 4.',
          at: todayMorning.subtract(const Duration(minutes: 25)),
          mine: false,
          sender: 'demo-host-meera',
        ),
      ],
    ),
    DemoInboxSeed(
      matchId: 'demo-chat-kabir',
      name: 'Kabir Shah',
      listingTitle: 'Shared room near FC Road, Pune',
      avatarUrl: 'assets/avatars/avatar_04.webp',
      otherUserId: 'demo-host-kabir',
      messages: [
        line(
          id: 'kabir-1',
          body: 'Two people already live there. No smoking.',
          at: twoDays.add(const Duration(hours: 5)),
          mine: false,
          sender: 'demo-host-kabir',
        ),
        line(
          id: 'kabir-2',
          body: 'That works. I will look at the photos again.',
          at: yesterday.add(const Duration(hours: 3)),
          mine: true,
        ),
      ],
    ),
    DemoInboxSeed(
      matchId: 'demo-chat-priya',
      name: 'Priya Nair',
      listingTitle: '2BHK in Andheri West',
      avatarUrl: 'assets/avatars/avatar_05.webp',
      otherUserId: 'demo-host-priya',
      messages: [
        line(
          id: 'priya-1',
          body: 'Is a visit possible this week?',
          at: yesterday.subtract(const Duration(hours: 4)),
          mine: true,
        ),
        line(
          id: 'priya-2',
          body: 'Thursday evening is free.',
          at: yesterday.add(const Duration(hours: 1)),
          mine: false,
          sender: 'demo-host-priya',
        ),
        line(
          id: 'priya-3',
          body: 'The flat is a 2BHK, available 15 Nov.',
          at: todayEarly.add(const Duration(hours: 1)),
          mine: false,
          sender: 'demo-host-priya',
        ),
        line(
          id: 'priya-4',
          body: 'Deposit is two months. Rent is ₹32,000.',
          at: todayMorning,
          mine: false,
          sender: 'demo-host-priya',
        ),
      ],
    ),
    DemoInboxSeed(
      matchId: 'demo-chat-arjun',
      name: 'Arjun Patel',
      listingTitle: 'Studio near SG Highway, Ahmedabad',
      avatarUrl: 'assets/avatars/avatar_06.webp',
      otherUserId: 'demo-host-arjun',
      messages: [
        line(
          id: 'arjun-1',
          body: 'The studio is furnished and on floor 7.',
          at: twoDays.add(const Duration(hours: 1)),
          mine: false,
          sender: 'demo-host-arjun',
        ),
        line(
          id: 'arjun-2',
          body: 'Thanks. I will decide after the weekend.',
          at: yesterday.add(const Duration(minutes: 40)),
          mine: true,
        ),
      ],
    ),
  ];
}
