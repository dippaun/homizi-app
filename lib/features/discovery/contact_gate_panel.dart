import 'package:flutter/material.dart';
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
        color: HomiziColors.card,
        border: Border.all(color: HomiziColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: phone == null && email == null
          ? Text(gate.hiddenCopy)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Shared for this match.'),
                if (phone != null) ...[
                  const SizedBox(height: 8),
                  Text(phone, key: phoneKey),
                ],
                if (email != null) ...[
                  const SizedBox(height: 8),
                  Text(email, key: emailKey),
                ],
              ],
            ),
    );
  }
}
