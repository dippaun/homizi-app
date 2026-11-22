import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/location_providers.dart';
import 'package:homizi/core/location/location_service.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/ui/kit/kit_field.dart';

/// Best catalogue city for typed text, including a short typo.
///
/// "ahmedbad" matches Ahmedabad (one missing letter). A match needs the
/// names to be equal, one to contain the other, or at most two edits.
PlaceSuggestion? closestCatalogPlace(
  String typed,
  List<PlaceSuggestion> places,
) {
  final query = typed.trim().toLowerCase();
  if (query.length < 2 || places.isEmpty) {
    return null;
  }
  PlaceSuggestion? nearest;
  var nearestEdits = 3;
  for (final place in places) {
    final name = place.label.trim().toLowerCase();
    if (name.isEmpty) {
      continue;
    }
    if (name == query || name.startsWith(query) || name.contains(query)) {
      return place;
    }
    if (query.startsWith(name) || query.contains(name)) {
      return place;
    }
    final edits = _placeEdits(query, name);
    if (edits < nearestEdits) {
      nearestEdits = edits;
      nearest = place;
    }
  }
  return nearest;
}

int _placeEdits(String left, String right) {
  if ((left.length - right.length).abs() > 2) {
    return 3;
  }
  final rows = List<int>.generate(right.length + 1, (index) => index);
  for (var i = 1; i <= left.length; i++) {
    var previous = rows[0];
    rows[0] = i;
    for (var j = 1; j <= right.length; j++) {
      final current = rows[j];
      final cost = left.codeUnitAt(i - 1) == right.codeUnitAt(j - 1) ? 0 : 1;
      final insert = rows[j] + 1;
      final delete = rows[j - 1] + 1;
      final replace = previous + cost;
      rows[j] = insert < delete
          ? (insert < replace ? insert : replace)
          : (delete < replace ? delete : replace);
      previous = current;
    }
  }
  return rows[right.length];
}

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
    this.nearbyLocalities = const [],
    this.selected,
    this.manualOption = false,
    this.manualSubtitle,
    this.busy = false,
    this.textCapitalization = TextCapitalization.none,
    this.helperText,
    this.includedPrimaryTypes = const [],
    this.commitLabel = true,
    this.stackedLabel = false,
    this.pickOnly = false,
    this.biasRadiusMeters,
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

  /// Localities already known to Homizi. Shown while typing, together with
  /// Google suggestions when a maps key is present.
  final List<PlaceSuggestion> nearbyLocalities;

  /// The place currently chosen on the screen. Hides the manual row when it
  /// already matches the text and has coordinates or a place id.
  final PlaceSuggestion? selected;
  final bool manualOption;
  final String? manualSubtitle;

  /// The parent is busy (for example locating). Shows the spinner.
  final bool busy;
  final TextCapitalization textCapitalization;
  final String? helperText;

  /// Places API (New) primary types, for example `establishment` on a tower.
  final List<String> includedPrimaryTypes;

  /// When false, a pick calls [onSelected] and leaves the typed text alone.
  /// Chip fields use that so the query box can clear itself.
  final bool commitLabel;

  /// Draws [labelText] above the box instead of as a floating label.
  final bool stackedLabel;

  /// A place is saved only when a suggestion is chosen. Typed text snaps
  /// back to the last picked label when the field loses focus.
  final bool pickOnly;

  /// Override the autocomplete bias circle. City search uses a wide one.
  final double? biasRadiusMeters;

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
  late String _committed;
  final _focus = FocusNode();
  var _picking = false;

  @override
  void initState() {
    super.initState();
    _committed = widget.controller.text;
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (_focus.hasFocus || !widget.pickOnly || !mounted) {
      return;
    }
    // A suggestion tap blurs the field before the tile's tap lands, which
    // used to wipe the list. Wait so the pick can commit first.
    Future<void>.delayed(const Duration(milliseconds: 280), () {
      if (!mounted || _focus.hasFocus || _picking) {
        return;
      }
      final typed = widget.controller.text.trim();
      if (typed.isEmpty || typed == _committed.trim()) {
        return;
      }
      unawaited(_commitTyped(typed));
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.removeListener(_onFocus);
    _focus.dispose();
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
      if (mounted) {
        setState(() {
          _suggestions = const [];
          _searching = false;
          _failed = false;
          _lastQuery = query;
        });
      }
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
        includedPrimaryTypes: widget.includedPrimaryTypes,
        biasRadiusMeters: widget.biasRadiusMeters,
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

  /// A typed city is kept when it matches Places or the catalogue, including
  /// a one- or two-letter typo such as "ahmedbad".
  Future<void> _commitTyped(String typed) async {
    if ((_debounce?.isActive ?? false) || _suggestions.isEmpty) {
      _debounce?.cancel();
      await _lookup(typed);
    }
    if (!mounted || _picking || widget.controller.text.trim() != typed) {
      return;
    }
    final local = _localMatches(typed);
    final catalog = closestCatalogPlace(typed, widget.nearbyLocalities);
    final best = _suggestions.isNotEmpty
        ? _suggestions.first
        : (local.isNotEmpty ? local.first : catalog);
    if (best != null) {
      await _choose(best);
      return;
    }
    widget.controller.value = TextEditingValue(
      text: _committed,
      selection: TextSelection.collapsed(offset: _committed.length),
    );
  }

  Future<void> _choose(PlaceSuggestion suggestion) async {
    _picking = true;
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
    if (widget.commitLabel) {
      widget.controller.value = TextEditingValue(
        text: resolved.label,
        selection: TextSelection.collapsed(offset: resolved.label.length),
      );
    }
    setState(() {
      _suggestions = const [];
      _failed = false;
    });
    widget.onSelected(resolved);
    _committed = widget.controller.text;
    _picking = false;
  }

  List<PlaceSuggestion> _localMatches(String text) {
    final query = text.trim().toLowerCase();
    if (query.length < 2) {
      return const [];
    }
    final google = {
      for (final place in _suggestions) place.label.trim().toLowerCase(),
    };
    final matches = <PlaceSuggestion>[];
    for (final place in widget.nearbyLocalities) {
      final label = place.label.trim();
      if (label.isEmpty) {
        continue;
      }
      final haystack = [
        label,
        place.locality ?? '',
        place.city ?? '',
      ].join(' ').toLowerCase();
      if (!haystack.contains(query) || google.contains(label.toLowerCase())) {
        continue;
      }
      matches.add(place);
      if (matches.length == 6) {
        break;
      }
    }
    return matches;
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
    final settled =
        widget.pickOnly && text.isNotEmpty && text == _committed.trim();
    final local = settled ? const <PlaceSuggestion>[] : _localMatches(text);
    final stacked = widget.stackedLabel;
    final label = widget.labelText;
    final spinner = spinning
        ? const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : null;
    return Semantics(
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stacked && label != null) ...[
            Text(homiziText(context, label), style: kitFieldLabelStyle),
            const SizedBox(height: 6),
          ],
          // Its own semantics node: on the web a text field merged with the
          // surrounding card is rebuilt when suggestions appear, which wiped
          // the typed text.
          Semantics(
            container: true,
            child: TextField(
              key: widget.fieldKey,
              controller: widget.controller,
              focusNode: _focus,
              textInputAction: TextInputAction.search,
              textCapitalization: widget.textCapitalization,
              style: const TextStyle(color: HomiziColors.ink, fontSize: 16),
              cursorColor: HomiziColors.logoOrange,
              decoration: stacked
                  ? kitInputDecoration(
                      hint: widget.hintText,
                      helper: widget.pickOnly
                          ? (widget.helperText ??
                                (widget.controller.text.trim().isEmpty
                                    ? 'Type a city, then leave the field. The closest place is saved.'
                                    : 'Saved. Type a new city to change it.'))
                          : widget.helperText,
                      prefixIcon: widget.prefixIcon,
                      suffixIcon: spinner,
                    )
                  : InputDecoration(
                      labelText: label,
                      hintText: widget.hintText,
                      helperText: widget.helperText,
                      prefixIcon: widget.prefixIcon,
                      suffixIcon: spinner,
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
          else if (!settled && _suggestions.isNotEmpty && text == _lastQuery)
            for (var index = 0; index < _suggestions.length; index++)
              Material(
                color: HomiziColors.white,
                child: ListTile(
                  key: Key('place-suggestion-$index'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.place_outlined,
                    color: HomiziColors.logoOrange,
                  ),
                  title: Text(_suggestions[index].label),
                  onTap: () {
                    _picking = true;
                    unawaited(_choose(_suggestions[index]));
                  },
                ),
              ),
          for (var index = 0; index < local.length; index++)
            Material(
              color: HomiziColors.white,
              child: ListTile(
                key: Key('locality-suggestion-$index'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.near_me_outlined,
                  color: HomiziColors.ink,
                ),
                title: Text(local[index].label),
                subtitle: const Text('Nearby locality'),
                onTap: () {
                  _picking = true;
                  unawaited(_choose(local[index]));
                },
              ),
            ),
          if (!_failed &&
              !widget.pickOnly &&
              _suggestions.isEmpty &&
              local.isEmpty &&
              widget.manualOption &&
              text.length >= 2 &&
              !spinning &&
              !_textIsSelected)
            Material(
              color: HomiziColors.white,
              child: ListTile(
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
                onTap: () => widget.onSelected(
                  PlaceSuggestion(label: text, manual: true),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
