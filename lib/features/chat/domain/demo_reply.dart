/// A short on-device reply used when no Supabase session is sending the message.
/// The text stays inside property talk so the contact check does not flag it.
String demoReplyFor(String body) {
  final lower = body.toLowerCase();
  if (lower.contains('visit') ||
      lower.contains('saturday') ||
      lower.contains('sunday') ||
      lower.contains('morning')) {
    return 'Saturday morning works. I can meet you at the building gate.';
  }
  if (lower.contains('rent') ||
      lower.contains('₹') ||
      lower.contains('bhk') ||
      lower.contains('deposit')) {
    return 'Rent is ₹18,000 for this 2BHK, plus maintenance. Move-in can be 1 Dec.';
  }
  if (lower.contains('available') ||
      lower.contains('room') ||
      lower.contains('flat') ||
      lower.contains('floor')) {
    return 'The room is free from 1 Dec. It is a furnished 2BHK on the 4th floor.';
  }
  if (lower.contains('11') || lower.contains('time')) {
    return '11 works. I will be in the lobby, not on a phone call.';
  }
  return 'Thanks, that helps. Want to fix a visit this week?';
}
