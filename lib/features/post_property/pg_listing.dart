import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';
import 'package:homizi/features/listings/listing_wizard_steps.dart';
import 'package:homizi/ui/kit/kit.dart';

/// Paying-guest answers stored as one JSON value on the existing
/// `wizard:pg` feature row. No new database column.
class PgListingDetails {
  const PgListingDetails({
    this.singlePrice = '',
    this.doublePrice = '',
    this.triplePrice = '',
    this.meals = false,
    this.gender = '',
    this.curfew = '',
    this.rules = '',
  });

  final String singlePrice;
  final String doublePrice;
  final String triplePrice;
  final bool meals;

  /// `boys`, `girls`, or `coliving`.
  final String gender;
  final String curfew;
  final String rules;

  bool get isEmpty =>
      singlePrice.trim().isEmpty &&
      doublePrice.trim().isEmpty &&
      triplePrice.trim().isEmpty &&
      !meals &&
      gender.trim().isEmpty &&
      curfew.trim().isEmpty &&
      rules.trim().isEmpty;

  String encode() {
    if (isEmpty) {
      return '';
    }
    return jsonEncode({
      'single': singlePrice.trim(),
      'double': doublePrice.trim(),
      'triple': triplePrice.trim(),
      'meals': meals,
      'gender': gender.trim(),
      'curfew': curfew.trim(),
      'rules': rules.trim(),
    });
  }

  static PgListingDetails decode(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const PgListingDetails();
    }
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        return const PgListingDetails();
      }
      String read(String key) {
        final value = decoded[key];
        return value is String ? value : '';
      }

      final gender = read('gender');
      return PgListingDetails(
        singlePrice: read('single'),
        doublePrice: read('double'),
        triplePrice: read('triple'),
        meals: decoded['meals'] == true,
        gender: gender == 'boys' || gender == 'girls' || gender == 'coliving'
            ? gender
            : '',
        curfew: read('curfew'),
        rules: read('rules'),
      );
    } on FormatException {
      return const PgListingDetails();
    }
  }

  PgListingDetails copyWith({
    String? singlePrice,
    String? doublePrice,
    String? triplePrice,
    bool? meals,
    String? gender,
    String? curfew,
    String? rules,
  }) {
    return PgListingDetails(
      singlePrice: singlePrice ?? this.singlePrice,
      doublePrice: doublePrice ?? this.doublePrice,
      triplePrice: triplePrice ?? this.triplePrice,
      meals: meals ?? this.meals,
      gender: gender ?? this.gender,
      curfew: curfew ?? this.curfew,
      rules: rules ?? this.rules,
    );
  }
}

/// Beds, meals, gender, curfew, rules, and amenities for a PG listing.
class PgListingFields extends StatefulWidget {
  const PgListingFields({
    required this.details,
    required this.amenities,
    required this.onChanged,
    required this.onAmenity,
    super.key,
  });

  final PgListingDetails details;
  final List<String> amenities;
  final ValueChanged<PgListingDetails> onChanged;
  final void Function(String key, bool selected) onAmenity;

  @override
  State<PgListingFields> createState() => _PgListingFieldsState();
}

class _PgListingFieldsState extends State<PgListingFields> {
  late final TextEditingController _single;
  late final TextEditingController _double;
  late final TextEditingController _triple;
  late final TextEditingController _curfew;
  late final TextEditingController _rules;
  late bool _meals;
  late String _gender;

  @override
  void initState() {
    super.initState();
    _meals = widget.details.meals;
    _gender = widget.details.gender;
    _single = TextEditingController(text: widget.details.singlePrice);
    _double = TextEditingController(text: widget.details.doublePrice);
    _triple = TextEditingController(text: widget.details.triplePrice);
    _curfew = TextEditingController(text: widget.details.curfew);
    _rules = TextEditingController(text: widget.details.rules);
  }

  @override
  void didUpdateWidget(PgListingFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    _meals = widget.details.meals;
    _gender = widget.details.gender;
    _assign(_single, widget.details.singlePrice);
    _assign(_double, widget.details.doublePrice);
    _assign(_triple, widget.details.triplePrice);
    _assign(_curfew, widget.details.curfew);
    _assign(_rules, widget.details.rules);
  }

  void _assign(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  @override
  void dispose() {
    _single.dispose();
    _double.dispose();
    _triple.dispose();
    _curfew.dispose();
    _rules.dispose();
    super.dispose();
  }

  void _emit(PgListingDetails next) => widget.onChanged(next);

  PgListingDetails _current() {
    return PgListingDetails(
      singlePrice: _single.text,
      doublePrice: _double.text,
      triplePrice: _triple.text,
      meals: _meals,
      gender: _gender,
      curfew: _curfew.text,
      rules: _rules.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('pg-listing-fields'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          homiziText(context, 'PG details'),
          style: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: HomiziColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          homiziText(
            context,
            'Sharing prices, meals, and house rules for this paying guest home.',
          ),
          style: const TextStyle(color: HomiziColors.inkSoft, height: 1.3),
        ),
        const SizedBox(height: 12),
        Text(homiziText(context, 'Beds & sharing')),
        const SizedBox(height: 8),
        _price('pg-single-price', _single, 'Single sharing (₹)'),
        _price('pg-double-price', _double, 'Double sharing (₹)'),
        _price('pg-triple-price', _triple, 'Triple sharing (₹)'),
        YesNoField(
          label: 'Meals included',
          value: _meals,
          yesKey: 'pg-meals-yes',
          noKey: 'pg-meals-no',
          icon: Icons.restaurant_outlined,
          onChanged: (value) {
            setState(() => _meals = value);
            _emit(_current());
          },
        ),
        const SizedBox(height: 8),
        Text(homiziText(context, 'Who can stay')),
        const SizedBox(height: 8),
        OptionGrid(
          children: [
            for (final item in const [
              ('boys', 'Boys', RealLifeIcons.man),
              ('girls', 'Girls', RealLifeIcons.woman),
              ('coliving', 'Co-living', RealLifeIcons.sharedRoom),
            ])
              OptionTile(
                key: Key('pg-gender-${item.$1}'),
                label: homiziText(context, item.$2),
                icon: item.$3,
                selected: _gender == item.$1,
                onTap: () {
                  setState(() => _gender = item.$1);
                  _emit(_current());
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('pg-curfew'),
          controller: _curfew,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _emit(_current()),
          decoration: listingFieldDecoration(
            context,
            'Curfew',
            Icons.nightlight_outlined,
            hint: '10:30 pm on weeknights',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('pg-rules'),
          controller: _rules,
          maxLines: 3,
          maxLength: 280,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => _emit(_current()),
          decoration: listingFieldDecoration(
            context,
            'Rules',
            Icons.rule_outlined,
            hint: 'No loud music after 10. Visitors leave by 9.',
          ),
        ),
        const SizedBox(height: 8),
        const _PgAmenityLabel(),
        const SizedBox(height: 8),
        OptionGrid(
          children: [
            for (final key in inFlatAmenityKeys)
              OptionTile(
                key: Key('pg-amenity-$key'),
                label: homiziText(context, listingAmenityLabel(key)),
                icon: switch (key) {
                  'wifi' => RealLifeIcons.wifi,
                  'fridge' => RealLifeIcons.fridge,
                  'ac' => RealLifeIcons.ac,
                  'washing_machine' => RealLifeIcons.laundry,
                  'gas_pipeline' => RealLifeIcons.cook,
                  _ => iconForChoice(listingAmenityLabel(key)),
                },
                selected: widget.amenities.contains(key),
                onTap: () =>
                    widget.onAmenity(key, !widget.amenities.contains(key)),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _price(String key, TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key(key),
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: const [WholeAmountFormatter()],
        onChanged: (_) => _emit(_current()),
        decoration: listingFieldDecoration(
          context,
          label,
          Icons.currency_rupee,
        ),
      ),
    );
  }
}

class _PgAmenityLabel extends StatelessWidget {
  const _PgAmenityLabel();

  @override
  Widget build(BuildContext context) {
    return Text(
      homiziText(context, 'Amenities'),
      style: const TextStyle(
        fontFamily: 'PlusJakartaSans',
        color: HomiziColors.ink,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
