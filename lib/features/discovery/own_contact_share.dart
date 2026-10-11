import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/discovery/domain/discovery_parse.dart';
import 'package:homizi/features/discovery/domain/discovery_state.dart';

class OwnContactShare extends ConsumerStatefulWidget {
  const OwnContactShare({
    required this.match,
    required this.onDeviceOnly,
    super.key,
  });

  final MatchSummary match;
  final bool onDeviceOnly;

  @override
  ConsumerState<OwnContactShare> createState() => _OwnContactShareState();
}

class _OwnContactShareState extends ConsumerState<OwnContactShare> {
  late String _scope;
  String? _note;

  @override
  void initState() {
    super.initState();
    _scope = widget.match.ownShare ?? 'phone';
  }

  @override
  void didUpdateWidget(OwnContactShare oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.match.ownShare;
    if (next != null && next != oldWidget.match.ownShare) {
      _scope = next;
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(discoveryProvider).busy;
    final matchId = widget.match.matchId;
    final sharing = widget.match.ownShare != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Share your own contact. This does not reveal theirs.',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text(
          ownShareStatus(
            widget.match.ownShare,
            onDeviceOnly: widget.onDeviceOnly,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final scope in contactShareScopes)
              ChoiceChip(
                key: Key('share-scope-$matchId-$scope'),
                label: Text(_chipLabel(scope)),
                selected: _scope == scope,
                onSelected: busy
                    ? null
                    : (selected) {
                        if (selected) {
                          setState(() => _scope = scope);
                        }
                      },
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton(
              key: Key('share-own-contact-$matchId'),
              onPressed: busy ? null : () => unawaited(_share()),
              child: Text(sharing ? 'Update what I share' : 'Share my contact'),
            ),
            OutlinedButton(
              key: Key('stop-own-contact-$matchId'),
              onPressed: busy || !sharing ? null : () => unawaited(_stop()),
              child: const Text('Stop sharing'),
            ),
          ],
        ),
        if (_note != null) ...[
          const SizedBox(height: 8),
          Text(_note!, key: Key('own-share-note-$matchId')),
        ],
      ],
    );
  }

  Future<void> _share() async {
    final notice = await ref
        .read(discoveryProvider.notifier)
        .shareOwnContact(widget.match.matchId, _scope);
    if (!mounted) {
      return;
    }
    setState(() => _note = notice.message);
  }

  Future<void> _stop() async {
    final notice = await ref
        .read(discoveryProvider.notifier)
        .stopSharingOwnContact(widget.match.matchId);
    if (!mounted) {
      return;
    }
    setState(() => _note = notice.message);
  }
}

String _chipLabel(String scope) {
  return switch (scope) {
    'email' => 'Email',
    'phone_and_email' => 'Both',
    _ => 'Phone',
  };
}
