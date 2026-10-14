import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final tabs = DefaultTabController.of(context);
          return Scaffold(
            backgroundColor: HomiziColors.white,
            appBar: AppBar(
              title: Text(homiziText(context, 'Help')),
              bottom: TabBar(
                tabs: [
                  Tab(text: homiziText(context, 'Guides')),
                  Tab(text: homiziText(context, 'Safety')),
                ],
              ),
            ),
            body: ListenableBuilder(
              listenable: tabs,
              builder: (context, _) {
                return tabs.index == 0 ? const _Guides() : const _Safety();
              },
            ),
          );
        },
      ),
    );
  }
}

class _Guides extends StatelessWidget {
  const _Guides();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          homiziText(
            context,
            'Support for this foundation build is the project owner. In-app notifications are for matches, messages, and visits. They are not a support inbox.',
          ),
        ),
        const SizedBox(height: 16),
        const _Faq(
          question: 'When can someone see my phone number?',
          answer: 'Only after a mutual match, and only for the part you share. Share and stop sharing call grant_contact_consent and revoke_contact_consent. The app shows a phone or email only when get_contact_visibility returns one.',
        ),
        const _Faq(
          question: 'Is identity verification real?',
          answer: 'No. The app exposes a mock interface. It does not collect Aadhaar, passport, or a face scan. A provider needs legal approval before any real check.',
        ),
        const _Faq(
          question: 'Can I send my phone number in chat?',
          answer: 'No. Chat refuses a phone number or an email address, on the server and in demo mode. Share contact only with the match control, which still does not put those details in the thread. A visit request is a time, not a street address.',
        ),
        const _Faq(
          question: 'What can a notification include?',
          answer: 'A match, a message, or a visit. The row stores ids only. It never includes a phone number, an email address, or a street address. Marking one read updates that timestamp and nothing else.',
        ),
        const _Faq(
          question: 'Can I pay for a listing here?',
          answer: 'Payments are deferred. There is no checkout, and the client cannot mark a plan as paid.',
        ),
        const _Faq(
          question: 'How do I report someone?',
          answer: 'Open a listing or a chat and use the flag icon. The report is stored for your account. Blocking is recorded with it and stops messages and contact in both directions. A moderator queue is not connected.',
        ),
        const _Faq(
          question: 'How do I delete my account?',
          answer: 'Settings has Delete account. On this device it clears the local profile. With the local server connected it removes the auth user, profile, listings, photos, messages, and the private contact row. It does not call a payment provider, an identity provider, or a production backup.',
        ),
      ],
    );
  }
}

class _Safety extends StatelessWidget {
  const _Safety();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          homiziText(
            context,
            'Safety: do not share an OTP, and do not move money before you have met or verified the home through a channel you trust.',
          ),
        ),
        const SizedBox(height: 16),
        const _Faq(
          question: 'Can I send my phone number in chat?',
          answer: 'No. Chat refuses a phone number or an email address, on the server and in demo mode. Share contact only with the match control, which still does not put those details in the thread. A visit request is a time, not a street address.',
        ),
      ],
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              homiziText(context, question),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(homiziText(context, answer)),
          ],
        ),
      ),
    );
  }
}
