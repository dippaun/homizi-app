import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/demo/demo_success.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:homizi/features/support/domain/faq_catalog.dart';
import 'package:homizi/features/support/support_gateway.dart';
import 'package:homizi/features/support/support_providers.dart';
import 'package:homizi/ui/kit/kit.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Builder(
        builder: (context) {
          final tabs = DefaultTabController.of(context);
          return MinTouchScope(
            child: Scaffold(
              backgroundColor: HomiziColors.white,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                leading: const HomiziBackButton(),
                title: Text(homiziText(context, 'Help')),
                bottom: TabBar(
                  tabs: [
                    Tab(text: homiziText(context, 'Guides')),
                    Tab(text: homiziText(context, 'Safety')),
                    Tab(text: homiziText(context, 'Contact')),
                  ],
                ),
              ),
              body: ContentBody(
                pageId: 'help',
                child: ListenableBuilder(
                  listenable: tabs,
                  builder: (context, _) {
                    return switch (tabs.index) {
                      0 => const _Guides(),
                      1 => const _Safety(),
                      _ => const _Contact(),
                    };
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Guides extends StatefulWidget {
  const _Guides();

  @override
  State<_Guides> createState() => _GuidesState();
}

class _GuidesState extends State<_Guides> {
  final _query = TextEditingController();
  var _category = 'all';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = searchFaqs(query: _query.text, category: _category);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          homiziText(
            context,
            'Support for this foundation build is the project owner. In-app notifications are for matches, messages, visits, and deposit reminders. They are not a support inbox.',
          ),
        ),
        const SizedBox(height: 16),
        KitTextField(
          fieldKey: const Key('faq-search'),
          label: 'Search help',
          controller: _query,
          hint: 'Visits, deposits, verification',
          icon: Icons.search,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in faqCategories)
              FilterChip(
                key: Key('faq-$category'),
                label: Text(homiziText(context, faqCategoryLabel(category))),
                selected: _category == category,
                showCheckmark: true,
                onSelected: (_) => setState(() => _category = category),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (entries.isEmpty)
          Text(
            homiziText(context, 'No matching questions.'),
            key: const Key('faq-empty'),
          )
        else
          for (final entry in entries)
            _Faq(question: entry.question, answer: entry.answer),
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
          homiziText(context, 'Safety tips'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final tip in safetyTips)
          Card.outlined(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(homiziText(context, tip)),
            ),
          ),
        const _Faq(
          question: 'Can I send my phone number in chat?',
          answer:
              'No. Chat refuses a phone number or an email address, on the server and in demo mode. Share contact only with the match control, which still does not put those details in the thread. A visit request is a time, not a street address.',
        ),
      ],
    );
  }
}

class _Contact extends ConsumerStatefulWidget {
  const _Contact();

  @override
  ConsumerState<_Contact> createState() => _ContactState();
}

class _ContactState extends ConsumerState<_Contact> {
  final _message = TextEditingController();
  var _topic = 'renting';
  var _busy = false;
  String? _note;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = supportMessageError(_message.text);
    if (error != null) {
      if (demoModeOn(ref)) {
        openDemoSuccess(
          context,
          title: 'Message sent',
          detail: 'Support can read this note in the demo.',
        );
        return;
      }
      setState(() => _note = error);
      return;
    }
    setState(() {
      _busy = true;
      _note = null;
    });
    try {
      await ref
          .read(supportGatewayProvider)
          .submit(topic: _topic, message: _message.text);
      if (!mounted) {
        return;
      }
      _message.clear();
      if (demoModeOn(ref)) {
        setState(() => _busy = false);
        openDemoSuccess(
          context,
          title: 'Message sent',
          detail: 'Support can read this note in the demo.',
        );
        return;
      }
      setState(() {
        _note =
            'Ticket saved. A person on the HOMIZI project can read it. No phone number or email is stored in the ticket.';
      });
    } on SupportFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _note = error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          homiziText(context, 'Contact support'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          homiziText(
            context,
            'This note stays on your account. Do not include a phone number or an email address.',
          ),
        ),
        const SizedBox(height: 16),
        KitChoiceField<String>(
          key: const Key('support-topic'),
          label: 'Topic',
          icon: RealLifeIcons.chat,
          selected: _topic,
          options: [
            for (final topic in supportTopics)
              KitOption(
                value: topic,
                label: faqCategoryLabel(topic),
                icon: RealLifeIcons.chat,
              ),
          ],
          onChanged: (value) {
            if (!_busy) {
              setState(() => _topic = value);
            }
          },
        ),
        KitTextField(
          fieldKey: const Key('support-message'),
          label: 'Message',
          controller: _message,
          hint: 'What should we look at?',
          icon: RealLifeIcons.mail,
          minLines: 4,
          maxLines: 8,
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('submit-support'),
          onPressed: _busy ? null : () => unawaited(_submit()),
          child: Text(homiziText(context, _busy ? 'Saving…' : 'Send')),
        ),
        if (_note != null) ...[
          const SizedBox(height: 12),
          Text(homiziText(context, _note!), key: const Key('support-note')),
        ],
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
