import 'package:homizi/ui/kit/page_background.dart';

/// Picks a stable wash so neighbouring forms do not all look the same.
PageBackgroundVariant pageVariantFor(String id) {
  var hash = 17;
  for (final unit in id.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash.isEven
      ? PageBackgroundVariant.skyline
      : PageBackgroundVariant.soft;
}
