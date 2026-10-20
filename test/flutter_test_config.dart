import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> testExecutable(Future<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final base = ThemeData.light().textTheme;
  GoogleFonts.plusJakartaSansTextTheme(base);
  for (final style
      in base.bodyLarge == null
          ? const <TextStyle>[]
          : <TextStyle?>[
              base.bodyLarge,
              base.bodyMedium,
              base.bodySmall,
              base.labelLarge,
              base.labelMedium,
              base.labelSmall,
            ]) {
    GoogleFonts.inter(textStyle: style);
  }
  await GoogleFonts.pendingFonts();
  await testMain();
}
