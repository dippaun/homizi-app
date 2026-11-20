import 'package:flutter/material.dart';

/// Keys and focus nodes for listing fields a continue tap can scroll to.
class WizardTargets {
  final _keys = <String, GlobalKey>{};
  final _focus = <String, FocusNode>{};

  GlobalKey key(String id) => _keys.putIfAbsent(id, GlobalKey.new);

  FocusNode focus(String id) => _focus.putIfAbsent(id, FocusNode.new);

  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
  }
}

/// Makes [WizardTargets] available to the listing steps.
class ListingWizardScope extends InheritedWidget {
  const ListingWizardScope({
    required this.targets,
    required super.child,
    super.key,
  });

  final WizardTargets targets;

  static WizardTargets? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ListingWizardScope>()
        ?.targets;
  }

  @override
  bool updateShouldNotify(ListingWizardScope oldWidget) {
    return oldWidget.targets != targets;
  }
}

/// Wraps [child] with the scroll key for [id] when a scope is present.
Widget wizardAnchor(BuildContext context, String id, Widget child) {
  final targets = ListingWizardScope.maybeOf(context);
  if (targets == null) {
    return child;
  }
  return KeyedSubtree(key: targets.key(id), child: child);
}

/// Focus node for [id], or null outside the listing wizard.
FocusNode? wizardFocus(BuildContext context, String id) {
  return ListingWizardScope.maybeOf(context)?.focus(id);
}
