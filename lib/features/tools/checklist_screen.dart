import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/discovery/discovery_controller.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';
import 'package:homizi/features/tools/tools_gateway.dart';
import 'package:homizi/features/tools/tools_providers.dart';
import 'package:image_picker/image_picker.dart';

class ChecklistScreen extends ConsumerStatefulWidget {
  const ChecklistScreen({super.key});

  @override
  ConsumerState<ChecklistScreen> createState() => _ChecklistScreenState();
}

class _ChecklistScreenState extends ConsumerState<ChecklistScreen> {
  final _title = TextEditingController();
  final _item = TextEditingController();
  final _notes = TextEditingController();
  var _room = inventoryRooms.first;
  var _condition = inventoryConditions.first;
  String? _matchId;
  String? _openId;
  var _busy = false;
  String? _note;
  List<MoveInChecklist> _lists = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _title.dispose();
    _item.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(toolsGatewayProvider).loadChecklists();
      if (!mounted) {
        return;
      }
      setState(() => _lists = rows);
    } on ToolsFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _note = error.message);
    }
  }

  MoveInChecklist? get _open {
    for (final list in _lists) {
      if (list.id == _openId) {
        return list;
      }
    }
    return null;
  }

  Future<void> _create() async {
    setState(() => _busy = true);
    try {
      final created = await ref
          .read(toolsGatewayProvider)
          .createChecklist(title: _title.text, matchId: _matchId);
      if (!mounted) {
        return;
      }
      _title.clear();
      setState(() {
        _lists = [created, ..._lists];
        _openId = created.id;
        _note = 'Checklist saved on your account.';
      });
    } on ToolsFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _note = error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _addItem() async {
    final open = _open;
    if (open == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final next = await ref
          .read(toolsGatewayProvider)
          .addItem(
            checklistId: open.id,
            room: _room,
            name: _item.text,
            condition: _condition,
            notes: _notes.text,
          );
      if (!mounted) {
        return;
      }
      _item.clear();
      _notes.clear();
      setState(() {
        _lists = [
          for (final list in _lists)
            if (list.id == next.id) next else list,
        ];
        _note = 'Item added.';
      });
    } on ToolsFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _note = error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _photo(InventoryItem item) async {
    final open = _open;
    if (open == null || !open.ownedByMe) {
      return;
    }
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (file == null) {
      return;
    }
    final bytes = await file.readAsBytes();
    final lower = file.name.toLowerCase();
    final extension = lower.endsWith('.png') ? 'png' : 'jpg';
    setState(() => _busy = true);
    try {
      await ref
          .read(toolsGatewayProvider)
          .attachPhoto(
            checklistId: open.id,
            itemId: item.id,
            bytes: bytes,
            extension: extension,
          );
      await _load();
      if (!mounted) {
        return;
      }
      setState(() => _note = 'Photo saved in your folder.');
    } on ToolsFailure catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _note = error.message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = ref.watch(discoveryProvider).matches;
    final open = _open;
    return Scaffold(
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Move-in checklist')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            homiziText(
              context,
              'Room by room. Link a match if the other person should read this. They cannot edit it.',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('checklist-title'),
            controller: _title,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Checklist title'),
              hintText: homiziText(context, 'Koramangala move-in'),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            key: const Key('checklist-match'),
            initialValue: _matchId,
            decoration: InputDecoration(
              labelText: homiziText(context, 'Share with a match'),
            ),
            items: [
              DropdownMenuItem(child: Text(homiziText(context, 'Only me'))),
              for (final match in matches)
                DropdownMenuItem(
                  value: match.matchId,
                  child: Text(match.otherDisplayName),
                ),
            ],
            onChanged: (value) => setState(() => _matchId = value),
          ),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('checklist-create'),
            onPressed: _busy ? null : () => unawaited(_create()),
            child: Text(homiziText(context, 'Create checklist')),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(homiziText(context, _note!), key: const Key('checklist-note')),
          ],
          const SizedBox(height: 20),
          for (final list in _lists)
            Card.outlined(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                key: Key('checklist-${list.id}'),
                title: Text(list.title),
                subtitle: Text(
                  homiziText(
                    context,
                    list.ownedByMe
                        ? '${list.items.length} items'
                        : 'Shared with you, read only',
                  ),
                ),
                trailing: Icon(
                  _openId == list.id ? Icons.expand_less : Icons.expand_more,
                ),
                onTap: () => setState(() {
                  _openId = _openId == list.id ? null : list.id;
                }),
              ),
            ),
          if (open != null) ...[
            Text(open.title, style: Theme.of(context).textTheme.titleMedium),
            if (!open.ownedByMe)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  homiziText(
                    context,
                    'Shared from a match. You can read this checklist.',
                  ),
                  key: const Key('checklist-readonly'),
                ),
              ),
            for (final item in open.items)
              Card.filled(
                margin: const EdgeInsets.only(top: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${item.room} · ${item.name}'),
                      Text(homiziText(context, conditionLabel(item.condition))),
                      if (item.notes.isNotEmpty) Text(item.notes),
                      if (item.photoBytes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Image.memory(
                            Uint8List.fromList(item.photoBytes!),
                            height: 120,
                            fit: BoxFit.cover,
                          ),
                        )
                      else if (item.photoPath != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            homiziText(context, 'Photo saved'),
                            key: Key('photo-${item.id}'),
                          ),
                        ),
                      if (open.ownedByMe)
                        TextButton(
                          key: Key('photo-button-${item.id}'),
                          onPressed: _busy
                              ? null
                              : () => unawaited(_photo(item)),
                          child: Text(homiziText(context, 'Add photo')),
                        ),
                    ],
                  ),
                ),
              ),
            if (open.ownedByMe) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('checklist-room'),
                initialValue: _room,
                decoration: InputDecoration(
                  labelText: homiziText(context, 'Room'),
                ),
                items: [
                  for (final room in inventoryRooms)
                    DropdownMenuItem(
                      value: room,
                      child: Text(homiziText(context, room)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _room = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('checklist-item'),
                controller: _item,
                decoration: InputDecoration(
                  labelText: homiziText(context, 'Item'),
                  hintText: homiziText(context, 'Sofa'),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('checklist-condition'),
                initialValue: _condition,
                decoration: InputDecoration(
                  labelText: homiziText(context, 'Condition'),
                ),
                items: [
                  for (final condition in inventoryConditions)
                    DropdownMenuItem(
                      value: condition,
                      child: Text(
                        homiziText(context, conditionLabel(condition)),
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _condition = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('checklist-notes'),
                controller: _notes,
                decoration: InputDecoration(
                  labelText: homiziText(context, 'Notes'),
                  hintText: homiziText(context, 'No stains on the seat'),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                key: const Key('checklist-add'),
                onPressed: _busy ? null : () => unawaited(_addItem()),
                child: Text(homiziText(context, 'Add item')),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
