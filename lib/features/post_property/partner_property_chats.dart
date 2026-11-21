import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/account/account_providers.dart';
import 'package:homizi/features/chat/open_profile_chat.dart';
import 'package:homizi/features/post_property/partner_enquiries.dart';
import 'package:homizi/features/shell/min_touch.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Selector {
  const _Selector({
    required this.id,
    required this.name,
    required this.line,
    required this.sample,
  });

  final String id;
  final String name;
  final String line;
  final bool sample;
}

/// People who liked or selected this partner's properties.
class PartnerPropertyChats extends ConsumerStatefulWidget {
  const PartnerPropertyChats({super.key});

  @override
  ConsumerState<PartnerPropertyChats> createState() =>
      _PartnerPropertyChatsState();
}

class _PartnerPropertyChatsState extends ConsumerState<PartnerPropertyChats> {
  var _loading = true;
  var _live = const <_Selector>[];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final config = ref.read(appConfigProvider);
    final demo = !config.connectsToSupabase || ref.read(forceDemoModeProvider);
    if (demo) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }
      final properties = await client
          .from('properties')
          .select('id')
          .eq('host_user_id', user.id);
      final ids = <String>{
        for (final row in _rows(properties))
          if (row['id'] is String) row['id'] as String,
      };
      if (ids.isEmpty) {
        if (mounted) {
          setState(() => _loading = false);
        }
        return;
      }
      final interests = await client
          .from('interests')
          .select('id, actor_user_id, target_id, action, created_at')
          .eq('action', 'like')
          .order('created_at', ascending: false)
          .limit(40);
      final liked = <Map<String, Object?>>[];
      for (final row in _rows(interests)) {
        final target = row['target_id'];
        final actor = row['actor_user_id'];
        if (target is String &&
            ids.contains(target) &&
            actor is String &&
            actor != user.id) {
          liked.add(row);
        }
      }
      final names = <String, String>{};
      final actors = {for (final row in liked) row['actor_user_id'] as String};
      if (actors.isNotEmpty) {
        final profiles = await client
            .from('profiles')
            .select('user_id, display_name')
            .inFilter('user_id', actors.toList());
        for (final row in _rows(profiles)) {
          final id = row['user_id'];
          final name = row['display_name'];
          if (id is String && name is String && name.trim().isNotEmpty) {
            names[id] = name.trim();
          }
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _live = [
          for (final row in liked)
            _Selector(
              id: '${row['id']}',
              name: names[row['actor_user_id'] as String] ?? 'Someone',
              line: 'Selected one of your properties',
              sample: false,
            ),
        ];
        _loading = false;
      });
    } on Object {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final people = [
      ..._live,
      if (_live.isEmpty)
        for (final enquiry in partnerEnquiries)
          _Selector(
            id: enquiry.name,
            name: enquiry.name,
            line: enquiry.line,
            sample: true,
          ),
    ];
    return MinTouchScope(
      child: Scaffold(
        key: const Key('partner-property-chats'),
        backgroundColor: HomiziColors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: const HomiziBackButton(),
          title: Text(homiziText(context, 'Chat')),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  Text(
                    homiziText(
                      context,
                      'People who selected or liked your properties.',
                    ),
                    style: const TextStyle(color: HomiziColors.inkSoft),
                  ),
                  const SizedBox(height: 12),
                  for (final person in people)
                    Card(
                      key: Key('partner-chat-${person.id}'),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () => unawaited(
                          openProfileChat(
                            context,
                            ref,
                            otherUserId: person.id,
                            name: person.name,
                            listingTitle: person.line,
                          ),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: HomiziColors.accentWash,
                          child: Text(
                            person.name.isEmpty
                                ? '?'
                                : person.name.substring(0, 1),
                          ),
                        ),
                        title: Text(person.name),
                        subtitle: Text(person.line),
                        trailing: person.sample
                            ? Text(
                                homiziText(context, 'Sample'),
                                style: const TextStyle(
                                  color: HomiziColors.inkSoft,
                                  fontSize: 12,
                                ),
                              )
                            : const Icon(
                                Icons.chat_bubble_outline,
                                color: HomiziColors.logoOrange,
                              ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

List<Map<String, Object?>> _rows(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is Map)
        item.map((key, value) => MapEntry(key.toString(), value)),
  ];
}
