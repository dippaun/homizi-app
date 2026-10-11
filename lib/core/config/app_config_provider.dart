import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/config/app_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromDefines());
