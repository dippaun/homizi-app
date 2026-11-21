import 'package:flutter/material.dart';
import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/ui/kit/real_life_icons.dart';

/// Who published a home. Stored on `wizard:poster` and, after the listing
/// migration, also on `properties.listed_by` for broker / pg / room_sharer.
const posterOwner = 'owner';
const posterPg = 'pg';
const posterBroker = 'broker';
const posterRoomSharer = 'room_sharer';

const posterKindOrder = <String>[
  posterOwner,
  posterPg,
  posterBroker,
  posterRoomSharer,
];

bool isPosterKind(String value) => posterKindOrder.contains(value);

String posterKindLabel(String kind) => switch (kind) {
  posterPg => 'PG owner',
  posterBroker => 'Broker',
  posterRoomSharer => 'Room sharer',
  _ => 'Owner',
};

IconData posterKindIcon(String kind) => switch (kind) {
  posterPg => RealLifeIcons.pg,
  posterBroker => Icons.real_estate_agent_outlined,
  posterRoomSharer => RealLifeIcons.sharedRoom,
  _ => RealLifeIcons.house,
};

/// Wash behind the badge. Text stays ink so it stays readable.
Color posterKindWash(String kind) => switch (kind) {
  posterPg => const Color(0xFFFFE4C8),
  posterBroker => const Color(0xFFD9F2E3),
  posterRoomSharer => const Color(0xFFE4E0FF),
  _ => const Color(0xFFFFF1D6),
};

Color posterKindInk(String kind) => switch (kind) {
  posterPg => const Color(0xFF9A4B12),
  posterBroker => const Color(0xFF0E6B45),
  posterRoomSharer => const Color(0xFF3D2E8C),
  _ => const Color(0xFF8A4B08),
};

/// Value stored on `properties.listed_by`.
/// `pg` and `room_sharer` need the poster migration's check.
String listedByColumnFor(String posterKind) => switch (posterKind) {
  posterBroker => 'broker',
  posterPg => 'pg',
  posterRoomSharer => 'room_sharer',
  _ => 'host',
};

String posterKindFromSignals({
  String? stored,
  String? listedBy,
  String? propertyType,
  String? intent,
  String? hostKind,
}) {
  final saved = stored?.trim() ?? '';
  if (isPosterKind(saved)) {
    return saved;
  }
  final listed = listedBy?.trim() ?? '';
  if (listed == 'broker' || listed == posterBroker) {
    return posterBroker;
  }
  if (listed == posterPg || listed == 'pg_owner') {
    return posterPg;
  }
  if (listed == posterRoomSharer || listed == 'sharer') {
    return posterRoomSharer;
  }
  final type = propertyType?.trim() ?? '';
  final why = intent?.trim() ?? '';
  if (type == 'pg' || why == 'pg') {
    return posterPg;
  }
  if (why == 'shared_space') {
    return posterRoomSharer;
  }
  return posterKindFromHostLabel(hostKind);
}

/// Demo cards and older rows store a display label, not the wire value.
String posterKindFromHostLabel(String? hostKind) {
  final kind = (hostKind ?? '').trim().toLowerCase();
  if (kind.contains('broker') || kind.contains('partner')) {
    return posterBroker;
  }
  if (kind.contains('pg')) {
    return posterPg;
  }
  if (kind.contains('flatmate') ||
      kind.contains('sharer') ||
      kind.contains('roomie') ||
      kind.contains('roommate')) {
    return posterRoomSharer;
  }
  return posterOwner;
}

String listingPosterKind(Listing listing) {
  return posterKindFromSignals(
    propertyType: listing.propertyType,
    hostKind: listing.hostKind,
  );
}

String posterKindFromProfileRole(String? role) {
  return switch ((role ?? '').trim()) {
    'broker' => posterBroker,
    'roommate' => posterRoomSharer,
    'tenant' => posterRoomSharer,
    _ => posterOwner,
  };
}

/// Empty or a full set means every poster stays visible.
bool posterKindAllowed(String kind, List<String> selected) {
  if (selected.isEmpty || selected.length >= posterKindOrder.length) {
    return true;
  }
  return selected.contains(kind);
}
