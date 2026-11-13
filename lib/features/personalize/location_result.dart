/// One-shot location permission. Coordinates are not stored and are not
/// turned into a city: no maps provider is configured.
class LocationDetectResult {
  const LocationDetectResult({required this.shared, required this.message});

  final bool shared;
  final String message;
}
