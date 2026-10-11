import 'package:flutter/material.dart';

class HostProfileScreen extends StatefulWidget {
  const HostProfileScreen({super.key});

  @override
  State<HostProfileScreen> createState() => _HostProfileScreenState();
}

class _HostProfileScreenState extends State<HostProfileScreen> {
  String _category = 'owner';
  final _company = TextEditingController();
  String? _saved;

  @override
  void dispose() {
    _company.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host profile')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Host category is a claim. A badge is not shown until a future review. Contact details stay in the private contact record.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Host category'),
            items: const [
              DropdownMenuItem(value: 'owner', child: Text('Owner')),
              DropdownMenuItem(value: 'broker', child: Text('Broker')),
              DropdownMenuItem(value: 'company', child: Text('Company')),
              DropdownMenuItem(value: 'flatmate', child: Text('Flatmate')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _category = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _company,
            decoration: const InputDecoration(
              labelText: 'Company name (optional)',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              setState(() {
                _saved =
                    'Saved on this device as $_category. The server profile update is a later task.';
              });
            },
            child: const Text('Save host profile'),
          ),
          if (_saved != null) ...[const SizedBox(height: 12), Text(_saved!)],
        ],
      ),
    );
  }
}
