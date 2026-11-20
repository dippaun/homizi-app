import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/features/office/office_location.dart';
import 'package:homizi/features/office/office_repository.dart';

/// Writes the workplace captured in registration or search so commute
/// screens can reuse it. A later "Change office" is the only re-prompt.
Future<void> rememberWorkplace(
  WidgetRef ref,
  PlaceSuggestion place,
) async {
  final label = place.label.trim();
  if (label.length < 2) {
    return;
  }
  final repo = ref.read(officeRepositoryProvider);
  try {
    await repo.load();
  } on Object {
    // A missing store still keeps the copy we are about to write.
  }
  final current = repo.primary;
  final sameLabel =
      current != null && current.label.trim().toLowerCase() == label.toLowerCase();
  final samePoint =
      place.latitude == null ||
      (current?.latitude == place.latitude &&
          current?.longitude == place.longitude);
  if (sameLabel && samePoint) {
    ref.read(officeRevisionProvider.notifier).bump();
    return;
  }
  await repo.save(
    OfficeLocation(
      id: current?.id ?? 'primary-office',
      label: label,
      placeId: place.placeId ?? current?.placeId,
      latitude: place.latitude ?? current?.latitude,
      longitude: place.longitude ?? current?.longitude,
      transport: current?.transport ?? TransportMode.car,
      maxCommuteMinutes: current?.maxCommuteMinutes ?? 45,
      primary: true,
    ),
  );
  ref.read(officeRevisionProvider.notifier).bump();
}
