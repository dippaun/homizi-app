import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Shares the PDF. On the web this downloads the file. No outside service.
Future<void> deliverPdf({required Uint8List bytes, required String filename}) {
  return Printing.sharePdf(bytes: bytes, filename: filename);
}
