import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/verification/identity_verification_gateway.dart';
import 'package:homizi/features/session/session_controller.dart';

class TenantProfileScreen extends ConsumerStatefulWidget {
  const TenantProfileScreen({super.key});

  @override
  ConsumerState<TenantProfileScreen> createState() =>
      _TenantProfileScreenState();
}

class _TenantProfileScreenState extends ConsumerState<TenantProfileScreen> {
  final _name = TextEditingController();
  final _occupation = TextEditingController();
  final _bio = TextEditingController();
  VerificationStatus _status = VerificationStatus.notStarted;
  String? _note;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _occupation.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _mockVerify() async {
    setState(() => _busy = true);
    final snapshot = await ref
        .read(verificationGatewayProvider)
        .startMockCheck(userId: ref.read(sessionProvider).contact);
    if (!mounted) {
      return;
    }
    setState(() {
      _busy = false;
      _status = snapshot.status;
      _note = snapshot.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tenant profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Only fields a match needs. Date of birth and contact details are not on this form.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Display name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _occupation,
            decoration: const InputDecoration(labelText: 'Occupation'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            maxLines: 3,
            maxLength: 500,
            decoration: const InputDecoration(labelText: 'Public bio'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Verification status'),
            subtitle: Text(_status.name),
          ),
          if (_note != null) Text(_note!),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _mockVerify,
            child: Text(
              _busy ? 'Queuing mock check…' : 'Start mock verification',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This does not call a verification provider and does not upload a document.',
          ),
        ],
      ),
    );
  }
}
