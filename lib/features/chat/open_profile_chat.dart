import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/ids/uuid_id.dart';
import 'package:homizi/core/routing/account_prompt.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/features/chat/direct_chat_screen.dart';
import 'package:homizi/features/chat/opened_direct_chats.dart';
import 'package:homizi/features/profile_create/verification_gate.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/sign_in_source.dart';

/// Location of the profile-to-profile thread.
///
/// Demo ids stay in the query string. The screen refuses to send them to
/// Supabase, so a non-uuid never becomes a Postgres `22P02`.
String directChatLocation({
  required String otherUserId,
  String? name,
  String? avatar,
  String? listingId,
  String? listingTitle,
  String? place,
  String? profilePath,
  bool suggestGreeting = false,
}) {
  return Uri(
    path: RoutePaths.directChat,
    queryParameters: {
      'user': otherUserId,
      if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      if (avatar != null && avatar.trim().isNotEmpty) 'avatar': avatar.trim(),
      if (listingId != null && listingId.trim().isNotEmpty)
        'listing': listingId.trim(),
      if (listingTitle != null && listingTitle.trim().isNotEmpty)
        'title': listingTitle.trim(),
      if (place != null && place.trim().isNotEmpty) 'place': place.trim(),
      if (suggestGreeting) 'greet': '1',
      if (profilePath != null && profilePath.trim().isNotEmpty)
        'profile': profilePath.trim(),
    },
  ).toString();
}

/// Opens the thread with [otherUserId].
///
/// A guest is asked to sign in and returns to this thread. A signed-in person
/// with a verified phone or email opens the thread immediately. The strict
/// identity flag still shows the verification sheet. A uuid poster calls
/// get_or_create_direct_conversation. Demo ids stay on this device. Either
/// way the Chats tab keeps a row for this person.
Future<void> openProfileChat(
  BuildContext context,
  WidgetRef ref, {
  required String otherUserId,
  required String name,
  String? avatarUrl,
  String? listingId,
  String? listingTitle,
  String? place,
  String? profilePath,
  bool suggestGreeting = false,
}) async {
  final id = otherUserId.trim();
  if (id.isEmpty) {
    return;
  }
  final location = directChatLocation(
    otherUserId: id,
    name: name,
    avatar: avatarUrl,
    listingId: listingId,
    listingTitle: listingTitle,
    place: place,
    suggestGreeting: suggestGreeting,
    profilePath: profilePath,
  );
  if (!ref.read(signedInProvider)) {
    await openAccountPath(context, ref.read(sessionProvider), location);
    return;
  }
  if (!contactActionsOpen(ref)) {
    await guardVerifiedAction(
      context,
      ref,
      action: () async {
        if (!context.mounted) {
          return;
        }
        _rememberDirectChat(
          ref,
          otherUserId: id,
          name: name,
          avatarUrl: avatarUrl,
          listingId: listingId,
          listingTitle: listingTitle,
        );
        await _pushThread(
          context,
          location: location,
          otherUserId: id,
          name: name,
          avatarUrl: avatarUrl,
          listingId: listingId,
          listingTitle: listingTitle,
          place: place,
          suggestGreeting: suggestGreeting,
          profilePath: profilePath,
        );
      },
    );
    return;
  }
  if (!context.mounted) {
    return;
  }
  _rememberDirectChat(
    ref,
    otherUserId: id,
    name: name,
    avatarUrl: avatarUrl,
    listingId: listingId,
    listingTitle: listingTitle,
  );
  await _pushThread(
    context,
    location: location,
    otherUserId: id,
    name: name,
    avatarUrl: avatarUrl,
    listingId: listingId,
    listingTitle: listingTitle,
    place: place,
    suggestGreeting: suggestGreeting,
    profilePath: profilePath,
  );
}

void _rememberDirectChat(
  WidgetRef ref, {
  required String otherUserId,
  required String name,
  String? avatarUrl,
  String? listingId,
  String? listingTitle,
}) {
  ref
      .read(openedDirectChatsProvider.notifier)
      .remember(
        otherUserId: otherUserId,
        name: name,
        avatarUrl: avatarUrl,
        listingId: listingId,
        listingTitle: listingTitle,
      );
}

Future<void> _pushThread(
  BuildContext context, {
  required String location,
  required String otherUserId,
  required String name,
  String? avatarUrl,
  String? listingId,
  String? listingTitle,
  String? place,
  String? profilePath,
  bool suggestGreeting = false,
}) async {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    await router.push(location);
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => DirectChatScreen(
        otherUserId: otherUserId,
        otherName: name,
        avatarUrl: avatarUrl,
        listingId: listingId,
        listingTitle: listingTitle,
        place: place,
        suggestGreeting: suggestGreeting,
        profilePath: profilePath,
      ),
    ),
  );
}

/// Opens the other person's profile from a thread header.
void openChatProfile(
  BuildContext context, {
  String? profilePath,
  String? otherUserId,
  String? listingId,
}) {
  final router = GoRouter.maybeOf(context);
  if (router == null) {
    return;
  }
  final profile = profilePath?.trim() ?? '';
  if (profile.startsWith('/')) {
    router.push(profile);
    return;
  }
  final listing = listingId?.trim() ?? '';
  if (listing.isNotEmpty) {
    router.push(RoutePaths.listing(listing));
    return;
  }
  final user = otherUserId?.trim() ?? '';
  if (user.isNotEmpty && !isUuid(user)) {
    router.push(RoutePaths.roommatePerson(user));
  }
}
