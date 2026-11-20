import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Longest side of an interactive crop export.
const cropExportLongSide = 1080;

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
  codec.dispose();
  if (data == null) {
    throw StateError('The photo could not be cropped.');
  }
  return data.buffer.asUint8List();
}

/// A decoded frame plus the codec that owns its bytes.
class DecodedPhoto {
  DecodedPhoto(this.codec, this.image);

  final ui.Codec codec;
  final ui.Image image;

  void dispose() {
    image.dispose();
    codec.dispose();
  }
}

/// Decodes [bytes] for framing. Null when the file is not a readable image.
Future<DecodedPhoto?> decodeUiImage(Uint8List bytes) async {
  ui.Codec? codec;
  try {
    codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (image.width < 1 || image.height < 1) {
      image.dispose();
      codec.dispose();
      return null;
    }
    return DecodedPhoto(codec, image);
  } on Object {
    codec?.dispose();
    return null;
  }
}

/// Output pixels for [aspectWidth]:[aspectHeight]. A square preset is equal.
(int, int) cropOutputSize({
  required int aspectWidth,
  required int aspectHeight,
  required int longSide,
}) {
  if (aspectWidth == aspectHeight) {
    return (longSide, longSide);
  }
  if (aspectWidth > aspectHeight) {
    final height = math.max(1, (longSide * aspectHeight / aspectWidth).round());
    return (longSide, height);
  }
  final width = math.max(1, (longSide * aspectWidth / aspectHeight).round());
  return (width, longSide);
}

/// Smallest long side that still clears a 720 by 480 listing photo.
int minimumCropLongSide({required int aspectWidth, required int aspectHeight}) {
  final longForShort = aspectWidth > aspectHeight
      ? (480 * aspectWidth / aspectHeight).ceil()
      : (480 * aspectHeight / aspectWidth).ceil();
  return math.max(720, longForShort);
}

/// Source pixels under the crop window.
///
/// [tx] and [ty] are the scaled image's top-left inside the window.
/// [scale] is 1 when the image just covers that window.
/// [outputAspect] is width / height of the file that will be saved.
ui.Rect cropSourceRect({
  required double tx,
  required double ty,
  required double scale,
  required ui.Size view,
  required ui.Size displayed,
  required int imageWidth,
  required int imageHeight,
  required double outputAspect,
}) {
  final bounds = ui.Rect.fromLTWH(
    0,
    0,
    imageWidth.toDouble(),
    imageHeight.toDouble(),
  );
  if (displayed.width < 1 || displayed.height < 1 || scale <= 0) {
    return _aspectInside(bounds, bounds, outputAspect);
  }
  final pixelX = imageWidth / displayed.width;
  final pixelY = imageHeight / displayed.height;
  final rect = ui.Rect.fromLTWH(
    -tx / scale * pixelX,
    -ty / scale * pixelY,
    view.width / scale * pixelX,
    view.height / scale * pixelY,
  );
  final fitted = _aspectInside(rect, bounds, outputAspect);
  if (fitted.width < 1 || fitted.height < 1) {
    return _aspectInside(bounds, bounds, outputAspect);
  }
  return fitted;
}

/// Draws [source] into a PNG of [width] by [height]. A square request is
/// rejected unless the encoded file is actually square.
Future<Uint8List> renderCropPng({
  required ui.Image image,
  required ui.Rect source,
  required int width,
  required int height,
}) async {
  if (width < 1 || height < 1 || source.width < 1 || source.height < 1) {
    throw StateError('The photo could not be cropped.');
  }
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawImageRect(
    image,
    source,
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final cropped = await recorder.endRecording().toImage(width, height);
  final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
  cropped.dispose();
  if (data == null) {
    throw StateError('The photo could not be cropped.');
  }
  final bytes = data.buffer.asUint8List();
  if (width == height && !pngSquare(bytes, width)) {
    throw StateError('The photo could not be cropped.');
  }
  return bytes;
}

/// True when the PNG header is [side] by [side].
bool pngSquare(Uint8List bytes, int side) {
  if (bytes.length < 24 || side < 1) {
    return false;
  }
  const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  for (var i = 0; i < sig.length; i++) {
    if (bytes[i] != sig[i]) {
      return false;
    }
  }
  final width = _be32(bytes, 16);
  final height = _be32(bytes, 20);
  return width == side && height == side;
}

ui.Rect _aspectInside(ui.Rect rect, ui.Rect bounds, double aspect) {
  if (bounds.width < 1 || bounds.height < 1 || aspect <= 0) {
    return bounds;
  }
  var width = rect.width < 1 ? bounds.width : rect.width;
  var height = rect.height < 1 ? bounds.height : rect.height;
  if (width / height > aspect) {
    width = height * aspect;
  } else {
    height = width / aspect;
  }
  if (width > bounds.width) {
    height = height * bounds.width / width;
    width = bounds.width;
  }
  if (height > bounds.height) {
    width = width * bounds.height / height;
    height = bounds.height;
  }
  final center = rect.width < 1 || rect.height < 1
      ? bounds.center
      : rect.center;
  final left = (center.dx - width / 2)
      .clamp(bounds.left, bounds.right - width)
      .toDouble();
  final top = (center.dy - height / 2)
      .clamp(bounds.top, bounds.bottom - height)
      .toDouble();
  return ui.Rect.fromLTWH(left, top, width, height);
}

int _be32(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}
