import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/media/avatar_ref.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/current_user_avatar.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/post_property/partner_shell.dart';
import 'package:homizi/features/post_property/pg_owner_mode.dart';
import 'package:homizi/features/roles/role_provider.dart';
import 'package:homizi/features/session/session_controller.dart';
import 'package:homizi/features/session/sign_in_source.dart';
import 'package:homizi/features/shell/glassy_nav_bar.dart';
import 'package:homizi/features/shell/role_nav.dart';

/// Circular saved photo for the Profile tab. Initials when no photo exists.
class ProfileNavAvatar extends ConsumerWidget {
  const ProfileNavAvatar({required this.selected, super.key});

  final bool selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final portrait = ref.watch(currentUserPhotoProvider).asData?.value;
    final photo = selected ? 18.0 : 24.0;
    return Container(
      key: const Key('profile-nav-avatar'),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: selected
            ? Border.all(color: HomiziColors.logoOrange, width: 2)
            : null,
      ),
      child: PersonPhoto(
        name: currentUserLabel(session.contact),
        bytes: portrait?.bytes,
        photoRef: displayAvatarRef(portrait?.url),
        diameter: photo,
      ),
    );
  }
}

class HomiziBottomNav extends ConsumerWidget {
  const HomiziBottomNav({required this.path, required this.router, super.key});

  final String path;
  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(signedInProvider);
    final partnerLive =
        ref.watch(partnerShellProvider) &&
        ref.watch(currentRoleProvider) == HomiziRole.broker;
    final pgOwner = pgOwnerActive(ref.watch(pgOwnerModeProvider));
    final destinations = pgOwner
        ? pgOwnerDestinations
        : partnerLive
        ? partnerLiveDestinations
        : isPartnerDesk(path)
        ? partnerDestinations
        : destinationsFor(ref.watch(currentRoleProvider), signedIn: signedIn);
    final selected = selectedNavIndex(destinations, path);
    // The bar paints its own surface into the bottom inset. An outer
    // SafeArea would leave a gap under that surface.
    return GlassyNavigationBar(
      destinations: [
        for (final destination in destinations)
          NavigationDestination(
            icon: destination.label == 'Profile' && signedIn
                ? const ProfileNavAvatar(selected: false)
                : Icon(destination.icon),
            selectedIcon: destination.label == 'Profile' && signedIn
                ? const ProfileNavAvatar(selected: true)
                : Icon(destination.selectedIcon),
            label: homiziText(context, destination.label),
          ),
      ],
      selectedIndex: selected,
      onDestinationSelected: (index) {
        final session = ref.read(sessionProvider);
        router.go(destinations[index].pathFor(session));
      },
    );
  }
}
