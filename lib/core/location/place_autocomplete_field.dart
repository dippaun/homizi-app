import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/location/location_service.dart';
import 'package:homizi/core/theme/homizi_colors.dart';

/// Google Places search box shared by Office, Search Properties, and the
/// listing locality field.
///
/// Typing calls [onChanged] with the raw text. Picking a suggestion resolves
/// its coordinates (same session token as the autocomplete) and calls
/// [onSelected]. A failed lookup shows a retry row instead of an empty list.
/// With [manualOption], a "Use typed text" row appears when nothing matched
/// and the text is not already the [selected] place.
class PlaceAutocompleteField extends ConsumerStatefulWidget {
  const PlaceAutocompleteField({
    required this.controller,
    required this.onSelected,
    this.onChanged,
    this.fieldKey,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.biasPoint,
    this.selected,
    this.manualOption = false,
    this.manualSubtitle,
    this.busy = false,
    this.textCapitalization = TextCapitalization.none,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<PlaceSuggestion> onSelected;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;
  final String? hintText;
  final String? labelText;
  final Widget? prefixIcon;

  /// Bias suggestions around this point (current spot or the picked city).
  final GeoFix? biasPoint;

  /// The place currently chosen on the screen. Hides the manual row when it
  /// already matches the text and has coordinates or a place id.
  final PlaceSuggestion? selected;
  final bool manualOption;
  final String? manualSubtitle;

  /// The parent is busy (for example locating). Shows the spinner.
  final bool busy;
  final TextCapitalization textCapitalization;

  @override
  ConsumerState<PlaceAutocompleteField> createState() =>
      _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState
    extends ConsumerState<PlaceAutocompleteField> {
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const [];
  var _searching = false;
  var _failed = false;
  String? _session;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      unawaited(_lookup(value));
    });
    setState(() => _failed = false);
  }

  Future<void> _lookup(String value) async {
    final query = value.trim();
    _lastQuery = query;
    if (query.length < 2) {
      if (mounted) {
        setState(() {
          _suggestions = const [];
          _searching = false;
          _failed = false;
        });
      }
      return;
    }
    final service = ref.read(locationServiceProvider);
    if (!service.mapsEnabled) {
      return;
    }
    _session ??= newPlacesSessionToken();
    setState(() {
      _searching = true;
      _failed = false;
    });
    try {
      final places = await service.searchPlaces(
        query,
        near: widget.biasPoint,
        sessionToken: _session,
      );
      if (!mounted || widget.controller.text.trim() != query) {
        return;
      }
      setState(() => _suggestions = places);
    } on Object {
      if (!mounted || widget.controller.text.trim() != query) {
        return;
      }
      setState(() {
        _suggestions = const [];
        _failed = true;
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _choose(PlaceSuggestion suggestion) async {
    final session = _session;
    _session = null;
    setState(() => _searching = true);
    var resolved = suggestion;
    try {
      resolved = await ref
          .read(locationServiceProvider)
          .resolvePlace(suggestion, sessionToken: session);
    } on Object {
      resolved = suggestion;
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
    if (!mounted) {
      return;
    }
    widget.controller.value = TextEditingValue(
      text: resolved.label,
      selection: TextSelection.collapsed(offset: resolved.label.length),
    );
    setState(() {
      _suggestions = const [];
      _failed = false;
    });
    widget.onSelected(resolved);
  }

  bool get _textIsSelected {
    final place = widget.selected;
    if (place == null || place.manual) {
      return false;
    }
    final known = place.hasCoordinates || (place.placeId ?? '').isNotEmpty;
    return known && place.label.trim() == widget.controller.text.trim();
  }

  @override
  Widget build(BuildContext context) {
    final mapsEnabled = ref.watch(locationServiceProvider).mapsEnabled;
    final text = widget.controller.text.trim();
    final spinning = _searching || widget.busy;
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Its own semantics node: on the web a text field merged with the
          // surrounding card is rebuilt when suggestions appear, which wiped
          // the typed text.
          Semantics(
            container: true,
            child: TextField(
              key: widget.fieldKey,
              controller: widget.controller,
              textInputAction: TextInputAction.search,
              textCapitalization: widget.textCapitalization,
              decoration: InputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                prefixIcon: widget.prefixIcon,
                suffixIcon: spinning
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _onChanged,
            ),
          ),
          if (_failed)
            ListTile(
              key: const Key('place-suggestions-error'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.wifi_off, color: HomiziColors.error),
              title: const Text("Couldn't load suggestions"),
              trailing: TextButton(
                key: const Key('place-suggestions-retry'),
                onPressed: () => unawaited(_lookup(widget.controller.text)),
                child: const Text('Retry'),
              ),
            )
          else if (_suggestions.isNotEmpty && text == _lastQuery)
            for (var index = 0; index < _suggestions.length; index++)
              ListTile(
                key: Key('place-suggestion-$index'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.place_outlined,
                  color: HomiziColors.logoOrange,
                ),
                title: Text(_suggestions[index].label),
                onTap: () => unawaited(_choose(_suggestions[index])),
              )
          else if (widget.manualOption &&
              text.length >= 2 &&
              !spinning &&
              !_textIsSelected)
            ListTile(
              key: const Key('office-use-typed'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('Use "$text"'),
              subtitle: Text(
                widget.manualSubtitle ??
                    (mapsEnabled
                        ? 'No place match. This address is saved as typed.'
                        : 'Saved as typed. Distance unavailable.'),
              ),
              onTap: () =>
                  widget.onSelected(PlaceSuggestion(label: text, manual: true)),
            ),
        ],
      ),
    );
  }
}
