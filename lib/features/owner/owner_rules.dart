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
    'not_available' => 'Verification cannot be changed here.',
    'not_found' => 'That lead is not on your listing.',
    _ => 'The server did not update this listing.',
  };
}

/// "Usually replies within X h". Hours below 1 are shown as 1.
String replyWithinLabel(int hours) {
  final shown = hours < 1 ? 1 : hours;
  return 'Usually replies within $shown h';
}

bool isOwnerLeadStatus(String status) =>
    status == 'new' || status == 'replied' || status == 'closed';

/// Printed status. The word is the status, not a colour.
String ownerLeadStatusLabel(String status) {
  return switch (status) {
    'new' => 'New',
    'replied' => 'Replied',
    'closed' => 'Closed',
    _ => 'New',
  };
}

String ownerLeadKindLabel(String kind) {
  return switch (kind) {
    'interest' => 'Interest',
    'visit' => 'Visit request',
    _ => 'Lead',
  };
}

String ownerLeadAuditLabel(OwnerLeadAudit event) {
  return 'You set this to ${ownerLeadStatusLabel(event.toStatus)}';
}

/// Minutes from the lead to the first replied status.
String ownerLeadResponseLabel(OwnerLead lead) {
  final minutes =
      lead.responseMinutes ??
      _minutesBetween(lead.createdAt, lead.firstRepliedAt);
  if (minutes == null) {
    return 'Not replied yet';
  }
  if (minutes < 1) {
    return 'Replied in under 1 minute';
  }
  if (minutes < 60) {
    return 'Replied in $minutes min';
  }
  return 'Replied in ${minutes ~/ 60} h';
}

int? _minutesBetween(DateTime start, DateTime? end) {
  if (end == null) {
    return null;
  }
  final minutes = end.difference(start).inMinutes;
  if (minutes < 0) {
    return 0;
  }
  return minutes;
}

/// Copy the lead inbox is allowed to show. Contact fields are not included.
String ownerLeadVisibleCopy(OwnerLead lead) {
  return [
    lead.nameLabel,
    ownerLeadKindLabel(lead.kind),
    ownerLeadStatusLabel(lead.status),
    ownerLeadResponseLabel(lead),
    for (final event in lead.audit) ownerLeadAuditLabel(event),
  ].join('\n');
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
