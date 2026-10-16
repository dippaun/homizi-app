/// Records a product event. Implementations must drop the write when the
/// person has opted out, and must not attach a phone, email, or name.
abstract interface class AnalyticsGateway {
  Future<void> log(String name, {Map<String, String> properties = const {}});
}
