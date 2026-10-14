import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/discovery/domain/contact_gate.dart';

class ContactGatePanel extends StatelessWidget {
  const ContactGatePanel({required this.gate, this.matchId, super.key});

  final ContactGate gate;
  final String? matchId;

  @override
  Widget build(BuildContext context) {
    final phone = gate.phone;
    final email = gate.email;
    final phoneKey = matchId == null
        ? const Key('contact-phone')
        : Key('contact-phone-$matchId');
    final emailKey = matchId == null
        ? const Key('contact-email')
        : Key('contact-email-$matchId');
    return Container(
      key: matchId == null
          ? const Key('contact-gate')
          : Key('contact-gate-$matchId'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: HomiziColors.mist,
        borderRadius: BorderRadius.circular(16),
      ),
      child: phone == null && email == null
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline, color: HomiziColors.accent),
                const SizedBox(width: 10),
                Expanded(child: Text(homiziText(context, gate.hiddenCopy))),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(homiziText(context, 'Shared for this match.')),
                if (phone != null) ...[
                  const SizedBox(height: 8),
                  Text(homiziText(context, phone), key: phoneKey),
                ],
                if (email != null) ...[
                  const SizedBox(height: 8),
                  Text(homiziText(context, email), key: emailKey),
                ],
              ],
            ),
    );
  }
}
