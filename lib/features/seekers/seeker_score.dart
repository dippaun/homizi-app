import 'package:homizi/features/discovery/domain/listing.dart';
import 'package:homizi/features/matching/domain/intelligent_match.dart';
import 'package:homizi/features/matching/match_api.dart';
import 'package:homizi/features/seekers/domain/host_property.dart';
import 'package:homizi/features/seekers/domain/seeker_profile.dart';

/// `{percent, topReasons, missing}` for one seeker against one property.
///
/// The numbers come from [scoreSeeker]. A must-have miss is a hard filter:
/// [seekerBlockedByHardFilter] is true and the board leaves that person off.
class SeekerFit {
  const SeekerFit({
    required this.percent,
    required this.topReasons,
    required this.missing,
  });

  final int percent;
  final List<String> topReasons;
  final List<String> missing;
}

/// Null when [host] is still the default, so [scoreSeeker] can read
/// furnishing, pets, and gender off the listing. A reordered or must-have
/// list is the host's saved priorities.
HostPriorities? savedHostPriorities(HostPriorities host) {
  const base = HostPriorities();
  if (host.mustHave.isNotEmpty ||
      host.gender != base.gender ||
      host.furnishing != base.furnishing ||
      host.petsAllowed != base.petsAllowed ||
      !_sameOrder(host.order, base.order)) {
    return host;
  }
  return null;
}

bool _sameOrder(List<HostFactorId> left, List<HostFactorId> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var i = 0; i < left.length; i++) {
    if (left[i] != right[i]) {
      return false;
    }
  }
  return true;
}

SeekerFit scoreSeekerForProperty({
  required HostProperty property,
  required SeekerPublicProfile seeker,
  HostPriorities? priorities,
  LearnedSignals signals = LearnedSignals.empty,
}) {
  final result = scoreSeeker(
    listingFromHostProperty(property),
    leadFromSeeker(seeker),
    priorities: priorities,
    signals: signals,
  );
  return SeekerFit(
    percent: result.percent,
    topReasons: result.topReasons,
    missing: result.missing,
  );
}

/// A must-have factor that [scoreSeeker] reported as missing.
bool seekerBlockedByHardFilter(HostPriorities? priorities, SeekerFit fit) {
  if (priorities == null || priorities.mustHave.isEmpty) {
    return false;
  }
  for (final id in priorities.mustHave) {
    final line = _hardMiss[id];
    if (line != null && fit.missing.contains(line)) {
      return true;
    }
  }
  return false;
}

/// Miss lines from [scoreHostLead]. Kept here so a must-have can be applied
/// without a second score.
const _hardMiss = <HostFactorId, String>{
  HostFactorId.workingProfessional: 'Not a working professional',
  HostFactorId.nonDrinker: 'Drinks',
  HostFactorId.nonSmoker: 'Smokes',
  HostFactorId.clean: 'Cleanliness does not match',
  HostFactorId.gender: 'Gender preference does not match',
  HostFactorId.longStay: 'Short stay',
  HostFactorId.furnishing: 'Different furnishing type',
  HostFactorId.pets: 'Has pets',
};

bool budgetCoversRent(HostProperty property, SeekerPublicProfile seeker) {
  final low = seeker.budgetMinInr <= seeker.budgetMaxInr
      ? seeker.budgetMinInr
      : seeker.budgetMaxInr;
  final high = seeker.budgetMinInr <= seeker.budgetMaxInr
      ? seeker.budgetMaxInr
      : seeker.budgetMinInr;
  return property.rentInr >= low && property.rentInr <= high;
}

Listing listingFromHostProperty(HostProperty property) {
  return Listing(
    id: property.id,
    hostUserId: 'host',
    title: property.label,
    city: property.city,
    locality: property.locality,
    rentInr: property.rentInr,
    depositInr: 0,
    furnishing: property.furnishing,
    propertyType: property.propertyType,
    hostDisplayName: 'Host',
    amenities: property.amenities,
    summary: '',
    petsAllowed: property.petsAllowed,
    nonVegAllowed: property.nonVegAllowed,
    restrictions: [if (property.noSmoking) 'no_smoking'],
    photoAssets: [property.photoAsset],
  );
}

TenantLead leadFromSeeker(SeekerPublicProfile profile) {
  final habits = [for (final item in profile.lifestyle) item.toLowerCase()];
  final drinks = habits.any(
    (item) => item.contains('drinker') && !item.startsWith('non'),
  );
  final nonSmoker = !profile.smokes;
  final clean = habits.any((item) => item.contains('clean'));
  final stay = profile.stayLabel.toLowerCase();
  final longStay =
      stay.isEmpty ||
      stay.contains('11') ||
      stay.contains('12') ||
      stay.contains('extend') ||
      stay.contains('year');
  final gender = _scoringGender(profile.id);
  return TenantLead(
    id: profile.id,
    name: profile.name,
    city: profile.city,
    locality: profile.localities.isEmpty
        ? profile.city
        : profile.localities.first,
    budgetMinInr: profile.budgetMinInr,
    budgetMaxInr: profile.budgetMaxInr,
    workingProfessional: profile.profession != 'student',
    nonDrinker: profile.lifestyleKnown ? !drinks : true,
    nonSmoker: nonSmoker,
    cleanliness: clean ? 5 : 3,
    gender: gender,
    longStay: longStay,
    furnishing: profile.furnishing.trim().isEmpty ? 'any' : profile.furnishing,
    hasPets: profile.hasPets,
    verified: profile.verified,
    likesYou: false,
    about: profile.about,
    roomie: RoomieProfile(
      budgetMinInr: profile.budgetMinInr,
      budgetMaxInr: profile.budgetMaxInr,
      city: profile.city,
      localities: profile.localities,
      smoking: nonSmoker ? 'no' : 'yes',
      drinking: drinks ? 'yes' : 'no',
      food: profile.wantsNonVeg ? 'non_veg' : 'veg',
      cleanliness: clean ? 5 : 3,
      sleep: 'flexible',
      guests: 'occasionally',
      cooking: 'sometimes',
    ),
  );
}

const _women = <String>{
  'ananya',
  'priya',
  'sana',
  'meera',
  'ishita',
  'fatima',
  'lavanya',
  'diya',
  'neelam',
  'aditi-mehta',
  'priya-desai',
};

const _men = <String>{
  'rohan',
  'rohan-verma',
  'kabir',
  'dev',
  'arjun',
  'vikram',
  'nikhil',
  'harsh',
  'aditya',
  'karan-shah',
  'neel-joshi',
};

/// Used only by the host scorer. The seeker screen does not print it.
String _scoringGender(String id) {
  if (_women.contains(id)) {
    return 'woman';
  }
  if (_men.contains(id)) {
    return 'man';
  }
  return '';
}
