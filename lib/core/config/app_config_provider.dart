import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromDefines());

/// Opt-in for the Content / Loading / Empty / Error chips.
///
/// Normal debug, profile, and release runs leave this off. A debug build
/// shows the chips only with `--dart-define=SHOW_STATE_PREVIEW=true`.
/// Profile and release ignore the define because [kDebugMode] is false.
const statePreviewRequested = bool.fromEnvironment('SHOW_STATE_PREVIEW');

final showStatePreviewProvider = Provider<bool>(
  (ref) => kDebugMode && statePreviewRequested,
);
