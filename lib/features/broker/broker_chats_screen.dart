import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/broker/broker_page.dart';

class _BrokerThread {
  const _BrokerThread({
    required this.id,
    required this.name,
    required this.preview,
    required this.place,
  });

  final String id;
  final String name;
  final String preview;
  final String place;
}

/// Indian desk threads. Opening one uses the shared chat screen, which
/// keeps a phone number or an email out of the message.
const _threads = <_BrokerThread>[
  _BrokerThread(
    id: 'broker-ananya',
    name: 'Ananya Iyer',
    place: 'Koramangala, Bengaluru',
    preview: 'Looking for a 2 BHK in Koramangala from November.',
  ),
  _BrokerThread(
    id: 'broker-rohan',
    name: 'Rohan Mehta',
    place: 'Andheri West, Mumbai',
    preview: 'Is the Andheri room still free for a working flatmate?',
  ),
  _BrokerThread(
    id: 'broker-meera',
    name: 'Meera Krishnan',
    place: 'Baner, Pune',
    preview: 'Can we see the Baner flat this Saturday morning?',
  ),
  _BrokerThread(
    id: 'broker-priya',
    name: 'Priya Nair',
    place: 'Kothrud, Pune',
    preview: 'Is the Kothrud 1 BHK free from the 8th?',
  ),
  _BrokerThread(
    id: 'broker-kabir',
    name: 'Kabir Singh',
    place: 'Dwarka, Delhi',
    preview: 'Looking for a shared room near the metro.',
  ),
  _BrokerThread(
    id: 'broker-dev',
    name: 'Dev Patel',
    place: 'Vastrapur, Ahmedabad',
    preview: 'A furnished 1 RK near college would work.',
  ),
  _BrokerThread(
    id: 'broker-fatima',
    name: 'Fatima Sheikh',
    place: 'Andheri East, Mumbai',
    preview: 'Can we visit the Andheri flat after 6?',
  ),
  _BrokerThread(
    id: 'broker-nikhil',
    name: 'Nikhil Rao',
    place: 'Whitefield, Bengaluru',
    preview: 'I work from home and need a quiet room.',
  ),
  _BrokerThread(
    id: 'broker-ishita',
    name: 'Ishita Banerjee',
    place: 'Karve Nagar, Pune',
    preview: 'Vegetarian household, shared room is fine.',
  ),
  _BrokerThread(
    id: 'broker-vikram',
    name: 'Vikram Joshi',
    place: 'Powai, Mumbai',
    preview: 'Family of four. Parking is important.',
  ),
  _BrokerThread(
    id: 'broker-harsh',
    name: 'Harsh Agarwal',
    place: 'Navrangpura, Ahmedabad',
    preview: 'College nearby. Weekends I cook.',
  ),
  _BrokerThread(
    id: 'broker-aditya',
    name: 'Aditya Kulkarni',
    place: 'Kharadi, Pune',
    preview: 'Internship starts in November.',
  ),
];

class BrokerChatsScreen extends StatelessWidget {
  const BrokerChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('broker-chats-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Chats')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'Messages with seekers. A phone number or an email is refused in chat.',
            ),
          ),
          const SizedBox(height: 16),
          for (final thread in _threads)
            BrokerTapCard(
              cardKey: Key('broker-chat-card-${thread.id}'),
              onTap: () => context.push(
                RoutePaths.chat(
                  thread.id,
                  name: thread.name,
                  title: thread.place,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    homiziText(context, thread.name),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(homiziText(context, thread.place)),
                  const SizedBox(height: 4),
                  Text(homiziText(context, thread.preview)),
                ],
              ),
            ),
          OutlinedButton(
            key: const Key('broker-chats-matches'),
            onPressed: () => context.go(RoutePaths.matches),
            child: Text(homiziText(context, 'Mutual matches')),
          ),
        ],
      ),
    );
  }
}
