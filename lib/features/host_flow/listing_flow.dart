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
    this.onLeaveIntro,
    super.key,
  });

  final String? propertyId;
  final bool fresh;
  final VoidCallback? onLeaveIntro;

  @override
  Widget build(BuildContext context) {
    return ListingEditorScreen(
      key: const Key('listing-flow'),
      propertyId: propertyId,
      fresh: fresh,
      spec: true,
      onLeaveIntro: onLeaveIntro,
    );
  }
}
