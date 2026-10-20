import 'package:flutter/widgets.dart';

/// Phrases demo mode must not show. Login screens stay unchanged when demo
/// mode is off.
bool isDemoSignInCopy(String message) {
  final lower = message.toLowerCase();
  return lower.contains('sign in') || lower.contains('sign-in');
}

/// Hides sign-in prompts while the staging demo is on.
class DemoCopyGuard extends InheritedWidget {
  const DemoCopyGuard({
    required this.hideSignIn,
    required super.child,
    super.key,
  });

  final bool hideSignIn;

  static bool hides(BuildContext context) {
    final guard = context.dependOnInheritedWidgetOfExactType<DemoCopyGuard>();
    return guard?.hideSignIn ?? false;
  }

  @override
  bool updateShouldNotify(DemoCopyGuard oldWidget) {
    return hideSignIn != oldWidget.hideSignIn;
  }
}
