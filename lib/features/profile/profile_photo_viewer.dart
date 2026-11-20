import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';

/// Hero tag for the signed-in profile photo on the profile tab.
const ownProfilePhotoHero = 'own-profile-photo';

/// Hero tag for the same photo on Edit profile.
const editProfilePhotoHero = 'edit-profile-photo';

/// Circular portrait. Bytes win, then a stored photo reference, then initials.
class ProfilePortrait extends StatelessWidget {
  const ProfilePortrait({
    required this.name,
    this.bytes,
    this.photoRef,
    super.key,
  });

  final String name;
  final Uint8List? bytes;
  final String? photoRef;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: HomiziColors.accentWash, child: _image(context));
  }

  Widget _image(BuildContext context) {
    return PersonPhoto(name: name, bytes: bytes, photoRef: photoRef);
  }
}

/// Full-screen profile photo. [onChangePhoto] is only for the signed-in person.
void openProfilePhotoViewer({
  required BuildContext context,
  required String heroTag,
  required String name,
  Uint8List? bytes,
  String? photoRef,
  VoidCallback? onChangePhoto,
}) {
  Navigator.of(context).push<void>(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: HomiziColors.night,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return ProfilePhotoViewer(
          heroTag: heroTag,
          name: name,
          bytes: bytes,
          photoRef: photoRef,
          onChangePhoto: onChangePhoto,
        );
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class ProfilePhotoViewer extends StatelessWidget {
  const ProfilePhotoViewer({
    required this.heroTag,
    required this.name,
    this.bytes,
    this.photoRef,
    this.onChangePhoto,
    super.key,
  });

  final String heroTag;
  final String name;
  final Uint8List? bytes;
  final String? photoRef;

  /// Present on the signed-in profile. Other people do not get this action.
  final VoidCallback? onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final change = onChangePhoto;
    final width = MediaQuery.sizeOf(context).width;
    final diameter = (width - 48).clamp(220.0, 420.0);
    return Scaffold(
      key: const Key('profile-photo-viewer'),
      backgroundColor: HomiziColors.clear,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                key: const Key('profile-photo-close'),
                tooltip: homiziText(context, 'Close'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: HomiziColors.nightInk),
              ),
            ),
            Center(
              child: Hero(
                tag: heroTag,
                child: ClipOval(
                  child: SizedBox(
                    width: diameter,
                    height: diameter,
                    child: ProfilePortrait(
                      name: name,
                      bytes: bytes,
                      photoRef: photoRef,
                    ),
                  ),
                ),
              ),
            ),
            if (change != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton(
                    key: const Key('profile-photo-change'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      change();
                    },
                    child: Text(
                      homiziText(context, 'Change photo'),
                      style: const TextStyle(
                        color: HomiziColors.logoOrange,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
