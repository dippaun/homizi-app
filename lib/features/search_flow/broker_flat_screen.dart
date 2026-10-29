import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:homizi/core/l10n/translate.dart';
import 'package:homizi/core/routing/route_paths.dart';
import 'package:homizi/core/theme/homizi_colors.dart';
import 'package:homizi/core/widgets/homizi_back.dart';
import 'package:homizi/features/discovery/data/locality_seed.dart';
import 'package:homizi/features/listings/domain/listing_wizard.dart';
import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/search_flow/flow_prefs.dart';

/// Broker flat details: location, price, amenities, images, and other notes.
///
/// The eight-step listing wizard stays available for a full post.
class BrokerFlatScreen extends ConsumerStatefulWidget {
  const BrokerFlatScreen({super.key});

  @override
  ConsumerState<BrokerFlatScreen> createState() => _BrokerFlatScreenState();
}

class _BrokerFlatScreenState extends ConsumerState<BrokerFlatScreen> {
  late final TextEditingController _locality;
  late final TextEditingController _price;
  late final TextEditingController _other;
  late String _city;
  late Set<String> _amenities;
  String? _error;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(flowPrefsProvider);
    _city = prefs.brokerCity;
    _locality = TextEditingController(text: prefs.brokerLocality);
    _price = TextEditingController(text: '${prefs.brokerPrice}');
    _other = TextEditingController(text: prefs.brokerOther);
    _amenities = {...prefs.brokerAmenities};
  }

  @override
  void dispose() {
    _locality.dispose();
    _price.dispose();
    _other.dispose();
    super.dispose();
  }

  void _match() {
    final price = int.tryParse(_price.text.replaceAll(RegExp('[^0-9]'), ''));
    final locality = _locality.text.trim();
    if (price == null || price <= 0 || locality.isEmpty) {
      setState(() => _error = 'Add a locality and a monthly rent.');
      return;
    }
    ref.read(flowPrefsProvider.notifier).update(
      ref.read(flowPrefsProvider).copyWith(
        brokerCity: _city,
        brokerLocality: locality,
        brokerPrice: price,
        brokerAmenities: _amenities.toList(),
        brokerOther: _other.text.trim(),
      ),
    );
    context.push('${RoutePaths.flowSwipe}?deck=broker');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('broker-flat-screen'),
      backgroundColor: HomiziColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: const HomiziBackButton(),
        title: Text(homiziText(context, 'Flat details')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                homiziText(
                  context,
                  'Post a flat. Location, price, amenities, images, and other details, then match it to seekers.',
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  height: 1.35,
                  color: HomiziColors.inkSoft,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                homiziText(context, 'Location'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: const Key('broker-city'),
                initialValue: exploreCities.contains(_city)
                    ? _city
                    : exploreCities.first,
                decoration: InputDecoration(
                  labelText: homiziText(context, 'City'),
                ),
                items: [
                  for (final city in exploreCities)
                    DropdownMenuItem(value: city, child: Text(city)),
                ],
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => _city = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('broker-locality'),
                controller: _locality,
                decoration: InputDecoration(
                  labelText: homiziText(context, 'Locality'),
                  hintText: homiziText(context, 'Andheri East'),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                homiziText(context, 'Price'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('broker-price'),
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: homiziText(context, 'Monthly rent ₹'),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                homiziText(context, 'Amenities'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in requirementAmenities)
                    FilterChip(
                      label: Text(
                        homiziText(context, requirementAmenityLabel(item)),
                      ),
                      selected: _amenities.contains(item),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _amenities.add(item);
                          } else {
                            _amenities.remove(item);
                          }
                        });
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                homiziText(context, 'Images'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: wizardSamplePhotos.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final photo = wizardSamplePhotos[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        width: 128,
                        height: 96,
                        child: Image.asset(
                          photo.sampleAsset ?? '',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const ColoredBox(color: HomiziColors.mist),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Text(
                homiziText(
                  context,
                  'Sample photos for this demo. The listing wizard accepts your own set.',
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: HomiziColors.muted,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                homiziText(context, 'Other details'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('broker-other'),
                controller: _other,
                maxLines: 4,
                maxLength: 240,
                decoration: InputDecoration(
                  labelText: homiziText(context, 'Configuration, deposit, availability'),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  homiziText(context, _error!),
                  style: const TextStyle(color: HomiziColors.error),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('broker-match'),
                onPressed: _match,
                child: Text(homiziText(context, 'Match this flat')),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: const Key('broker-open-wizard'),
                onPressed: () =>
                    context.push('${RoutePaths.listingEditor}?fresh=1'),
                child: Text(homiziText(context, 'Open the listing wizard')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
