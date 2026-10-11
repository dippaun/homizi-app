import 'package:flutter/material.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';

class RequirementFormScreen extends StatefulWidget {
  const RequirementFormScreen({super.key});

  @override
  State<RequirementFormScreen> createState() => _RequirementFormScreenState();
}

class _RequirementFormScreenState extends State<RequirementFormScreen> {
  final _min = TextEditingController();
  final _max = TextEditingController();
  final _locality = TextEditingController();
  String _city = 'Bengaluru';
  DateTime? _moveIn;
  int _occupancy = 1;
  List<String> _errors = const [];
  String? _saved;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    _locality.dispose();
    super.dispose();
  }

  RequirementDraft _draft() {
    return RequirementDraft(
      budgetMinInr: int.tryParse(_min.text.trim()),
      budgetMaxInr: int.tryParse(_max.text.trim()),
      city: _city,
      locality: _locality.text,
      moveInDate: _moveIn,
      occupancy: _occupancy,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDate: _moveIn ?? now,
    );
    if (picked != null) {
      setState(() => _moveIn = picked);
    }
  }

  void _save() {
    final errors = _draft().errors(today: DateTime.now());
    setState(() {
      _errors = errors;
      _saved = errors.isEmpty
          ? 'Draft kept on this device. Server persistence arrives with the requirements module.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final moveLabel = _moveIn == null
        ? 'Choose a move-in date'
        : '${_moveIn!.year}-${_moveIn!.month.toString().padLeft(2, '0')}-${_moveIn!.day.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: const Text('What you need')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Budget, city, locality, move-in, and occupancy. Lifestyle scoring does not use gender, religion, caste, or age.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _city,
            decoration: const InputDecoration(labelText: 'City'),
            items: const [
              DropdownMenuItem(value: 'Bengaluru', child: Text('Bengaluru')),
              DropdownMenuItem(value: 'Pune', child: Text('Pune')),
              DropdownMenuItem(value: 'Hyderabad', child: Text('Hyderabad')),
              DropdownMenuItem(value: 'Mumbai', child: Text('Mumbai')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _city = value);
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locality,
            decoration: const InputDecoration(
              labelText: 'Locality',
              hintText: 'Koramangala',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _min,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Minimum budget (₹)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _max,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Maximum budget (₹)'),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Occupancy'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _occupancy > 1
                      ? () => setState(() => _occupancy -= 1)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$_occupancy'),
                IconButton(
                  onPressed: _occupancy < 20
                      ? () => setState(() => _occupancy += 1)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
          OutlinedButton(onPressed: _pickDate, child: Text(moveLabel)),
          if (_errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final error in _errors)
              Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
          if (_saved != null) ...[const SizedBox(height: 12), Text(_saved!)],
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save draft')),
        ],
      ),
    );
  }
}
