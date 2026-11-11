import 'package:flutter/material.dart';
import 'package:homizi/features/host/host_onboarding_screen.dart';
import 'package:homizi/features/host_flow/listing_flow.dart';

/// Become a Host, then List Your Property. Route: `/flow/host`.
class HostFlowScreen extends StatefulWidget {
  const HostFlowScreen({super.key});

  @override
  State<HostFlowScreen> createState() => _HostFlowScreenState();
}

class _HostFlowScreenState extends State<HostFlowScreen> {
  var _listing = false;
  var _hostDone = false;
  var _listingFresh = true;

  @override
  Widget build(BuildContext context) {
    if (_listing) {
      return ListingFlow(
        fresh: _listingFresh,
        onLeaveIntro: () => setState(() {
          _listing = false;
          _hostDone = true;
          _listingFresh = false;
        }),
      );
    }
    return HostOnboardingScreen(
      key: const Key('host-flow-screen'),
      spec: true,
      startConfirmed: _hostDone,
      onFinished: () => setState(() => _listing = true),
    );
  }
}
