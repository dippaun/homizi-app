import 'package:flutter/material.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/auth/otp/hcaptcha_mount_stub.dart'
    if (dart.library.html) 'hcaptcha_mount_web.dart';

/// Official hCaptcha test site key. It always passes and is not a secret.
const hcaptchaTestSiteKey = '10000000-ffff-ffff-ffff-000000000001';

/// hCaptcha checkbox for Flutter web. An empty [siteKey] draws nothing.
///
/// The secret stays in the Supabase dashboard. This widget only receives the
/// public site key.
class HcaptchaField extends StatefulWidget {
  const HcaptchaField({
    required this.siteKey,
    required this.onToken,
    super.key,
  });

  final String siteKey;
  final ValueChanged<String?> onToken;

  @override
  State<HcaptchaField> createState() => _HcaptchaFieldState();
}

class _HcaptchaFieldState extends State<HcaptchaField> {
  final _anchor = GlobalKey();
  String? _elementId;
  bool _scriptRequested = false;

  @override
  void initState() {
    super.initState();
    if (widget.siteKey.isEmpty) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _mount());
  }

  @override
  void didUpdateWidget(HcaptchaField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.siteKey != widget.siteKey) {
      _remove();
      widget.onToken(null);
      WidgetsBinding.instance.addPostFrameCallback((_) => _mount());
    }
  }

  @override
  void dispose() {
    _remove();
    super.dispose();
  }

  void _mount() {
    if (!mounted || widget.siteKey.isEmpty || _elementId != null) {
      return;
    }
    final box = _anchor.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return;
    }
    final offset = box.localToGlobal(Offset.zero);
    _elementId = 'homizi-hcaptcha-${identityHashCode(this)}';
    mountHcaptcha(
      elementId: _elementId!,
      siteKey: widget.siteKey,
      left: offset.dx,
      top: offset.dy,
      onToken: (token) {
        if (mounted) {
          widget.onToken(token);
        }
      },
      scriptRequested: _scriptRequested,
    );
    _scriptRequested = true;
  }

  void _remove() {
    final id = _elementId;
    _elementId = null;
    if (id != null) {
      removeHcaptcha(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.siteKey.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      key: _anchor,
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HomiziColors.line),
      ),
      child: const Row(
        children: [
          _CaptchaBox(),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "I'm not a robot",
              key: Key('hcaptcha-anchor'),
              style: TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'hCaptcha',
            style: TextStyle(color: HomiziColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CaptchaBox extends StatelessWidget {
  const _CaptchaBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: HomiziColors.muted),
      ),
    );
  }
}
