import 'dart:typed_data';

import 'package:homizi/core/network/offline_failure.dart';
import 'package:homizi/features/tools/domain/deposit_math.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';
import 'package:homizi/features/tools/tools_gateway.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseToolsGateway implements ToolsGateway {
  SupabaseToolsGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<List<RentReceipt>> loadReceipts() async {
    final user = _user();
    final rows = await _guard(
      () => _client
          .from('rent_receipts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false),
    );
    return [for (final row in rows) _receipt(_asMap(row))];
  }

  @override
  Future<RentReceipt> saveReceipt(RentReceipt receipt) async {
    final user = _user();
    final inserted = await _guard(
      () => _client
          .from('rent_receipts')
          .insert({
            'user_id': user.id,
            'tenant_name': receipt.tenantName.trim(),
            'owner_name': receipt.ownerName.trim(),
            'property_address': receipt.propertyAddress.trim(),
            'monthly_rent_inr': receipt.monthlyRentInr,
            'period_start': _day(receipt.periodStart),
            'period_end': _day(receipt.periodEnd),
            'owner_pan': receipt.ownerPan,
            'payment_mode': receipt.paymentMode,
          })
          .select()
          .single(),
    );
    return _receipt(_asMap(inserted));
  }

  @override
  Future<List<AgreementDraft>> loadAgreements() async {
    final user = _user();
    final rows = await _guard(
      () => _client
          .from('rent_agreement_drafts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false),
    );
    return [for (final row in rows) _agreement(_asMap(row))];
  }

  @override
  Future<AgreementDraft> saveAgreement(AgreementDraft draft) async {
    final user = _user();
    final inserted = await _guard(
      () => _client
          .from('rent_agreement_drafts')
          .insert({
            'user_id': user.id,
            'licensor_name': draft.licensorName.trim(),
            'licensee_name': draft.licenseeName.trim(),
            'property_address': draft.propertyAddress.trim(),
            'city': draft.city.trim(),
            'monthly_rent_inr': draft.monthlyRentInr,
            'deposit_inr': draft.depositInr,
            'maintenance_inr': draft.maintenanceInr,
            'start_date': _day(draft.startDate),
            'term_months': 11,
          })
          .select()
          .single(),
    );
    return _agreement(_asMap(inserted));
  }

  @override
  Future<List<MoveInChecklist>> loadChecklists() async {
    final user = _user();
    final lists = await _guard(
      () => _client
          .from('move_in_checklists')
          .select()
          .order('updated_at', ascending: false),
    );
    final items = await _guard(
      () => _client.from('move_in_items').select().order('sort_order'),
    );
    final byList = <String, List<InventoryItem>>{};
    for (final raw in items) {
      final row = _asMap(raw);
      final checklistId = row['checklist_id'];
      if (checklistId is! String) {
        continue;
      }
      final item = _item(row);
      if (item == null) {
        continue;
      }
      byList.putIfAbsent(checklistId, () => []).add(item);
    }
    return [for (final raw in lists) ?_checklist(_asMap(raw), user.id, byList)];
  }

  @override
  Future<MoveInChecklist> createChecklist({
    required String title,
    String? matchId,
  }) async {
    final user = _user();
    final trimmed = title.trim();
    if (trimmed.length < 3 || trimmed.length > 80) {
      throw const ToolsFailure(
        'Give the checklist a title of 3 to 80 characters.',
      );
    }
    final inserted = await _guard(
      () => _client
          .from('move_in_checklists')
          .insert({'user_id': user.id, 'title': trimmed, 'match_id': matchId})
          .select()
          .single(),
    );
    final list = _checklist(_asMap(inserted), user.id, const {});
    if (list == null) {
      throw const ToolsFailure('The checklist was not saved.');
    }
    return list;
  }

  @override
  Future<MoveInChecklist> addItem({
    required String checklistId,
    required String room,
    required String name,
    required String condition,
    required String notes,
  }) async {
    if (!inventoryRooms.contains(room) ||
        !inventoryConditions.contains(condition)) {
      throw const ToolsFailure('Choose a room and a condition.');
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 80) {
      throw const ToolsFailure('Name the item in 80 characters or fewer.');
    }
    if (notes.trim().length > 400) {
      throw const ToolsFailure('Keep the note to 400 characters.');
    }
    await _guard(
      () => _client.from('move_in_items').insert({
        'checklist_id': checklistId,
        'room': room,
        'item_name': trimmed,
        'condition': condition,
        'notes': notes.trim().isEmpty ? null : notes.trim(),
      }),
    );
    return _one(checklistId);
  }

  @override
  Future<void> removeItem({
    required String checklistId,
    required String itemId,
  }) async {
    await _guard(() => _client.from('move_in_items').delete().eq('id', itemId));
  }

  @override
  Future<InventoryItem> attachPhoto({
    required String checklistId,
    required String itemId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final user = _user();
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const ToolsFailure('Use a photo under 5 MB.');
    }
    final ext = extension == 'png' ? 'png' : 'jpg';
    final path = '${user.id}/$itemId.$ext';
    try {
      await _client.storage
          .from(inventoryPhotosBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
            ),
          );
    } catch (error) {
      throw ToolsFailure(_photo(error));
    }
    await _guard(
      () => _client
          .from('move_in_items')
          .update({'photo_path': path})
          .eq('id', itemId),
    );
    final list = await _one(checklistId);
    for (final item in list.items) {
      if (item.id == itemId) {
        return item;
      }
    }
    throw const ToolsFailure('The photo was saved but the item was not found.');
  }

  @override
  Future<Uint8List?> loadPhoto(String path) async {
    _user();
    try {
      return await _client.storage.from(inventoryPhotosBucket).download(path);
    } catch (error) {
      throw ToolsFailure(_photo(error));
    }
  }

  @override
  Future<List<DepositTracker>> loadDeposits() async {
    final user = _user();
    final rows = await _guard(
      () => _client
          .from('deposit_trackers')
          .select()
          .eq('user_id', user.id)
          .order('updated_at', ascending: false),
    );
    final deductions = await _guard(
      () => _client.from('deposit_deductions').select(),
    );
    final byTracker = <String, List<DepositDeduction>>{};
    for (final raw in deductions) {
      final row = _asMap(raw);
      final trackerId = row['tracker_id'];
      final deduction = _deduction(row);
      if (trackerId is! String || deduction == null) {
        continue;
      }
      byTracker.putIfAbsent(trackerId, () => []).add(deduction);
    }
    return [for (final raw in rows) ?_deposit(_asMap(raw), byTracker)];
  }

  @override
  Future<DepositTracker> saveDeposit({
    required String propertyLabel,
    required int depositPaidInr,
    DateTime? refundDueOn,
  }) async {
    final user = _user();
    final label = propertyLabel.trim();
    if (label.length < 3 || label.length > 80 || depositPaidInr < 0) {
      throw const ToolsFailure(
        'Enter the home and the deposit in whole rupees.',
      );
    }
    final inserted = await _guard(
      () => _client
          .from('deposit_trackers')
          .insert({
            'user_id': user.id,
            'property_label': label,
            'deposit_paid_inr': depositPaidInr,
            'refund_due_on': refundDueOn == null ? null : _day(refundDueOn),
          })
          .select()
          .single(),
    );
    final tracker = _deposit(_asMap(inserted), const {});
    if (tracker == null) {
      throw const ToolsFailure('The deposit was not saved.');
    }
    return tracker;
  }

  @override
  Future<DepositDeduction> addDeduction({
    required String trackerId,
    required String label,
    required int amountInr,
  }) async {
    final trimmed = label.trim();
    if (trimmed.length < 2 || trimmed.length > 80 || amountInr < 0) {
      throw const ToolsFailure(
        'Enter a deduction label and a whole-rupee amount.',
      );
    }
    final inserted = await _guard(
      () => _client
          .from('deposit_deductions')
          .insert({
            'tracker_id': trackerId,
            'label': trimmed,
            'amount_inr': amountInr,
          })
          .select()
          .single(),
    );
    final deduction = _deduction(_asMap(inserted));
    if (deduction == null) {
      throw const ToolsFailure('The deduction was not saved.');
    }
    return deduction;
  }

  @override
  Future<bool> remindDeposit(String trackerId) async {
    _user();
    final raw = await _guard(
      () => _client.rpc<dynamic>(
        'remind_own_deposit',
        params: {'p_tracker_id': trackerId},
      ),
    );
    return raw == true;
  }

  Future<MoveInChecklist> _one(String checklistId) async {
    final lists = await loadChecklists();
    for (final list in lists) {
      if (list.id == checklistId) {
        return list;
      }
    }
    throw const ToolsFailure('That checklist is not on your account.');
  }

  User _user() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const ToolsFailure('Sign in before using tools.');
    }
    return user;
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on ToolsFailure {
      rethrow;
    } on PostgrestException catch (error) {
      throw ToolsFailure(_safe(error.message));
    } catch (error) {
      throw ToolsFailure(describedFailure(error));
    }
  }
}

String _day(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime _date(Object? raw) {
  final parsed = DateTime.tryParse('${raw ?? ''}');
  if (parsed == null) {
    throw const ToolsFailure('A saved date was not readable.');
  }
  return DateTime(parsed.year, parsed.month, parsed.day);
}

int _int(Object? raw) {
  if (raw is int) {
    return raw;
  }
  if (raw is num) {
    return raw.toInt();
  }
  throw const ToolsFailure('A saved amount was not readable.');
}

String _text(Object? raw, String fallback) {
  if (raw is String && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  throw ToolsFailure(fallback);
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  throw const ToolsFailure('A saved row was not readable.');
}

RentReceipt _receipt(Map<String, dynamic> row) {
  final pan = row['owner_pan'];
  return RentReceipt(
    id: _text(row['id'], 'A receipt id was missing.'),
    tenantName: _text(row['tenant_name'], 'A tenant name was missing.'),
    ownerName: _text(row['owner_name'], 'An owner name was missing.'),
    propertyAddress: _text(row['property_address'], 'An address was missing.'),
    monthlyRentInr: _int(row['monthly_rent_inr']),
    periodStart: _date(row['period_start']),
    periodEnd: _date(row['period_end']),
    ownerPan: pan is String && pan.isNotEmpty ? pan : null,
    paymentMode: _text(row['payment_mode'], 'A payment mode was missing.'),
    createdAt:
        DateTime.tryParse('${row['created_at']}') ?? DateTime.now().toUtc(),
  );
}

AgreementDraft _agreement(Map<String, dynamic> row) {
  return AgreementDraft(
    id: _text(row['id'], 'A draft id was missing.'),
    licensorName: _text(row['licensor_name'], 'A licensor name was missing.'),
    licenseeName: _text(row['licensee_name'], 'A licensee name was missing.'),
    propertyAddress: _text(row['property_address'], 'An address was missing.'),
    city: _text(row['city'], 'A city was missing.'),
    monthlyRentInr: _int(row['monthly_rent_inr']),
    depositInr: _int(row['deposit_inr']),
    maintenanceInr: _int(row['maintenance_inr']),
    startDate: _date(row['start_date']),
    termMonths: _int(row['term_months']),
    createdAt:
        DateTime.tryParse('${row['created_at']}') ?? DateTime.now().toUtc(),
  );
}

InventoryItem? _item(Map<String, dynamic> row) {
  final id = row['id'];
  final room = row['room'];
  final name = row['item_name'];
  final condition = row['condition'];
  if (id is! String ||
      room is! String ||
      name is! String ||
      condition is! String) {
    return null;
  }
  final notes = row['notes'];
  final photo = row['photo_path'];
  return InventoryItem(
    id: id,
    room: room,
    name: name,
    condition: condition,
    notes: notes is String ? notes : '',
    photoPath: photo is String ? photo : null,
  );
}

MoveInChecklist? _checklist(
  Map<String, dynamic> row,
  String userId,
  Map<String, List<InventoryItem>> items,
) {
  final id = row['id'];
  final title = row['title'];
  if (id is! String || title is! String) {
    return null;
  }
  final matchId = row['match_id'];
  return MoveInChecklist(
    id: id,
    title: title,
    ownedByMe: row['user_id'] == userId,
    matchId: matchId is String ? matchId : null,
    items: items[id] ?? const [],
  );
}

DepositDeduction? _deduction(Map<String, dynamic> row) {
  final id = row['id'];
  final label = row['label'];
  if (id is! String || label is! String) {
    return null;
  }
  return DepositDeduction(
    id: id,
    label: label,
    amountInr: _int(row['amount_inr']),
  );
}

DepositTracker? _deposit(
  Map<String, dynamic> row,
  Map<String, List<DepositDeduction>> deductions,
) {
  final id = row['id'];
  final label = row['property_label'];
  if (id is! String || label is! String) {
    return null;
  }
  final due = row['refund_due_on'];
  return DepositTracker(
    id: id,
    propertyLabel: label,
    depositPaidInr: _int(row['deposit_paid_inr']),
    refundDueOn: due == null ? null : _date(due),
    deductions: deductions[id] ?? const [],
  );
}

String _safe(String message) {
  final trimmed = message.trim();
  if (trimmed.isEmpty ||
      trimmed.length > 180 ||
      trimmed.contains('@') ||
      trimmed.contains('+91')) {
    return 'The tool request failed. Contact details stay off this screen.';
  }
  return trimmed;
}

String _photo(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('row-level security') || message.contains('42501')) {
    return 'Photo upload was refused. The inventory-photos policies are not installed on this project yet.';
  }
  if (message.contains('bucket')) {
    return 'The inventory-photos bucket is missing on this project.';
  }
  return 'The photo could not be saved.';
}
