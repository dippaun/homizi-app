import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/location/location_service.dart';

/// The app-wide location service. Google is on only when `MAPS_API_KEY`
/// was compiled in. Agent D should read this provider.
final locationServiceProvider = Provider<LocationService>((ref) {
  final config = ref.watch(appConfigProvider);
  return buildLocationService(mapsApiKey: config.mapsApiKey);
});
