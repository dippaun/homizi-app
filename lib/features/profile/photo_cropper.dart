import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/profile/square_crop.dart';
import 'package:homizi/ui/kit/sticky_cta.dart';

/// Tappable frame. The label is the chip; the user never types a ratio.
enum PhotoAspectPreset {
  square(1, 1, '1:1'),
  portrait(4, 5, '4:5'),
  wide(16, 9, '16:9');

  const PhotoAspectPreset(this.widthUnits, this.heightUnits, this.label);

  final int widthUnits;
  final int heightUnits;
  final String label;

  double get ratio => widthUnits / heightUnits;

  bool get isSquare => widthUnits == heightUnits;
}

/// Bytes from the crop sheet, or a signal that the file could not be read.
class FramedPhoto {
  const FramedPhoto({
    required this.bytes,
    required this.cropped,
    required this.unreadable,
  });

  const FramedPhoto.cancelled()
    : bytes = null,
      cropped = false,
      unreadable = false;

  final Uint8List? bytes;

  /// True when [bytes] is a new PNG of the framed region.
  final bool cropped;

  final bool unreadable;
}

/// Full-screen crop sheet. Drag and pinch move the photo under a fixed mask.
/// Scroll and the slider zoom on desktop web. Cancel leaves the photo unchanged.
Future<FramedPhoto> framePhoto({
  required BuildContext context,
  required Uint8List bytes,
  required List<PhotoAspectPreset> aspects,
  PhotoAspectPreset? initial,
  bool circular = false,
  int? maxBytes,
  bool keepOriginalIfUnreadable = false,
  Key? saveKey,
}) async {
  assert(aspects.isNotEmpty, 'A crop needs at least one aspect.');
  final decoded = await decodeUiImage(bytes);
  if (!context.mounted) {
    decoded?.dispose();
    return const FramedPhoto.cancelled();
  }
  if (decoded == null) {
    if (keepOriginalIfUnreadable) {
      return FramedPhoto(bytes: bytes, cropped: false, unreadable: true);
    }
    return const FramedPhoto(bytes: null, cropped: false, unreadable: true);
  }
  final preset = initial != null && aspects.contains(initial)
      ? initial
      : aspects.first;
  final cropped = await showModalBottomSheet<Uint8List>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    useRootNavigator: true,
    backgroundColor: HomiziColors.white,
    builder: (sheetContext) {
      final height = MediaQuery.sizeOf(sheetContext).height;
      return SizedBox(
        height: height,
        child: _PhotoCropSheet(
          decoded: decoded,
          aspects: aspects,
          initial: preset,
          circular: circular,
          maxBytes: maxBytes,
          saveKey: saveKey ?? const Key('photo-crop-save'),
        ),
      );
    },
  );
  if (cropped == null) {
    return const FramedPhoto.cancelled();
  }
  return FramedPhoto(bytes: cropped, cropped: true, unreadable: false);
}

class _PhotoCropSheet extends StatefulWidget {
  const _PhotoCropSheet({
    required this.decoded,
    required this.aspects,
    required this.initial,
    required this.circular,
    required this.saveKey,
    this.maxBytes,
  });

  final DecodedPhoto decoded;
  final List<PhotoAspectPreset> aspects;
  final PhotoAspectPreset initial;
  final bool circular;
  final int? maxBytes;
  final Key saveKey;

  ui.Image get image => decoded.image;

  @override
  State<_PhotoCropSheet> createState() => _PhotoCropSheetState();
}

class _PhotoCropSheetState extends State<_PhotoCropSheet> {
  late PhotoAspectPreset _aspect = widget.initial;
  Size? _viewSize;
  Size? _baseSize;
  var _coverRefreshScheduled = false;
  var _scale = 1.0;
  var _tx = 0.0;
  var _ty = 0.0;
  var _showGrid = false;
  var _saving = false;
  var _gesturing = false;
  Timer? _gridTimer;
  var _originScale = 1.0;
  var _originTx = 0.0;
  var _originTy = 0.0;
  var _originFocal = Offset.zero;
  var _imageDisposed = false;

  @override
  void dispose() {
    _gridTimer?.cancel();
    if (!_imageDisposed) {
      widget.decoded.dispose();
      _imageDisposed = true;
    }
    super.dispose();
  }

  void _applyCover() {
    final view = _viewSize;
    final base = _baseSize;
    if (view == null || base == null) {
      return;
    }
    _scale = 1;
    _tx = (view.width - base.width) / 2;
    _ty = (view.height - base.height) / 2;
  }

  void _clampOffset() {
    final view = _viewSize;
    final base = _baseSize;
    if (view == null || base == null) {
      return;
    }
    final shownWidth = base.width * _scale;
    final shownHeight = base.height * _scale;
    final minX = math.min(0.0, view.width - shownWidth);
    final minY = math.min(0.0, view.height - shownHeight);
    _tx = _tx.clamp(minX, 0.0).toDouble();
    _ty = _ty.clamp(minY, 0.0).toDouble();
  }

  void _zoomAt(double nextScale, Offset focal) {
    final current = _scale <= 0 ? 1.0 : _scale;
    final clamped = nextScale.clamp(1.0, 4.0).toDouble();
    final imageX = (focal.dx - _tx) / current;
    final imageY = (focal.dy - _ty) / current;
    _scale = clamped;
    _tx = focal.dx - imageX * clamped;
    _ty = focal.dy - imageY * clamped;
    _clampOffset();
  }

  void _onStart(ScaleStartDetails details) {
    _gridTimer?.cancel();
    _originScale = _scale;
    _originTx = _tx;
    _originTy = _ty;
    _originFocal = details.localFocalPoint;
    setState(() {
      _gesturing = true;
      _showGrid = true;
    });
  }

  void _onUpdate(ScaleUpdateDetails details) {
    final nextScale = (_originScale * details.scale).clamp(1.0, 4.0).toDouble();
    final imageX = (_originFocal.dx - _originTx) / _originScale;
    final imageY = (_originFocal.dy - _originTy) / _originScale;
    final focal = details.localFocalPoint;
    setState(() {
      _scale = nextScale;
      _tx = focal.dx - imageX * nextScale;
      _ty = focal.dy - imageY * nextScale;
      _clampOffset();
    });
  }

  void _onEnd(ScaleEndDetails _) {
    setState(() {
      _gesturing = false;
      _showGrid = false;
    });
  }

  void _onSignal(PointerSignalEvent event) {
    if (_saving || event is! PointerScrollEvent || event.scrollDelta.dy == 0) {
      return;
    }
    final view = _viewSize;
    if (view == null) {
      return;
    }
    setState(() {
      _zoomAt(
        _scale * math.exp(-event.scrollDelta.dy / 280),
        event.localPosition,
      );
      _showGrid = true;
    });
    _scheduleGridHide();
  }

  void _scheduleGridHide() {
    _gridTimer?.cancel();
    _gridTimer = Timer(const Duration(milliseconds: 450), () {
      if (!mounted || _gesturing) {
        return;
      }
      setState(() => _showGrid = false);
    });
  }

  void _reset() {
    if (_saving) {
      return;
    }
    _gridTimer?.cancel();
    setState(() {
      _showGrid = false;
      _applyCover();
    });
  }

  void _select(PhotoAspectPreset aspect) {
    if (_saving || aspect == _aspect) {
      return;
    }
    setState(() {
      _aspect = aspect;
      _viewSize = null;
      _baseSize = null;
    });
  }

  Future<void> _save() async {
    if (_saving || _viewSize == null || _baseSize == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final bytes = await _export();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(bytes);
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(homiziText(context, 'The photo could not be cropped.')),
        ),
      );
    }
  }

  Future<Uint8List> _export() async {
    final view = _viewSize!;
    final base = _baseSize!;
    final source = cropSourceRect(
      tx: _tx,
      ty: _ty,
      scale: _scale,
      view: view,
      displayed: base,
      imageWidth: widget.image.width,
      imageHeight: widget.image.height,
      outputAspect: _aspect.ratio,
    );
    var longSide = cropExportLongSide;
    final floor = widget.maxBytes == null
        ? longSide
        : minimumCropLongSide(
            aspectWidth: _aspect.widthUnits,
            aspectHeight: _aspect.heightUnits,
          );
    while (true) {
      final size = cropOutputSize(
        aspectWidth: _aspect.widthUnits,
        aspectHeight: _aspect.heightUnits,
        longSide: longSide,
      );
      final png = await renderCropPng(
        image: widget.image,
        source: source,
        width: size.$1,
        height: size.$2,
      );
      final limit = widget.maxBytes;
      if (limit == null || png.length <= limit || longSide <= floor) {
        return png;
      }
      final reduced = math.max(floor, (longSide * 0.85).round());
      if (reduced == longSide) {
        return png;
      }
      longSide = reduced;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        key: const Key('photo-crop-sheet'),
        backgroundColor: HomiziColors.white,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: SizedBox(
                height: 48,
                child: Row(
                  children: [
                    TextButton(
                      key: const Key('photo-crop-cancel'),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(homiziText(context, 'Cancel')),
                    ),
                    const Spacer(),
                    TextButton(
                      key: const Key('photo-crop-reset'),
                      onPressed: _saving ? null : _reset,
                      child: Text(homiziText(context, 'Reset')),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return _stage(constraints.biggest);
                  },
                ),
              ),
            ),
            if (widget.aspects.length > 1) _aspectChips(context),
            _zoom(context),
          ],
        ),
        bottomNavigationBar: StickyCta(
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: widget.saveKey,
              onPressed: _saving || _viewSize == null
                  ? null
                  : () => unawaited(_save()),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: HomiziColors.ink,
                      ),
                    )
                  : Text(homiziText(context, 'Save photo')),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stage(Size space) {
    final view = _cropWindow(space, _aspect.ratio);
    if (view.width < 2 || view.height < 2) {
      return const ColoredBox(color: HomiziColors.night);
    }
    final base = _coverSize(widget.image, view);
    if (_viewSize != view || _baseSize != base) {
      _viewSize = view;
      _baseSize = base;
      _scale = 1;
      _tx = (view.width - base.width) / 2;
      _ty = (view.height - base.height) / 2;
      if (!_coverRefreshScheduled) {
        _coverRefreshScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _coverRefreshScheduled = false;
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
    return ColoredBox(
      color: HomiziColors.night,
      child: Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: Listener(
            onPointerSignal: _onSignal,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _saving ? null : _onStart,
              onScaleUpdate: _saving ? null : _onUpdate,
              onScaleEnd: _saving ? null : _onEnd,
              child: ClipRect(
                child: SizedBox(
                  width: view.width,
                  height: view.height,
                  child: Stack(
                    children: [
                      Positioned(
                        left: _tx,
                        top: _ty,
                        width: base.width * _scale,
                        height: base.height * _scale,
                        child: RawImage(image: widget.image, fit: BoxFit.fill),
                      ),
                      if (widget.circular)
                        const IgnorePointer(
                          child: CustomPaint(
                            painter: _CircleMaskPainter(),
                            child: SizedBox.expand(),
                          ),
                        )
                      else
                        const IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.fromBorderSide(
                                BorderSide(color: HomiziColors.white, width: 2),
                              ),
                            ),
                            child: SizedBox.expand(),
                          ),
                        ),
                      if (_showGrid)
                        IgnorePointer(
                          child: widget.circular
                              ? const ClipOval(
                                  child: CustomPaint(
                                    painter: _ThirdsGridPainter(),
                                    child: SizedBox.expand(),
                                  ),
                                )
                              : const CustomPaint(
                                  painter: _ThirdsGridPainter(),
                                  child: SizedBox.expand(),
                                ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _aspectChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final aspect in widget.aspects)
            ChoiceChip(
              key: Key('photo-crop-aspect-${aspect.name}'),
              label: Text(aspect.label),
              selected: aspect == _aspect,
              showCheckmark: false,
              onSelected: _saving ? null : (_) => _select(aspect),
              selectedColor: HomiziColors.logoOrange.withValues(alpha: 0.10),
              backgroundColor: HomiziColors.white,
              labelStyle: const TextStyle(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w700,
              ),
              side: BorderSide(
                color: aspect == _aspect
                    ? HomiziColors.logoOrange
                    : HomiziColors.line,
                width: aspect == _aspect ? 1.5 : 1,
              ),
            ),
        ],
      ),
    );
  }

  Widget _zoom(BuildContext context) {
    final view = _viewSize;
    return Semantics(
      label: homiziText(context, 'Zoom'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
        child: Row(
          children: [
            const Icon(Icons.zoom_out, color: HomiziColors.ink),
            Expanded(
              child: Slider(
                key: const Key('photo-crop-zoom'),
                value: _scale.clamp(1.0, 4.0).toDouble(),
                min: 1,
                max: 4,
                activeColor: HomiziColors.logoOrange,
                onChangeStart: _saving
                    ? null
                    : (_) {
                        _gridTimer?.cancel();
                        setState(() => _showGrid = true);
                      },
                onChanged: _saving || view == null
                    ? null
                    : (value) {
                        setState(() {
                          _zoomAt(
                            value,
                            Offset(view.width / 2, view.height / 2),
                          );
                        });
                      },
                onChangeEnd: _saving
                    ? null
                    : (_) => setState(() => _showGrid = false),
              ),
            ),
            const Icon(Icons.zoom_in, color: HomiziColors.ink),
          ],
        ),
      ),
    );
  }
}

Size _cropWindow(Size space, double ratio) {
  var maxWidth = space.width;
  final maxHeight = space.height;
  if (maxWidth > 560) {
    maxWidth = 560;
  }
  if (maxWidth < 2 || maxHeight < 2 || ratio <= 0) {
    return Size.zero;
  }
  if (maxWidth / maxHeight > ratio) {
    final height = maxHeight;
    return Size(height * ratio, height);
  }
  return Size(maxWidth, maxWidth / ratio);
}

Size _coverSize(ui.Image image, Size view) {
  final imageAspect = image.width / image.height;
  final viewAspect = view.width / view.height;
  if (imageAspect > viewAspect) {
    final height = view.height;
    return Size(height * imageAspect, height);
  }
  final width = view.width;
  return Size(width, width / imageAspect);
}

class _CircleMaskPainter extends CustomPainter {
  const _CircleMaskPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final shade = Path()
      ..addRect(bounds)
      ..addOval(bounds)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      shade,
      Paint()..color = HomiziColors.night.withValues(alpha: 0.55),
    );
    canvas.drawOval(
      bounds.deflate(1),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = HomiziColors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleMaskPainter oldDelegate) => false;
}

class _ThirdsGridPainter extends CustomPainter {
  const _ThirdsGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = HomiziColors.white.withValues(alpha: 0.9)
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final dx = size.width * i / 3;
      final dy = size.height * i / 3;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), paint);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ThirdsGridPainter oldDelegate) => false;
}
