import 'package:flutter/material.dart';
import 'package:homizi/core/brand/homizi_mark.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/listings/domain/photo_caption.dart';

/// Full-bleed hero, thumbnail strip, and the full-screen gallery it opens.
class ListingDetailGallery extends StatefulWidget {
  const ListingDetailGallery({
    required this.assets,
    required this.labels,
    required this.heroTag,
    required this.verified,
    required this.saved,
    required this.onSave,
    required this.onShare,
    required this.onReport,
    super.key,
  });

  final List<String> assets;
  final List<String> labels;
  final String heroTag;
  final bool verified;
  final bool saved;
  final VoidCallback? onSave;
  final VoidCallback onShare;
  final VoidCallback onReport;

  @override
  State<ListingDetailGallery> createState() => _ListingDetailGalleryState();
}

class _ListingDetailGalleryState extends State<ListingDetailGallery> {
  late final PageController _page;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _page = PageController();
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  List<String> get _photos =>
      widget.assets.isEmpty ? const <String>[] : widget.assets;

  String _labelAt(int index) {
    if (index < widget.labels.length &&
        widget.labels[index].trim().isNotEmpty) {
      return widget.labels[index].trim();
    }
    if (index < widget.assets.length) {
      return photoSemanticsLabel(
        roomLabel: roomLabelForAsset(widget.assets[index]),
      );
    }
    return 'Photo';
  }

  void _go(int index) {
    if (index < 0 || index >= _photos.length) {
      return;
    }
    if (!_page.hasClients) {
      return;
    }
    _page.jumpToPage(index);
  }

  void _open() {
    if (_photos.isEmpty) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ListingPhotoGalleryPage(
          assets: _photos,
          labels: [for (var i = 0; i < _photos.length; i++) _labelAt(i)],
          initialIndex: _index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = _photos;
    final height = MediaQuery.sizeOf(context).height;
    final heroHeight = (height * 0.42).clamp(280, 460).toDouble();
    final route = ModalRoute.of(context);
    final current = route == null || route.isCurrent;
    final hero = SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            const PhotoShimmer()
          else
            GestureDetector(
              key: const Key('listing-hero'),
              onTap: _open,
              child: PageView.builder(
                controller: _page,
                itemCount: photos.length,
                onPageChanged: (index) => setState(() => _index = index),
                itemBuilder: (context, index) {
                  return ListingPhoto(
                    asset: photos[index],
                    semanticLabel: _labelAt(index),
                  );
                },
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _overlay(context),
                  if (widget.verified) ...[
                    const SizedBox(height: 10),
                    const _VerifiedPropertyBadge(),
                  ],
                ],
              ),
            ),
          ),
          if (photos.isNotEmpty)
            Positioned(
              right: 16,
              bottom: 16,
              child: _Counter(index: _index, total: photos.length),
            ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HeroMode(
          enabled: current && TickerMode.valuesOf(context).enabled,
          child: Hero(tag: widget.heroTag, child: hero),
        ),
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 72,
            child: ListView.separated(
              key: const Key('listing-thumb-strip'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: photos.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = index == _index;
                return GestureDetector(
                  key: Key('listing-thumb-$index'),
                  onTap: () => _go(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? HomiziColors.logoOrange
                            : HomiziColors.line,
                        width: selected ? 2.5 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: ListingPhoto(asset: photos[index]),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              homiziText(context, _labelAt(_index)),
              key: Key('listing-gallery-caption-$_index'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: HomiziColors.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _overlay(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const IgnorePointer(child: _LogoChip()),
          Row(
            children: [
              const _RoundBack(),
              const Spacer(),
              _RoundIconButton(
                key: const Key('listing-hero-save'),
                tooltip: widget.saved ? 'Remove save' : 'Save',
                icon: widget.saved ? Icons.favorite : Icons.favorite_border,
                color: HomiziColors.logoOrange,
                onPressed: widget.onSave,
              ),
              const SizedBox(width: 8),
              _RoundIconButton(
                key: const Key('listing-share'),
                tooltip: 'Share',
                icon: Icons.share_outlined,
                onPressed: widget.onShare,
              ),
              const SizedBox(width: 8),
              _ReportMenu(onReport: widget.onReport),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogoChip extends StatelessWidget {
  const _LogoChip();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: HomiziColors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Padding(
        padding: EdgeInsets.all(4),
        child: HomiziLogo(size: 28),
      ),
    );
  }
}

class _RoundBack extends StatelessWidget {
  const _RoundBack();

  @override
  Widget build(BuildContext context) {
    if (!TickerMode.valuesOf(context).enabled) {
      return const SizedBox.shrink();
    }
    final route = ModalRoute.of(context);
    if (route != null && !route.isCurrent) {
      return const SizedBox.shrink();
    }
    return _RoundIconButton(
      key: const Key('listing-back'),
      tooltip: 'Back',
      icon: Icons.arrow_back,
      onPressed: () => HomiziBackButton.leave(context),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.color = HomiziColors.ink,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: homiziText(context, tooltip),
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: HomiziColors.white,
        foregroundColor: color,
        fixedSize: const Size(40, 40),
        minimumSize: const Size(40, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 20, color: color),
    );
  }
}

class _ReportMenu extends StatelessWidget {
  const _ReportMenu({required this.onReport});

  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HomiziColors.white,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: PopupMenuButton<String>(
        key: const Key('listing-more'),
        tooltip: homiziText(context, 'More'),
        padding: EdgeInsets.zero,
        color: HomiziColors.white,
        onSelected: (value) {
          if (value == 'report') {
            onReport();
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem<String>(
            value: 'report',
            child: Text(
              homiziText(context, 'Report'),
              key: const Key('listing-report'),
              style: const TextStyle(color: HomiziColors.ink),
            ),
          ),
        ],
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.more_horiz, color: HomiziColors.ink, size: 22),
        ),
      ),
    );
  }
}

class _VerifiedPropertyBadge extends StatelessWidget {
  const _VerifiedPropertyBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('listing-verified-property'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: HomiziColors.success,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 16, color: HomiziColors.onSuccess),
          const SizedBox(width: 6),
          Text(
            homiziText(context, 'Verified Property'),
            style: const TextStyle(
              color: HomiziColors.onSuccess,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('listing-photo-counter'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: HomiziColors.night,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${index + 1}/$total',
        style: const TextStyle(
          color: HomiziColors.white,
          fontWeight: FontWeight.w800,
          fontSize: 13,
        ),
      ),
    );
  }
}

/// Full-screen swipe of the same photos. One back button.
class ListingPhotoGalleryPage extends StatefulWidget {
  const ListingPhotoGalleryPage({
    required this.assets,
    required this.labels,
    required this.initialIndex,
    super.key,
  });

  final List<String> assets;
  final List<String> labels;
  final int initialIndex;

  @override
  State<ListingPhotoGalleryPage> createState() =>
      _ListingPhotoGalleryPageState();
}

class _ListingPhotoGalleryPageState extends State<ListingPhotoGalleryPage> {
  late final PageController _page;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.assets.length - 1);
    _page = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = _index < widget.labels.length
        ? widget.labels[_index]
        : 'Photo';
    return Scaffold(
      key: const Key('listing-gallery'),
      backgroundColor: HomiziColors.night,
      body: Stack(
        children: [
          PageView.builder(
            controller: _page,
            itemCount: widget.assets.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              return ListingPhoto(
                asset: widget.assets[index],
                semanticLabel: index < widget.labels.length
                    ? widget.labels[index]
                    : 'Photo',
              );
            },
          ),
          Positioned(
            left: 12,
            top: 0,
            child: SafeArea(
              child: _RoundIconButton(
                tooltip: 'Back',
                icon: Icons.arrow_back,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ColoredBox(
              color: HomiziColors.white,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          homiziText(context, label),
                          style: const TextStyle(
                            color: HomiziColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${_index + 1}/${widget.assets.length}',
                        style: const TextStyle(
                          color: HomiziColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
