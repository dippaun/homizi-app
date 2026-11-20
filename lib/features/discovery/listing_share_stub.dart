/// VM and mobile builds have no Web Share API.
Future<bool> shareWithDevice({
  required String title,
  required String text,
  required String url,
}) async {
  return false;
}
