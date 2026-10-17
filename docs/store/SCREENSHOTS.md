# Screenshots and feature graphic

DRAFT — NOT FOR SUBMISSION.

Phone screenshots are rendered from the HOMIZI widget tree at 1080×1920 (9:16), flattened onto white so the PNG has no alpha. The feature graphic is 1024×500, drawn from the app icon and Plus Jakarta Sans.

| File | Screen |
| --- | --- |
| `graphics/01-explore.png` | Explore feed |
| `graphics/02-listing.png` | Listing detail |
| `graphics/03-matches.png` | Matches |
| `graphics/04-chat.png` | Match chat |
| `graphics/05-settings.png` | Settings, including the analytics switch |
| `graphics/feature-graphic.png` | Play feature graphic, 1024×500 |

Regenerate the phone shots with Flutter:

```bash
HOMIZI_STORE_SHOTS=docs/store/graphics flutter test test/store/play_screenshot_test.dart
python3 tool/flatten_store_png.py docs/store/graphics
```

Regenerate the feature graphic:

```bash
python3 tool/store_feature_graphic.py
```

The capture test does not run in CI. `flutter test` without `HOMIZI_STORE_SHOTS` only checks that the capture stays opt-in.
