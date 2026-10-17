import 'dart:typed_data';
import 'dart:ui' as ui;

/// Centre-crops [bytes] to a square PNG. Works for camera, gallery, and web files.
Future<Uint8List> centerSquarePng(Uint8List bytes, {int side = 512}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final crop = image.width < image.height ? image.width : image.height;
  final src = ui.Rect.fromLTWH(
    (image.width - crop) / 2,
    (image.height - crop) / 2,
    crop.toDouble(),
    crop.toDouble(),
  );
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    image,
    src,
    ui.Rect.fromLTWH(0, 0, side.toDouble(), side.toDouble()),
    ui.Paint(),
  );
  final cropped = await recorder.endRecording().toImage(side, side);
  final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  cropped.dispose();
  if (data == null) {
    throw StateError('The photo could not be cropped.');
  }
  return data.buffer.asUint8List();
}
