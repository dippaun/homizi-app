import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Flutter web hCaptcha mount. Imported only when `dart:html` exists.
void mountHcaptcha({
  required String elementId,
  required String siteKey,
  required double left,
  required double top,
  required void Function(String token) onToken,
  required bool scriptRequested,
}) {
  final document = globalContext.getProperty<JSObject?>('document'.toJS);
  if (document == null) {
    return;
  }
  if (!scriptRequested) {
    final script = document.callMethod<JSObject>(
      'createElement'.toJS,
      'script'.toJS,
    );
    script.setProperty(
      'src'.toJS,
      'https://js.hcaptcha.com/1/api.js?render=explicit'.toJS,
    );
    script.setProperty('async'.toJS, true.toJS);
    document
        .getProperty<JSObject>('head'.toJS)
        .callMethod('appendChild'.toJS, script);
  }
  final div = document.callMethod<JSObject>('createElement'.toJS, 'div'.toJS);
  div.setProperty('id'.toJS, elementId.toJS);
  final style = div.getProperty<JSObject>('style'.toJS);
  style.setProperty('position'.toJS, 'fixed'.toJS);
  style.setProperty('left'.toJS, '${left.round()}px'.toJS);
  style.setProperty('top'.toJS, '${top.round()}px'.toJS);
  style.setProperty('zIndex'.toJS, '30'.toJS);
  document
      .getProperty<JSObject>('body'.toJS)
      .callMethod('appendChild'.toJS, div);
  _renderWhenReady(elementId, siteKey, onToken, 0);
}

void _renderWhenReady(
  String elementId,
  String siteKey,
  void Function(String token) onToken,
  int attempt,
) {
  final hcaptcha = globalContext.getProperty<JSObject?>('hcaptcha'.toJS);
  if (hcaptcha == null) {
    if (attempt > 40) {
      return;
    }
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      _renderWhenReady(elementId, siteKey, onToken, attempt + 1);
    });
    return;
  }
  final options = JSObject();
  options.setProperty('sitekey'.toJS, siteKey.toJS);
  options.setProperty(
    'callback'.toJS,
    ((JSString token) {
      onToken(token.toDart);
    }).toJS,
  );
  hcaptcha.callMethod('render'.toJS, '#$elementId'.toJS, options);
}

void removeHcaptcha(String elementId) {
  final document = globalContext.getProperty<JSObject?>('document'.toJS);
  if (document == null) {
    return;
  }
  final node = document.callMethod<JSObject?>(
    'getElementById'.toJS,
    elementId.toJS,
  );
  node?.callMethod('remove'.toJS);
}
