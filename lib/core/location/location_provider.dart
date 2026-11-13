import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config_provider.dart';
import 'package:homizi/core/location/location_service.dart';

/// The location service for this build. Override it in tests.
final locationServiceProvider = Provider<LocationService>((ref) {
  final config = ref.watch(appConfigProvider);
  return createLocationService(mapsApiKey: config.mapsApiKey);
});
