import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/google_logo.dart';

/// Google's light sign-in button: white fill, grey stroke, near-black label,
/// and the four-color G. The rest of the screen stays on [HomiziColors].
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.onPressed,
    this.busy = false,
    super.key,
  });

  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Continue with Google',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(
          child: Material(
            color: GoogleSignInColors.fill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: const BorderSide(color: GoogleSignInColors.stroke),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? onPressed : null,
              hoverColor: GoogleSignInColors.hover,
              highlightColor: GoogleSignInColors.pressed,
              splashColor: GoogleSignInColors.pressed,
              child: const SizedBox(
                height: 40,
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GoogleLogo(),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Continue with Google',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            height: 20 / 14,
                            letterSpacing: 0.25,
                            color: GoogleSignInColors.label,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
