import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:homizi/core/config/app_config.dart';
import 'package:homizi/features/push/push_gateway.dart';

class FirebasePushGateway implements PushGateway {
  FirebasePushGateway(this._config, this._tokens);

  final AppConfig _config;
  final DeviceTokenStore _tokens;
  var _started = false;

  @override
  bool get configured => _config.firebaseConfigured;

  @override
  Future<void> start() async {
    if (!configured || _started) {
      return;
    }
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: _config.firebaseApiKey,
          appId: _config.firebaseAppId,
          messagingSenderId: _config.firebaseMessagingSenderId,
          projectId: _config.firebaseProjectId,
        ),
      );
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      // FCM HTTP v1 still sends to the registration token.
      // ignore: deprecated_member_use
      final token = await messaging.getToken(
        vapidKey: _config.firebaseVapidKey.isEmpty
            ? null
            : _config.firebaseVapidKey,
        serviceWorkerScriptPath: kIsWeb ? 'firebase-messaging-sw.js' : null,
      );
      if (token != null && token.isNotEmpty) {
        await _tokens.save(token, pushPlatform());
      }
      _started = true;
    } catch (_) {
      // A missing plugin or a rejected permission must not block the app.
      _started = false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (!configured) {
      return;
    }
    if (enabled) {
      await start();
      return;
    }
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      // ignore: deprecated_member_use
      await FirebaseMessaging.instance.deleteToken();
      if (token != null && token.isNotEmpty) {
        await _tokens.remove(token);
      }
    } catch (_) {
      // Turning alerts off must still succeed if Firebase is unavailable.
    }
  }
}

String pushPlatform() {
  if (kIsWeb) {
    return 'web';
  }
  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    _ => 'android',
  };
}
