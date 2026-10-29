import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tenant requirements and the broker flat, kept on this device in demo mode.
class FlowPrefs {
  const FlowPrefs({
    this.stay = 'full',
    this.city = 'Bengaluru',
    this.localities = const ['Koramangala', 'Indiranagar'],
    this.budgetMin = 18000,
    this.budgetMax = 32000,
    this.amenities = const ['wifi', 'washing_machine'],
    this.furnishing = 'semi_furnished',
    this.note = 'Quiet working professional. No smoking.',
    this.brokerCity = 'Mumbai',
    this.brokerLocality = 'Andheri East',
    this.brokerPrice = 42000,
    this.brokerAmenities = const ['wifi', 'ac', 'security'],
    this.brokerOther =
        '2 BHK, semi-furnished. Deposit ₹1,00,000. Available 1 Dec 2026. Gated society near the Metro.',
  });

  /// `full`, `shared`, or `roommate`.
  final String stay;
  final String city;
  final List<String> localities;
  final int budgetMin;
  final int budgetMax;
  final List<String> amenities;
  final String furnishing;
  final String note;
  final String brokerCity;
  final String brokerLocality;
  final int brokerPrice;
  final List<String> brokerAmenities;
  final String brokerOther;

  int get budgetLow => budgetMin <= budgetMax ? budgetMin : budgetMax;

  int get budgetHigh => budgetMin <= budgetMax ? budgetMax : budgetMin;

  FlowPrefs copyWith({
    String? stay,
    String? city,
    List<String>? localities,
    int? budgetMin,
    int? budgetMax,
    List<String>? amenities,
    String? furnishing,
    String? note,
    String? brokerCity,
    String? brokerLocality,
    int? brokerPrice,
    List<String>? brokerAmenities,
    String? brokerOther,
  }) {
    return FlowPrefs(
      stay: stay ?? this.stay,
      city: city ?? this.city,
      localities: localities ?? this.localities,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
      amenities: amenities ?? this.amenities,
      furnishing: furnishing ?? this.furnishing,
      note: note ?? this.note,
      brokerCity: brokerCity ?? this.brokerCity,
      brokerLocality: brokerLocality ?? this.brokerLocality,
      brokerPrice: brokerPrice ?? this.brokerPrice,
      brokerAmenities: brokerAmenities ?? this.brokerAmenities,
      brokerOther: brokerOther ?? this.brokerOther,
    );
  }
}

class FlowPrefsController extends Notifier<FlowPrefs> {
  @override
  FlowPrefs build() => const FlowPrefs();

  void update(FlowPrefs next) => state = next;
}

final flowPrefsProvider = NotifierProvider<FlowPrefsController, FlowPrefs>(
  FlowPrefsController.new,
);

String stayLabel(String stay) => switch (stay) {
  'shared' => 'Shared room',
  'roommate' => 'Roommate',
  _ => 'Full room',
};
