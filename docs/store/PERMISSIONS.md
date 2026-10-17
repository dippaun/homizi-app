# Permissions

DRAFT — NOT FOR SUBMISSION. This list is the release manifest, not the debug manifest.

The app module declares one permission in `android/app/src/main/AndroidManifest.xml`:

- `android.permission.INTERNET` — required so a release build can reach Supabase over HTTPS. It is a normal permission. The app does not ask the user for it.

`aapt dump permissions` on the release APK built with Flutter 3.44.9 also lists:

- `in.homizi.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION` — a signature permission added by AndroidX so exported receivers stay app-private. It is not a user-facing permission and it is not requested at runtime.

The merged release manifest does not add camera, storage, media, location, contacts, SMS, notification, or advertising-id permissions. `image_picker` 0.8.13+25's own manifest does not declare `READ_EXTERNAL_STORAGE` or `CAMERA`. Listing photos use the gallery (`ImageSource.gallery`) and the system photo picker.

The app does not request:

- Camera.
- Precise or coarse location.
- Read contacts, read SMS, or phone state.
- Post notifications. Push delivery is not connected. The in-app inbox does not register a device token.
- Advertising id.

Debug and profile manifests also declare `INTERNET` so the Flutter tool can attach. Those source sets are not the Play artifact.
