/// VM and mobile builds have no hCaptcha document. The widget still reserves space.
void mountHcaptcha({
  required String elementId,
  required String siteKey,
  required double left,
  required double top,
  required void Function(String token) onToken,
  required bool scriptRequested,
}) {
  // Referenced so the stub matches the web signature without a browser.
  elementId;
  siteKey;
  left;
  top;
  onToken;
  scriptRequested;
}

void removeHcaptcha(String elementId) {
  elementId;
}
