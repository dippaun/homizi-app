import 'dart:typed_data';

import 'package:homizi/core/ids/local_id.dart';
import 'package:homizi/features/notifications/demo_notification_gateway.dart';
import 'package:homizi/features/notifications/domain/inbox_notice.dart';
import 'package:homizi/features/notifications/notification_gateway.dart';
import 'package:homizi/features/tools/domain/deposit_math.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';
import 'package:homizi/features/tools/tools_gateway.dart';

/// In-memory rent tools for demo mode. Nothing is sent to a server.
class DemoToolsGateway implements ToolsGateway {
  DemoToolsGateway({NotificationGateway? notifications})
    : _notifications = notifications ?? DemoNotificationGateway();

  final NotificationGateway _notifications;
  final List<RentReceipt> _receipts = [];
  final List<AgreementDraft> _agreements = [];
  final List<MoveInChecklist> _checklists = [];
  final List<DepositTracker> _deposits = [];

  @override
  Future<List<RentReceipt>> loadReceipts() async => [..._receipts];

  @override
  Future<RentReceipt> saveReceipt(RentReceipt receipt) async {
    final saved = RentReceipt(
      id: receipt.id.isEmpty ? newLocalId() : receipt.id,
      tenantName: receipt.tenantName.trim(),
      ownerName: receipt.ownerName.trim(),
      propertyAddress: receipt.propertyAddress.trim(),
      monthlyRentInr: receipt.monthlyRentInr,
      periodStart: receipt.periodStart,
      periodEnd: receipt.periodEnd,
      ownerPan: receipt.ownerPan,
      paymentMode: receipt.paymentMode,
      createdAt: receipt.createdAt,
    );
    _receipts.insert(0, saved);
    return saved;
  }

  @override
  Future<List<AgreementDraft>> loadAgreements() async => [..._agreements];

  @override
  Future<AgreementDraft> saveAgreement(AgreementDraft draft) async {
    final saved = AgreementDraft(
      id: draft.id.isEmpty ? newLocalId() : draft.id,
      licensorName: draft.licensorName.trim(),
      licenseeName: draft.licenseeName.trim(),
      propertyAddress: draft.propertyAddress.trim(),
      city: draft.city.trim(),
      monthlyRentInr: draft.monthlyRentInr,
      depositInr: draft.depositInr,
      maintenanceInr: draft.maintenanceInr,
      startDate: draft.startDate,
      createdAt: draft.createdAt,
    );
    _agreements.insert(0, saved);
    return saved;
  }

  @override
  Future<List<MoveInChecklist>> loadChecklists() async {
    return [for (final list in _checklists) list];
  }

  @override
  Future<MoveInChecklist> createChecklist({
    required String title,
    String? matchId,
  }) async {
    final trimmed = title.trim();
    if (trimmed.length < 3 || trimmed.length > 80) {
      throw const ToolsFailure(
        'Give the checklist a title of 3 to 80 characters.',
      );
    }
    final created = MoveInChecklist(
      id: newLocalId(),
      title: trimmed,
      ownedByMe: true,
      matchId: matchId,
    );
    _checklists.insert(0, created);
    return created;
  }

  @override
  Future<MoveInChecklist> addItem({
    required String checklistId,
    required String room,
    required String name,
    required String condition,
    required String notes,
  }) async {
    final list = _owned(checklistId);
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
    final item = InventoryItem(
      id: newLocalId(),
      room: room,
      name: trimmed,
      condition: condition,
      notes: notes.trim(),
    );
    final next = list.copyWith(items: [...list.items, item]);
    _replace(next);
    return next;
  }

  @override
  Future<void> removeItem({
    required String checklistId,
    required String itemId,
  }) async {
    final list = _owned(checklistId);
    _replace(
      list.copyWith(
        items: [
          for (final item in list.items)
            if (item.id != itemId) item,
        ],
      ),
    );
  }

  @override
  Future<InventoryItem> attachPhoto({
    required String checklistId,
    required String itemId,
    required Uint8List bytes,
    required String extension,
  }) async {
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw const ToolsFailure('Use a photo under 5 MB.');
    }
    final list = _owned(checklistId);
    InventoryItem? updated;
    final items = [
      for (final item in list.items)
        if (item.id == itemId)
          updated = item.copyWith(
            photoPath: 'demo/$itemId.$extension',
            photoBytes: bytes,
          )
        else
          item,
    ];
    if (updated == null) {
      throw const ToolsFailure('That item is not on this checklist.');
    }
    _replace(list.copyWith(items: items));
    return updated;
  }

  @override
  Future<Uint8List?> loadPhoto(String path) async {
    for (final list in _checklists) {
      for (final item in list.items) {
        if (item.photoPath == path && item.photoBytes != null) {
          return Uint8List.fromList(item.photoBytes!);
        }
      }
    }
    return null;
  }

  @override
  Future<List<DepositTracker>> loadDeposits() async => [..._deposits];

  @override
  Future<DepositTracker> saveDeposit({
    required String propertyLabel,
    required int depositPaidInr,
    DateTime? refundDueOn,
  }) async {
    final label = propertyLabel.trim();
    if (label.length < 3 || label.length > 80) {
      throw const ToolsFailure('Name the home in 3 to 80 characters.');
    }
    if (depositPaidInr < 0) {
      throw const ToolsFailure('Enter the deposit in whole rupees.');
    }
    final saved = DepositTracker(
      id: newLocalId(),
      propertyLabel: label,
      depositPaidInr: depositPaidInr,
      refundDueOn: refundDueOn,
    );
    _deposits.insert(0, saved);
    return saved;
  }

  @override
  Future<DepositDeduction> addDeduction({
    required String trackerId,
    required String label,
    required int amountInr,
  }) async {
    final index = _deposits.indexWhere((item) => item.id == trackerId);
    if (index < 0) {
      throw const ToolsFailure('That deposit record is not on this device.');
    }
    final trimmed = label.trim();
    if (trimmed.length < 2 || trimmed.length > 80 || amountInr < 0) {
      throw const ToolsFailure(
        'Enter a deduction label and a whole-rupee amount.',
      );
    }
    final deduction = DepositDeduction(
      id: newLocalId(),
      label: trimmed,
      amountInr: amountInr,
    );
    final current = _deposits[index];
    _deposits[index] = DepositTracker(
      id: current.id,
      propertyLabel: current.propertyLabel,
      depositPaidInr: current.depositPaidInr,
      refundDueOn: current.refundDueOn,
      deductions: [...current.deductions, deduction],
    );
    return deduction;
  }

  @override
  Future<bool> remindDeposit(String trackerId) async {
    final index = _deposits.indexWhere((item) => item.id == trackerId);
    if (index < 0) {
      throw const ToolsFailure('That deposit record is not on this device.');
    }
    if (_deposits[index].refundDueOn == null) {
      throw const ToolsFailure(
        'Add a refund due date before setting a reminder.',
      );
    }
    final prefs = await _notifications.loadPreferences();
    if (!prefs.system) {
      return false;
    }
    final notifications = _notifications;
    if (notifications is DemoNotificationGateway) {
      notifications.seed(
        InboxNotice(
          id: newLocalId(),
          type: 'deposit_reminder',
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
    return true;
  }

  /// A checklist shared with this device, read only.
  void seedShared(MoveInChecklist checklist) {
    _checklists.add(
      MoveInChecklist(
        id: checklist.id,
        title: checklist.title,
        ownedByMe: false,
        matchId: checklist.matchId,
        items: checklist.items,
      ),
    );
  }

  MoveInChecklist _owned(String id) {
    final index = _checklists.indexWhere((item) => item.id == id);
    if (index < 0) {
      throw const ToolsFailure('That checklist is not on this device.');
    }
    final list = _checklists[index];
    if (!list.ownedByMe) {
      throw const ToolsFailure(
        'This checklist is shared with you as read only.',
      );
    }
    return list;
  }

  void _replace(MoveInChecklist next) {
    final index = _checklists.indexWhere((item) => item.id == next.id);
    _checklists[index] = next;
  }
}
