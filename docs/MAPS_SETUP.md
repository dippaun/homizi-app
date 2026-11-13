# Google Maps

HOMIZI uses Google as the maps provider:

- **Maps JavaScript API** draws the office pin in the browser.
- **Places API (New)** supplies autocomplete and nearby search.
- **Routes API** `computeRoutes` returns distance and duration for Car (`DRIVE`), Two Wheeler (`TWO_WHEELER`), Public Transport (`TRANSIT`), and Walk (`WALK`).

The key is compiled in. It is not stored in the repository.

```bash
flutter run --dart-define=MAPS_API_KEY=YOUR_KEY --dart-define-from-file=config/staging.json
```

`config/staging.json` and the `config/env.*.json.example` files keep `MAPS_API_KEY` as `""`. Do not paste a key into those files or into a commit.

With an empty key the app does not call Google. The person types the address and nearby places, and commute shows **Distance unavailable**. The app does not fill in a distance or a travel time.

## Google Cloud

1. Create a key in Google Cloud for the HOMIZI web app.
2. Enable **Maps JavaScript API**, **Places API (New)**, and **Routes API**.
3. Restrict the key by HTTP referrer: `https://dippaun.github.io/*`.
4. Pass the key only with `--dart-define=MAPS_API_KEY=...` (or a local define file that is not committed).

The Maps JavaScript script is added in the browser only after that key is present. Places and Routes send the key in the `X-Goog-Api-Key` header, and only from `GoogleMapsProvider`, which refuses an empty key.

`LocationService` in `lib/core/location/` is the interface other screens use. `locationServiceProvider` reads `AppConfig.mapsApiKey`.
