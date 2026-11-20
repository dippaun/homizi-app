import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/location/location_models.dart';
import 'package:homizi/core/location/place_autocomplete_field.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/office/office_location.dart';
import 'package:homizi/features/office/office_repository.dart';
import 'package:homizi/features/office/remember_office.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Office captured once. Later screens read [OfficeRepository.primary].
class SavedOfficeField extends ConsumerStatefulWidget {
  const SavedOfficeField({this.compact = false, super.key});

  /// Profile row: the saved workplace and Change office.
  final bool compact;

  @override
  ConsumerState<SavedOfficeField> createState() => _SavedOfficeFieldState();
}

class _SavedOfficeFieldState extends ConsumerState<SavedOfficeField> {
  final _place = TextEditingController();
  var _editing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _place.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      await ref.read(officeRepositoryProvider).load();
    } on Object {
      // The field stays empty when the store cannot be read.
    }
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _save(PlaceSuggestion place) async {
    await rememberWorkplace(ref, place);
    if (!mounted) {
      return;
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(officeRevisionProvider);
    final office = ref.watch(officeRepositoryProvider).primary;
    if (widget.compact) {
      return _compact(office);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          homiziText(context, 'Office'),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: HomiziColors.ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          homiziText(
            context,
            'Used everywhere commute is shown. You can change it from Profile.',
          ),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: HomiziColors.muted),
        ),
        const SizedBox(height: 8),
        if (office != null && !_editing)
          _saved(office)
        else
          PlaceAutocompleteField(
            controller: _place,
            fieldKey: const Key('registration-office'),
            labelText: homiziText(context, 'Office or workplace'),
            hintText: homiziText(context, 'Search your office'),
            prefixIcon: const Icon(
              Icons.apartment_outlined,
              color: HomiziColors.logoOrange,
            ),
            onSelected: (place) => unawaited(_save(place)),
          ),
      ],
    );
  }

  Widget _compact(OfficeLocation? office) {
    final label = office == null || office.label.trim().isEmpty
        ? homiziText(context, 'Add your office')
        : office.label.trim();
    return ListTile(
      key: const Key('profile-change-office'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.apartment_outlined,
        color: HomiziColors.logoOrange,
      ),
      title: Text(
        homiziText(context, 'Office'),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(label),
      trailing: TextButton(
        onPressed: () => unawaited(_open()),
        child: Text(
          homiziText(context, 'Change office'),
          style: const TextStyle(
            color: HomiziColors.logoOrange,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Future<void> _open() async {
    await context.push(RoutePaths.office);
    if (mounted) {
      await _load();
    }
  }

  Widget _saved(OfficeLocation office) {
    return Material(
      color: HomiziColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: HomiziColors.line),
      ),
      child: ListTile(
        key: const Key('registration-office-saved'),
        leading: const Icon(
          RealLifeIcons.office,
          color: HomiziColors.logoOrange,
        ),
        title: Text(office.label),
        subtitle: Text(
          homiziText(
            context,
            'Saved for commute. Change office lives in Profile.',
          ),
        ),
        trailing: IconButton(
          tooltip: homiziText(context, 'Change office'),
          onPressed: () => setState(() => _editing = true),
          icon: const Icon(Icons.edit_outlined),
        ),
      ),
    );
  }
}
