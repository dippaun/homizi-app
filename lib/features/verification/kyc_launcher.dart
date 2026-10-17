import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Adds the return address Digio should use after the check.
/// The address is not shown in the app.
Uri? kycGatewayUri(String gatewayUrl, {required String returnUrl}) {
  final parsed = Uri.tryParse(gatewayUrl);
  if (parsed == null || parsed.scheme != 'https' || returnUrl.isEmpty) {
    return null;
  }
  final encoded = Uri.encodeComponent(returnUrl);
  if (gatewayUrl.contains('#')) {
    final join = gatewayUrl.contains('?') ? '&' : '?';
    return Uri.tryParse('$gatewayUrl${join}redirect_url=$encoded');
  }
  return parsed.replace(
    queryParameters: {...parsed.queryParameters, 'redirect_url': returnUrl},
  );
}

String kycReturnUrl() {
  if (kIsWeb) {
    final origin = Uri.base.origin;
    if (origin.startsWith('https://') ||
        origin.startsWith('http://localhost')) {
      return '$origin/verify';
    }
  }
  return 'in.homizi.app://verify';
}

abstract interface class KycLauncher {
  Future<bool> open(Uri uri);
}

class UrlKycLauncher implements KycLauncher {
  const UrlKycLauncher();

  @override
  Future<bool> open(Uri uri) {
    if (uri.scheme != 'https') {
      return Future<bool>.value(false);
    }
    return launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    );
  }
}

final kycLauncherProvider = Provider<KycLauncher>(
  (ref) => const UrlKycLauncher(),
);
