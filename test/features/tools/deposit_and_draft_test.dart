import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/features/tools/domain/deposit_math.dart';
import 'package:homizi/features/tools/domain/tool_pdf.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refund due never goes below zero', () {
    expect(refundDueInr(84000, 8000), 76000);
    expect(refundDueInr(84000, 90000), 0);
    expect(deductionsExceedDeposit(84000, 90000), isTrue);
    expect(deductionTotal(const [8000, 1500]), 9500);
  });

  test('agreement copy is an 11-month draft with the watermark', () {
    final draft = AgreementDraft(
      id: 'draft-1',
      licensorName: 'Rohan Mehta',
      licenseeName: 'Ananya Iyer',
      propertyAddress: '18, 4th Cross, Koramangala 5th Block, Bengaluru',
      city: 'Bengaluru',
      monthlyRentInr: 28000,
      depositInr: 84000,
      maintenanceInr: 2000,
      startDate: DateTime(2026, 11),
      createdAt: DateTime.utc(2026, 10, 17),
    );

    final paragraphs = agreementParagraphs(draft);
    expect(paragraphs, contains(agreementWatermark));
    expect(paragraphs.join('\n'), contains('11 months'));
    expect(paragraphs.join('\n'), contains('Ananya Iyer'));
    expect(draft.termMonths, 11);
    expect(
      agreementError(
        licensorName: 'R',
        licenseeName: 'Ananya Iyer',
        propertyAddress: '18, 4th Cross, Koramangala',
        city: 'Bengaluru',
        monthlyRentInr: 28000,
        depositInr: 0,
        maintenanceInr: 0,
      ),
      isNotNull,
    );
  });

  test('receipt and agreement PDFs keep the draft wording', () async {
    final receipt = RentReceipt(
      id: 'r1',
      tenantName: 'Ananya Iyer',
      ownerName: 'Rohan Mehta',
      propertyAddress: '18, 4th Cross, Koramangala 5th Block, Bengaluru',
      monthlyRentInr: 28000,
      periodStart: DateTime(2026, 4),
      periodEnd: DateTime(2026, 6),
      ownerPan: 'ABCDE1234F',
      paymentMode: 'upi',
      createdAt: DateTime.utc(2026, 10, 17),
    );
    final receiptBytes = await buildReceiptPdf(receipt);
    final receiptText = pdfPlainText(receiptBytes);
    expect(String.fromCharCodes(receiptBytes.take(5)), '%PDF-');
    expect(receiptText, contains('Ananya Iyer'));
    expect(receiptText, contains('HOMIZI did not collect this payment'));
    expect(receiptText, contains('ABCDE1234F'));
    expect(receiptText, contains('₹28,000'));

    final draft = AgreementDraft(
      id: 'd1',
      licensorName: 'Rohan Mehta',
      licenseeName: 'Ananya Iyer',
      propertyAddress: '18, 4th Cross, Koramangala 5th Block, Bengaluru',
      city: 'Bengaluru',
      monthlyRentInr: 28000,
      depositInr: 84000,
      maintenanceInr: 2000,
      startDate: DateTime(2026, 11),
      createdAt: DateTime.utc(2026, 10, 17),
    );
    final agreementBytes = await buildAgreementPdf(draft);
    final agreementText = pdfPlainText(agreementBytes);
    expect(agreementText, contains(agreementWatermark));
    expect(agreementText, contains('11 months'));
  });

  test('PAN and day parsing stay strict', () {
    expect(normalizePan(' abcde1234f '), 'ABCDE1234F');
    expect(normalizePan(''), isNull);
    expect(normalizePan('not-a-pan'), '');
    expect(parseDay('2026-12-01'), DateTime(2026, 12));
    expect(parseDay('2026-02-31'), isNull);
    expect(
      receiptError(
        tenantName: 'Ananya Iyer',
        ownerName: 'Rohan Mehta',
        propertyAddress: '18, 4th Cross, Koramangala 5th Block, Bengaluru',
        monthlyRentInr: 28000,
        periodStart: DateTime(2026, 4),
        periodEnd: DateTime(2026, 6),
        ownerPan: 'ABCDE1234F',
        paymentMode: 'upi',
      ),
      isNull,
    );
  });
}

/// Reads the text operators from an uncompressed PDF that embeds a Unicode font.
String pdfPlainText(List<int> bytes) {
  final raw = String.fromCharCodes(bytes);
  final fonts = <String, Map<int, int>>{};
  final fontRefs = RegExp(r'/Name/(F\d+)[\s\S]*?/ToUnicode (\d+) 0 R');
  final cmaps = <int, Map<int, int>>{};
  final cmapObjects = RegExp(
    r'(\d+) 0 obj\n<<[^>]*>>stream\n(/CIDInit[\s\S]*?)\nendstream',
  );
  for (final match in cmapObjects.allMatches(raw)) {
    cmaps[int.parse(match.group(1)!)] = _cmap(match.group(2)!);
  }
  for (final match in fontRefs.allMatches(raw)) {
    final cmap = cmaps[int.parse(match.group(2)!)];
    if (cmap != null) {
      fonts[match.group(1)!] = cmap;
    }
  }

  final text = StringBuffer();
  final contents = RegExp(r'stream\n([\s\S]*?)\nendstream');
  for (final stream in contents.allMatches(raw)) {
    final body = stream.group(1)!;
    if (!body.contains(' BT ') && !body.startsWith('BT ')) {
      continue;
    }
    var current = fonts.values.isEmpty
        ? const <int, int>{}
        : fonts.values.first;
    final tokens = RegExp(r'/(F\d+)\s+[\d.]+\s+Tf|<([0-9A-Fa-f]+)>');
    for (final token in tokens.allMatches(body)) {
      final fontName = token.group(1);
      if (fontName != null) {
        current = fonts[fontName] ?? current;
        continue;
      }
      final hex = token.group(2)!;
      if (hex.length % 4 != 0) {
        continue;
      }
      if (text.isNotEmpty) {
        text.write(' ');
      }
      for (var index = 0; index < hex.length; index += 4) {
        final cid = int.parse(hex.substring(index, index + 4), radix: 16);
        final code = current[cid];
        if (code != null && code != 0) {
          text.writeCharCode(code);
        }
      }
    }
  }
  return text.toString().replaceAll(RegExp(r'\s+'), ' ');
}

Map<int, int> _cmap(String body) {
  final map = <int, int>{};
  final row = RegExp(
    r'^<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>(?:\s*<([0-9A-Fa-f]+)>)?\s*$',
    multiLine: true,
  );
  for (final match in row.allMatches(body)) {
    final start = int.parse(match.group(1)!, radix: 16);
    final second = match.group(2)!;
    final third = match.group(3);
    if (third == null) {
      if (second.length == 4) {
        map[start] = int.parse(second, radix: 16);
      }
      continue;
    }
    final end = int.parse(second, radix: 16);
    final dest = int.parse(third, radix: 16);
    for (var cid = start; cid <= end; cid++) {
      map[cid] = dest + (cid - start);
    }
  }
  return map;
}
