import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          Text(
            'Support for this foundation build is the project owner. In-app notifications are for matches, messages, and visits. They are not a support inbox.',
          ),
          SizedBox(height: 16),
          _Faq(
            question: 'When can someone see my phone number?',
            answer: 'Only after a mutual match, and only for the part you share. Share and stop sharing call grant_contact_consent and revoke_contact_consent. The app shows a phone or email only when get_contact_visibility returns one.',
          ),
          _Faq(
            question: 'Is identity verification real?',
            answer: 'No. The app exposes a mock interface. It does not collect Aadhaar, passport, or a face scan. A provider needs legal approval before any real check.',
          ),
          _Faq(
            question: 'Can I send my phone number in chat?',
            answer: 'No. Chat refuses a phone number or an email address, on the server and in demo mode. Share contact only with the match control, which still does not put those details in the thread. A visit request is a time, not a street address.',
          ),
          _Faq(
            question: 'What can a notification include?',
            answer: 'A match, a message, or a visit. The row stores ids only. It never includes a phone number, an email address, or a street address. Marking one read updates that timestamp and nothing else.',
          ),
          _Faq(
            question: 'Can I pay for a listing here?',
            answer: 'Payments are deferred. There is no checkout, and the client cannot mark a plan as paid.',
          ),
          _Faq(
            question: 'How do I report someone?',
            answer: 'Open a listing and use the flag icon. Blocking is recorded with the report. Moderator review is not staffed in this build.',
          ),
          SizedBox(height: 16),
          Text(
            'Safety: do not share an OTP, and do not move money before you have met or verified the home through a channel you trust.',
          ),
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(answer),
        ],
      ),
    );
  }
}
