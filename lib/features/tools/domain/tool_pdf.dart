import 'package:flutter/services.dart';
import 'package:homizi/core/format/inr.dart';
import 'package:homizi/features/tools/domain/tool_records.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _orange = PdfColor(247 / 255, 86 / 255, 32 / 255);

Future<pw.ThemeData>? _theme;

Future<pw.ThemeData> _pdfTheme() {
  return _theme ??= () async {
    final regular = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Regular.ttf'),
    );
    final bold = pw.Font.ttf(
      await rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'),
    );
    return pw.ThemeData.withFont(base: regular, bold: bold);
  }();
}

Future<Uint8List> buildReceiptPdf(RentReceipt receipt) async {
  final doc = pw.Document(compress: false);
  final theme = await _pdfTheme();
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(40),
      build: (context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'HOMIZI',
              style: const pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: _orange,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Rent receipt',
              style: const pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 16),
            _line('Tenant', receipt.tenantName),
            _line('Owner', receipt.ownerName),
            _line('Property', receipt.propertyAddress),
            _line('Monthly rent', formatInr(receipt.monthlyRentInr)),
            _line('Period', monthSpan(receipt.periodStart, receipt.periodEnd)),
            _line('Payment mode', paymentModeLabel(receipt.paymentMode)),
            if (receipt.ownerPan != null) _line('Owner PAN', receipt.ownerPan!),
            pw.Spacer(),
            pw.Text(
              'Generated in HOMIZI for your records. HOMIZI did not collect this payment.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        );
      },
    ),
  );
  return doc.save();
}

Future<Uint8List> buildAgreementPdf(AgreementDraft draft) async {
  final doc = pw.Document(compress: false);
  final theme = await _pdfTheme();
  final paragraphs = agreementParagraphs(draft);
  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      theme: theme,
      margin: const pw.EdgeInsets.all(40),
      build: (context) {
        return pw.Stack(
          children: [
            pw.Center(
              child: pw.Transform.rotate(
                angle: -0.5,
                child: pw.Text(
                  agreementWatermark,
                  style: const pw.TextStyle(
                    fontSize: 18,
                    color: PdfColors.grey400,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  color: PdfColors.grey200,
                  child: pw.Text(
                    agreementWatermark,
                    textAlign: pw.TextAlign.center,
                    style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'HOMIZI',
                  style: const pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                    color: _orange,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'Leave and licence draft',
                  style: const pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
                for (final paragraph in paragraphs) ...[
                  pw.Text(paragraph),
                  pw.SizedBox(height: 8),
                ],
                pw.Spacer(),
                pw.Text(
                  agreementWatermark,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
  return doc.save();
}

pw.Widget _line(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.RichText(
      text: pw.TextSpan(
        children: [
          pw.TextSpan(
            text: '$label: ',
            style: const pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.TextSpan(text: value),
        ],
      ),
    ),
  );
}
