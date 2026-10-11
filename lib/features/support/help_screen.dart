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
            'Support for this foundation build is the project owner. There is no live inbox yet.',
          ),
          SizedBox(height: 16),
          _Faq(
            question: 'When can someone see my phone number?',
            answer: 'Only after a mutual match, and only if you consent. The database function get_contact_visibility returns nothing otherwise. Hiding a button in the app is not the control.',
          ),
          _Faq(
            question: 'Is identity verification real?',
            answer: 'No. The app exposes a mock interface. It does not collect Aadhaar, passport, or a face scan. A provider needs legal approval before any real check.',
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
