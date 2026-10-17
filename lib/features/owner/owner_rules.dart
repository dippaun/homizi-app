import 'package:homizi/features/owner/owner_models.dart';

/// Labels for the owner dashboard chips.
String ownerChipLabel(String chip) {
  return switch (chip) {
    'draft' => 'Draft',
    'in_review' => 'In review',
    'live' => 'Live',
    'paused' => 'Paused',
    'rented' => 'Rented',
    'expired' => 'Expired',
    _ => 'Draft',
  };
}

bool canPauseListing(String status) => status == 'published';

bool canResumeListing(String status) =>
    status == 'paused' || status == 'expired';

bool canMarkRented(String status) =>
    status == 'published' || status == 'paused';

bool canRenewListing(String status) =>
    status == 'published' || status == 'paused' || status == 'expired';

bool canDeleteDraft(String status) => status == 'draft';

bool canSubmitForReview(String status) => status == 'draft';

bool canEditListing(String status) => status != 'removed' && status != 'rented';

String ownerActionMessage(String action) {
  return switch (action) {
    'pause' => 'Listing paused.',
    'resume' => 'Listing is live again.',
    'mark_rented' => 'Marked as rented.',
    'renew' => 'The listing window is extended by 30 days.',
    'submit_review' => 'Submitted for review.',
    'delete_draft' => 'Draft deleted.',
    _ => 'Updated.',
  };
}

String ownerActionError(Object? code) {
  return switch (code) {
    'unauthenticated' => 'Sign in before managing a listing.',
    'not_owner' => 'You can only manage your own listing.',
    'incomplete' => 'Add a title, a city, a locality, and the rent first.',
    'photos' => 'The server needs at least 3 photos that are not rejected.',
    'photo_order' => 'Put a room photo first. Exterior shots follow the rooms.',
    'not_draft' => 'Only a draft can be deleted.',
    'invalid' => 'That action is not available for this listing.',
    'not_available' => 'The demo identity badge is not available here.',
    _ => 'The server did not update this listing.',
  };
}

/// "Usually replies within X h". Hours below 1 are shown as 1.
String replyWithinLabel(int hours) {
  final shown = hours < 1 ? 1 : hours;
  return 'Usually replies within $shown h';
}

List<DayCount> trailingDays(List<DayCount> days, int count) {
  if (count <= 0 || days.isEmpty) {
    return const [];
  }
  if (days.length <= count) {
    return days;
  }
  return days.sublist(days.length - count);
}
