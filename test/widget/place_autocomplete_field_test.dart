import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/location/location_service.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/theme/homizi_theme.dart';

class _Places implements LocationService {
  var fail = true;
  String? lastToken;
  String? resolvedToken;

  @override
  bool get mapsEnabled => true;

  @override
  GeoFix? get lastKnownPoint => null;

  @override
  Future<LocationAccess> requestAccess() async => LocationAccess.granted;

  @override
  Future<GeoFix?> currentPosition() async => null;

  @override
  Future<PlaceSuggestion?> reverseGeocode(GeoFix point) async => null;

  @override
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    GeoFix? near,
    String? sessionToken,
  }) async {
    lastToken = sessionToken;
    if (fail) {
      throw const PlaceSearchException('offline');
    }
    return const [
      PlaceSuggestion(
        label: 'Vastrapur, Ahmedabad, Gujarat, India',
        placeId: 'ChIJv',
      ),
    ];
  }

  @override
  Future<PlaceSuggestion> resolvePlace(
    PlaceSuggestion suggestion, {
    String? sessionToken,
  }) async {
    resolvedToken = sessionToken;
    return suggestion.copyWith(latitude: 23.03, longitude: 72.53);
  }

  @override
  Future<NearbyResult> nearbyPlaces(
    GeoFix? origin, {
    double radiusMeters = 1500,
  }) async => NearbyResult.manual;

  @override
  Future<CommuteEstimate> commute({
    required PlaceEndpoint origin,
    required PlaceEndpoint destination,
    required TransportMode mode,
  }) async => CommuteEstimate.unavailable(mode);
}

void main() {
  testWidgets('a failed lookup shows retry, then suggestions resolve', (
    tester,
  ) async {
    final places = _Places();
    final controller = TextEditingController();
    PlaceSuggestion? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [locationServiceProvider.overrideWithValue(places)],
        child: MaterialApp(
          theme: HomiziTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => PlaceAutocompleteField(
                fieldKey: const Key('field'),
                controller: controller,
                manualOption: true,
                selected: picked,
                onSelected: (place) => setState(() => picked = place),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('field')), 'Vastr');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text("Couldn't load suggestions"), findsOneWidget);
    expect(find.byKey(const Key('office-use-typed')), findsNothing);

    places.fail = false;
    await tester.tap(find.byKey(const Key('place-suggestions-retry')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Vastrapur, Ahmedabad, Gujarat, India'), findsOneWidget);
    final token = places.lastToken;
    expect(token, isNotNull);

    await tester.tap(find.byKey(const Key('place-suggestion-0')));
    await tester.pump();
    await tester.pump();
    expect(places.resolvedToken, token);
    expect(picked?.latitude, 23.03);
    expect(controller.text, 'Vastrapur, Ahmedabad, Gujarat, India');
    // The chosen place matches the text, so no "No place match" row.
    expect(find.byKey(const Key('office-use-typed')), findsNothing);
  });
}
