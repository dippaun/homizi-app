import 'dart:typed_data';

import 'package:homizi/features/tools/domain/deposit_math.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';

class ToolsFailure implements Exception {
  const ToolsFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

const inventoryPhotosBucket = 'inventory-photos';

abstract interface class ToolsGateway {
  Future<List<RentReceipt>> loadReceipts();

  Future<RentReceipt> saveReceipt(RentReceipt receipt);

  Future<List<AgreementDraft>> loadAgreements();

  Future<AgreementDraft> saveAgreement(AgreementDraft draft);

  Future<List<MoveInChecklist>> loadChecklists();

  Future<MoveInChecklist> createChecklist({
    required String title,
    String? matchId,
  });

  Future<MoveInChecklist> addItem({
    required String checklistId,
    required String room,
    required String name,
    required String condition,
    required String notes,
  });

  Future<void> removeItem({
    required String checklistId,
    required String itemId,
  });

  Future<InventoryItem> attachPhoto({
    required String checklistId,
    required String itemId,
    required Uint8List bytes,
    required String extension,
  });

  Future<Uint8List?> loadPhoto(String path);

  Future<List<DepositTracker>> loadDeposits();

  Future<DepositTracker> saveDeposit({
    required String propertyLabel,
    required int depositPaidInr,
    DateTime? refundDueOn,
  });

  Future<DepositDeduction> addDeduction({
    required String trackerId,
    required String label,
    required int amountInr,
  });

  /// In-app notification only. Returns false when system alerts are off.
  Future<bool> remindDeposit(String trackerId);
}
