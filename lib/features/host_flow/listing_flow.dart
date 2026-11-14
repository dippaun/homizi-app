import 'package:flutter/material.dart';
import 'package:homizi/features/listings/listing_editor_screen.dart';

/// Reusable listing wizard for the host flow and for Agent D (broker).
///
/// Open it from [RoutePaths.flowListing], or place this widget in another
/// flow. It keeps the existing listing draft and saves through the inventory
/// gateway. Pass [fresh] false to resume the draft already in memory.
class ListingFlow extends StatelessWidget {
  const ListingFlow({
    this.propertyId,
    this.fresh = true,
    this.brokerMode = false,
    this.showMarketing = true,
    this.postFlow = false,
    this.onLeaveIntro,
    super.key,
  });

  final String? propertyId;
  final bool fresh;

  /// Page 7, then the intro. Editing an existing listing skips both.
  final bool showMarketing;

  /// Post Property owner path: three stages, same fields and publish path.
  final bool postFlow;

  /// Broker listing. Forwarded to the shared editor so brokerage, owner
  /// authorisation, and the Listed by Broker badge stay available.
  final bool brokerMode;
  final VoidCallback? onLeaveIntro;

  @override
  Widget build(BuildContext context) {
    return ListingEditorScreen(
      key: const Key('listing-flow'),
      propertyId: propertyId,
      fresh: fresh,
      brokerMode: brokerMode,
      spec: true,
      showMarketing: postFlow ? false : showMarketing,
      postFlow: postFlow,
      onLeaveIntro: onLeaveIntro,
    );
  }
}
