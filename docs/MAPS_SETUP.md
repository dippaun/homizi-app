# Google Maps

HOMIZI uses Google as the maps provider:

- **Maps JavaScript API** draws the office pin and the listing locality circle in the browser. The listing circle is the approximate area, not the building.
- **Places API (New)** supplies autocomplete, place details, and nearby search (including Text Search for airports).
- **Geocoding** on the web uses the Maps JavaScript `Geocoder`. The legacy `maps.googleapis.com/maps/api/geocode/json` web service returns `REQUEST_DENIED` for this referrer-restricted key.
- **Travel time** on the web uses the Maps JavaScript `DistanceMatrixService` (walking, driving, transit). Two-wheeler uses driving, because that service has no two-wheeler mode. The legacy Distance Matrix web service is not called.
- **Routes API** remains available for non-browser tests. The live site does not call it.

With an empty key the listing shows one fallback map and estimated nearby rows the owner can edit. It does not draw a second map.

The key is compiled in. It is not stored in the repository.

```bash
flutter run --dart-define=MAPS_API_KEY=YOUR_KEY --dart-define-from-file=config/staging.json
```

`config/staging.json` and the `config/env.*.json.example` files keep `MAPS_API_KEY` as `""`. Do not paste a key into those files or into a commit.

With an empty key the app does not call Google. The person types the address. Office commute shows **Distance unavailable**. A listing still shows estimated nearby rows, and the owner can edit every name, distance, and time.

## Google Cloud

1. Create a key in Google Cloud for the HOMIZI web app.
2. Enable **Maps JavaScript API**, **Places API (New)**, **Geocoding API**, **Routes API**, and **Distance Matrix API**. Places API (legacy) can stay enabled; the app does not call its web-service REST methods.
3. Restrict the key by HTTP referrer: `https://dippaun.github.io/*`. Places API (New) REST accepts that restriction from the browser. Legacy Geocoding and Places web-service REST do not, so those calls stay inside the Maps JavaScript API.
4. Pass the key only with `--dart-define=MAPS_API_KEY=...` (or a local define file that is not committed).

The Maps JavaScript script is added in the browser only after that key is present. Places and Routes send the key in the `X-Goog-Api-Key` header, and only from `GoogleMapsProvider`, which refuses an empty key.

`LocationService` in `lib/core/location/` is the interface other screens use. `locationServiceProvider` reads `AppConfig.mapsApiKey`.
