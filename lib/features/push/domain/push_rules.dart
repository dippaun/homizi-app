/// In-app notification type to the preference category used by push.
/// Unknown types are not pushed. A saved-search notice stays in the inbox
/// and is never sent to FCM.
String? pushCategoryForType(String type) {
  return switch (type) {
    'match' => 'matches',
    'message' => 'chat',
    'visit_requested' ||
    'visit_accepted' ||
    'visit_declined' ||
    'visit_cancelled' => 'visits',
    'saved_search_match' => null,
    _ => null,
  };
}

/// Copy sent to the device. Ids only; no name, phone, or address.
String pushTitleForType(String type) {
  return switch (pushCategoryForType(type)) {
    'matches' => 'New match on HOMIZI',
    'chat' => 'New message on HOMIZI',
    'visits' => 'Visit update on HOMIZI',
    _ => 'HOMIZI',
  };
}

String pushBodyForType(String type) {
  return switch (pushCategoryForType(type)) {
    'matches' => 'Open HOMIZI to see the match.',
    'chat' => 'Open the chat in HOMIZI.',
    'visits' => 'Open HOMIZI to see the visit.',
    _ => 'Open HOMIZI.',
  };
}

bool pushConfigured({
  required String apiKey,
  required String appId,
  required String senderId,
  required String projectId,
}) {
  return apiKey.trim().isNotEmpty &&
      appId.trim().isNotEmpty &&
      senderId.trim().isNotEmpty &&
      projectId.trim().isNotEmpty;
}
