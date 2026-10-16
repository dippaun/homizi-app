/// Web and other targets without `dart:io`. String markers still classify
/// browser fetch failures in [offlineFailureMessage].
bool isDroppedConnection(Object error) => false;
