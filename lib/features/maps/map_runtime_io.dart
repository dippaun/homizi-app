import 'dart:io';

/// Widget tests must not open tile sockets or leave pending image timers.
bool get suppressMapTiles => Platform.environment['FLUTTER_TEST'] == 'true';
