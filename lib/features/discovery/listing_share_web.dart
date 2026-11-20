import 'dart:js_interop';

import 'package:web/web.dart';

/// `navigator.share` on the web. Returns false when the browser has no API
/// or the person dismisses the sheet.
Future<bool> shareWithDevice({
  required String title,
  required String text,
  required String url,
}) async {
  try {
    final nav = window.navigator;
    if (!nav.canShare()) {
      return false;
    }
    await nav.share(ShareData(title: title, text: text, url: url)).toDart;
    return true;
  } on Object {
    return false;
  }
}
