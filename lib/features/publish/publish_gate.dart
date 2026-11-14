import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/account_prompt.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/inventory/inventory_gateway.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/listings/listing_posted_screen.dart';
import 'package:homizi/features/listings/published_search.dart';
import 'package:homizi/features/profile_create/own_verification.dart';
import 'package:homizi/features/publish/brief_live_screen.dart';
import 'package:homizi/features/publish/published_activity.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/session/sign_in_source.dart';

/// Signed-out publishing opens sign-in and does not write.
/// Returns true when [signedInProvider] allows the publish to continue.
Future<bool> requireSignedInToPublish(
  BuildContext context,
  WidgetRef ref,
) async {
  if (ref.read(signedInProvider)) {
    return true;
  }
  if (!context.mounted) {
    return false;
  }
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    final here = router.routeInformationProvider.value.uri.toString();
    await router.push(signInReturn(here));
    return false;
  }
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        key: const Key('sign-in-prompt'),
        backgroundColor: HomiziColors.white,
        title: Text(homiziText(dialogContext, 'Sign in to continue')),
        content: Text(
          homiziText(
            dialogContext,
            'This stays on your account. After sign-in you come back to this step.',
          ),
          style: const TextStyle(color: HomiziColors.ink),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(homiziText(dialogContext, 'Not now')),
          ),
          FilledButton(
            key: const Key('sign-in-prompt-continue'),
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(homiziText(dialogContext, 'Sign in')),
          ),
        ],
      );
    },
  );
  return false;
}

void rememberPublishedBrief(
  WidgetRef ref,
  RequirementDraft draft, {
  required bool onServer,
}) {
  final verified = ref.read(ownVerificationProvider).isVerified;
  final place = [
    draft.city.trim(),
    ...draft.localityList,
  ].where((part) => part.isNotEmpty).join(' · ');
  ref
      .read(publishedActivityProvider.notifier)
      .remember(
        PublishedActivityItem(
          id: draft.id ?? place,
          kind: PublishedKind.brief,
          title: draft.seekerKind == 'roommate'
              ? 'Roommate brief'
              : 'Seeker brief',
          place: place,
          unverified: !verified,
          onServer: onServer,
        ),
      );
}

Future<void> showBriefLive(
  BuildContext context,
  WidgetRef ref,
  RequirementDraft draft, {
  required bool onServer,
}) async {
  rememberPublishedBrief(ref, draft, onServer: onServer);
  if (!context.mounted) {
    return;
  }
  final verified = ref.read(ownVerificationProvider).isVerified;
  final place = [
    draft.city.trim(),
    ...draft.localityList,
  ].where((part) => part.isNotEmpty).join(' · ');
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) =>
          BriefLiveScreen(place: place, onServer: onServer, verified: verified),
    ),
  );
}

/// Records a complete home in search and My activity.
void rememberPublishedHome(
  WidgetRef ref,
  ListingDraft draft, {
  required bool onServer,
}) {
  if (releaseGaps(draft).isNotEmpty) {
    return;
  }
  final verified = ref.read(ownVerificationProvider).isVerified;
  ref
      .read(publishedSearchProvider.notifier)
      .remember(draft, hostVerified: verified);
  final place = [
    draft.locality.trim(),
    draft.city.trim(),
  ].where((part) => part.isNotEmpty).join(', ');
  ref
      .read(publishedActivityProvider.notifier)
      .remember(
        PublishedActivityItem(
          id: draft.id ?? draft.title,
          kind: PublishedKind.home,
          title: draft.title.trim().isEmpty
              ? 'Untitled home'
              : draft.title.trim(),
          place: place,
          unverified: !verified,
          onServer: onServer,
        ),
      );
}

/// Records a home as published and opens the confirmation when it is complete.
/// Returns true when the confirmation was shown.
Future<bool> finishListingPublish(
  BuildContext context,
  WidgetRef ref, {
  required ListingWriteResult result,
}) async {
  final draft = result.draft;
  final ready = releaseGaps(draft).isEmpty;
  final verified = ref.read(ownVerificationProvider).isVerified;
  rememberPublishedHome(ref, draft, onServer: result.publishedByServer);
  final live = result.publishedByServer || ready;
  if (!live || !context.mounted) {
    return false;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => ListingPostedScreen(
        draft: draft,
        serverPublished: result.publishedByServer,
        publisherVerified: verified,
      ),
    ),
  );
  return true;
}
