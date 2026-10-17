# Push

Device push is implemented and inert until Firebase is configured. Follow [PUSH_SETUP.md](PUSH_SETUP.md).

These files stay out of git:

- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`
- a Firebase service-account JSON
- an APNs key

With no Firebase dart-defines, the Settings switch does not register a token. The in-app inbox still works. The `send-push` function returns without calling FCM when `FCM_SERVICE_ACCOUNT` is unset.
