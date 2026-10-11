import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/features/chat/domain/chat_rules.dart';
import 'package:homizi/features/chat/domain/thread_state.dart';
import 'package:homizi/features/chat/thread_gateway.dart';
import 'package:homizi/features/chat/thread_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    required this.matchId,
    this.otherName = 'Match',
    this.listingTitle,
    super.key,
  });

  final String matchId;
  final String otherName;
  final String? listingTitle;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _body = TextEditingController();
  var _loading = true;
  var _busy = false;
  String? _note;
  ThreadSnapshot _thread = ThreadSnapshot.empty;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final thread = await ref.read(threadGatewayProvider).load(widget.matchId);
      if (!mounted) {
        return;
      }
      setState(() {
        _thread = thread;
        _loading = false;
        _note = thread.note;
      });
    } on ThreadFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _note = error.message;
      });
    }
  }

  Future<void> _send() async {
    final text = _body.text;
    if (containsContactText(text)) {
      setState(() => _note = ThreadCopy.contactRejected);
      return;
    }
    await _run(
      () => ref.read(threadGatewayProvider).send(widget.matchId, text),
      clearComposer: true,
    );
  }

  Future<void> _requestVisit() async {
    await _run(
      () => ref
          .read(threadGatewayProvider)
          .requestVisit(widget.matchId, defaultVisitSlots(DateTime.now())),
    );
  }

  Future<void> _respond(String visitId, String status) async {
    await _run(
      () => ref.read(threadGatewayProvider).respondVisit(visitId, status),
    );
  }

  Future<void> _run(
    Future<ThreadSnapshot> Function() action, {
    bool clearComposer = false,
  }) async {
    setState(() => _busy = true);
    try {
      final thread = await action();
      if (!mounted) {
        return;
      }
      setState(() {
        _thread = thread;
        _note = thread.note;
        _busy = false;
      });
      if (clearComposer) {
        _body.clear();
      }
    } on ThreadFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _note = error.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final connected = ref.watch(appConfigProvider).connectsToSupabase;
    final name = containsContactText(widget.otherName)
        ? 'Match'
        : widget.otherName;
    final title = widget.listingTitle;
    final safeTitle = title != null && !containsContactText(title)
        ? title
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: _loading
          ? const Center(child: Text('Opening the conversation…'))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    connected
                        ? 'Messages stay on the match. Phone numbers and email addresses are refused. A visit time is not a street address.'
                        : 'Demo mode keeps this chat on the device. Nothing is sent, and contact details are still refused.',
                  ),
                ),
                if (_note != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Text(_note!, key: const Key('chat-note')),
                  ),
                Expanded(
                  child: ListView(
                    key: const Key('chat-log'),
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (safeTitle != null) Text(safeTitle),
                      const SizedBox(height: 12),
                      _VisitPanel(
                        visits: _thread.visits,
                        busy: _busy,
                        onRequest: _requestVisit,
                        onRespond: _respond,
                      ),
                      const SizedBox(height: 16),
                      if (_thread.messages.isEmpty)
                        const Text(
                          'No messages yet. Say hello without a phone number or an email address.',
                        )
                      else
                        for (final message in _thread.messages)
                          Align(
                            alignment: message.mine
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  message.body,
                                  key: Key('chat-message-${message.id}'),
                                ),
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('chat-body'),
                          controller: _body,
                          decoration: const InputDecoration(
                            hintText: 'Write a message',
                          ),
                          minLines: 1,
                          maxLines: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        key: const Key('chat-send'),
                        onPressed: _busy ? null : () => unawaited(_send()),
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _VisitPanel extends StatelessWidget {
  const _VisitPanel({
    required this.visits,
    required this.busy,
    required this.onRequest,
    required this.onRespond,
  });

  final List<VisitRequest> visits;
  final bool busy;
  final Future<void> Function() onRequest;
  final Future<void> Function(String visitId, String status) onRespond;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Visits', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Propose a time. The street address is not part of this request.',
        ),
        const SizedBox(height: 8),
        if (visits.isEmpty)
          const Text('No visit requested yet.')
        else
          for (final visit in visits) ...[
            Text(
              _statusLabel(visit.status),
              key: Key('visit-status-${visit.id}'),
            ),
            for (final slot in visit.slots) Text(formatVisitSlot(slot)),
            if (visit.isOpen && visit.mine)
              TextButton(
                key: Key('cancel-visit-${visit.id}'),
                onPressed: busy
                    ? null
                    : () => unawaited(onRespond(visit.id, 'cancelled')),
                child: const Text('Cancel request'),
              ),
            if (visit.isOpen && !visit.mine)
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    key: Key('accept-visit-${visit.id}'),
                    onPressed: busy
                        ? null
                        : () => unawaited(onRespond(visit.id, 'accepted')),
                    child: const Text('Accept'),
                  ),
                  OutlinedButton(
                    key: Key('decline-visit-${visit.id}'),
                    onPressed: busy
                        ? null
                        : () => unawaited(onRespond(visit.id, 'declined')),
                    child: const Text('Decline'),
                  ),
                ],
              ),
            const SizedBox(height: 8),
          ],
        OutlinedButton(
          key: const Key('request-visit'),
          onPressed: busy ? null : () => unawaited(onRequest()),
          child: const Text('Request a visit'),
        ),
      ],
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'accepted' => 'Accepted',
    'declined' => 'Declined',
    'cancelled' => 'Cancelled',
    'rescheduled' => 'Rescheduled',
    'completed' => 'Completed',
    _ => 'Requested',
  };
}
