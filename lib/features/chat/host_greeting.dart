/// First note a host can edit before sending it to a seeker.
String hostGreeting({
  required String name,
  required String listingTitle,
  required String locality,
}) {
  final who = name.trim().isEmpty
      ? 'there'
      : name.trim().split(RegExp(r'\s+')).first;
  final home = listingTitle.trim().isEmpty ? 'place' : listingTitle.trim();
  final where = locality.trim().isEmpty ? 'the area' : locality.trim();
  return 'Hi $who, I think my $home in $where could suit you, have a look at my property';
}
