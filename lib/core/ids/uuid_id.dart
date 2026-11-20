/// Postgres `uuid` columns reject demo ids such as `lst_ahd_vastrapur`.
final uuidIdPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

/// True when [value] can be sent to a Supabase `uuid` column or RPC argument.
bool isUuid(String value) => uuidIdPattern.hasMatch(value.trim());

/// Ids safe to pass to `.eq`, `.inFilter`, or an RPC `uuid` argument.
List<String> uuidIds(Iterable<String> ids) => [
  for (final id in ids)
    if (isUuid(id)) id,
];
