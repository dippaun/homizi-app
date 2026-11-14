import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// The Digio link to open. start-kyc already adds the allowlisted return
/// address; an older server reply without one gets [returnUrl] added here.
Uri? kycGatewayUri(String gatewayUrl, {required String returnUrl}) {
  final parsed = Uri.tryParse(gatewayUrl);
  if (parsed == null || parsed.scheme != 'https') {
    return null;
  }
  if (gatewayUrl.contains('redirect_url=') || returnUrl.isEmpty) {
    return parsed;
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

/// Where Digio sends people back to: the verify route under the app's base
/// href, with hash routing. For the live app that is
/// https://dippaun.github.io/homizi-app/#/verify.
String kycReturnUrlFor(Uri base, {required bool web}) {
  if (web &&
      (base.scheme == 'https' ||
          (base.scheme == 'http' &&
              (base.host == 'localhost' || base.host == '127.0.0.1')))) {
    var path = base.path;
    if (!path.endsWith('/')) {
      path = path.substring(0, path.lastIndexOf('/') + 1);
    }
    if (path.isEmpty) {
      path = '/';
    }
    return '${base.origin}$path#/verify';
  }
  return 'in.homizi.app://verify';
}

String kycReturnUrl() => kycReturnUrlFor(Uri.base, web: kIsWeb);

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
