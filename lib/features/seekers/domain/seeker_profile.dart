import 'package:homizi/features/requirements/domain/requirement_draft.dart';
import 'package:homizi/features/roles/seeker_match.dart';

/// Public seeker brief. Phone, email, and verification documents are absent.
class SeekerPublicProfile {
  const SeekerPublicProfile({
    required this.id,
    required this.name,
    required this.city,
    required this.localities,
    required this.budgetMinInr,
    required this.budgetMaxInr,
    required this.roomType,
    required this.furnishing,
    required this.amenities,
    required this.seekerKind,
    required this.about,
    required this.profession,
    this.age,
    this.occupation = '',
    this.verified = false,
    this.photoAsset = '',
    this.education = '',
    this.hometown = '',
    this.languages = const [],
    this.lookingWith = '',
    this.stayLabel = '',
    this.propertyLabel = '',
    this.moveIn,
    this.moveInLabel = '',
    this.lifestyle = const [],
    this.houseRules = const [],
    this.lifestyleKnown = false,
    this.smokes = false,
    this.hasPets = false,
    this.wantsNonVeg = false,
    this.perPerson = false,
    this.userId = '',
  });

  final String id;
  final String name;
  final String city;
  final List<String> localities;
  final int budgetMinInr;
  final int budgetMaxInr;
  final String roomType;
  final String furnishing;
  final List<String> amenities;
  final String seekerKind;
  final String about;
  final String profession;
  final int? age;
  final String occupation;
  final bool verified;
  final String photoAsset;
  final String education;
  final String hometown;
  final List<String> languages;
  final String lookingWith;
  final String stayLabel;
  final String propertyLabel;
  final DateTime? moveIn;
  final String moveInLabel;
  final List<String> lifestyle;
  final List<String> houseRules;
  final bool lifestyleKnown;
  final bool smokes;
  final bool hasPets;
  final bool wantsNonVeg;
  final bool perPerson;
  final String userId;

  String get occupationLabel {
    if (occupation.trim().isNotEmpty) {
      return occupation.trim();
    }
    return requirementProfessionLabel(profession);
  }

  String get kindLabel =>
      seekerKind == 'roommate' ? 'Roommate' : 'Tenant / Seeker';

  String get propertyLine {
    if (propertyLabel.trim().isNotEmpty) {
      return propertyLabel.trim();
    }
    return requirementRoomTypeLabel(roomType);
  }
}

SeekerPublicProfile profileFromMatch(SeekerMatch match) {
  final extra = demoSeekerProfiles[match.requirementId];
  if (extra != null) {
    return extra;
  }
  return SeekerPublicProfile(
    id: match.requirementId,
    name: match.displayName,
    city: match.city,
    localities: match.localities,
    budgetMinInr: match.budgetMinInr,
    budgetMaxInr: match.budgetMaxInr,
    roomType: match.roomType.split(',').first.trim(),
    furnishing: '',
    amenities: const [],
    seekerKind: match.seekerKind,
    about: match.aboutMe,
    profession: match.profession.split(',').first.trim(),
    photoAsset: _photoFor(match.requirementId),
  );
}

String _photoFor(String id) {
  const women = {
    'ananya',
    'priya',
    'sana',
    'meera',
    'ishita',
    'fatima',
    'lavanya',
    'diya',
    'neelam',
  };
  const men = {
    'rohan',
    'kabir',
    'dev',
    'arjun',
    'vikram',
    'nikhil',
    'harsh',
    'aditya',
  };
  if (women.contains(id)) {
    return switch (id) {
      'ananya' || 'lavanya' => 'assets/avatars/avatar_05.webp',
      'priya' || 'meera' || 'fatima' => 'assets/avatars/avatar_01.webp',
      _ => 'assets/avatars/avatar_03.webp',
    };
  }
  if (men.contains(id)) {
    return id == 'dev' || id == 'arjun' || id == 'nikhil'
        ? 'assets/avatars/avatar_04.webp'
        : 'assets/avatars/avatar_02.webp';
  }
  return '';
}

/// Extra public facts for demo briefs. No document numbers.
const demoSeekerProfiles = <String, SeekerPublicProfile>{
  'ananya': SeekerPublicProfile(
    id: 'ananya',
    name: 'Ananya Iyer',
    city: 'Bengaluru',
    localities: ['Koramangala', 'Indiranagar'],
    budgetMinInr: 20000,
    budgetMaxInr: 35000,
    roomType: '2bhk',
    furnishing: 'semi_furnished',
    amenities: ['wifi', 'ac', 'washing_machine'],
    seekerKind: 'tenant',
    about:
        'Architect in Indiranagar. I want a bright 2 BHK on an 11 month lease.',
    profession: 'working',
    age: 27,
    occupation: 'Architect',
    verified: true,
    photoAsset: 'assets/avatars/avatar_05.webp',
    education: 'B.Arch',
    hometown: 'Chennai, Tamil Nadu',
    languages: ['English', 'Tamil', 'Hindi'],
    lookingWith: 'Solo',
    stayLabel: '11 months',
    propertyLabel: '2 BHK',
    moveInLabel: '20 Nov 2026',
    lifestyle: ['Non-Smoker', 'Work from Home'],
    houseRules: ['Cooking Allowed', 'No Loud Parties'],
    lifestyleKnown: true,
  ),
  'rohan-verma': SeekerPublicProfile(
    id: 'rohan-verma',
    name: 'Rohan Verma',
    city: 'Ahmedabad',
    localities: ['Bodakdev', 'Thaltej', 'Vastrapur'],
    budgetMinInr: 8000,
    budgetMaxInr: 12000,
    roomType: '2bhk',
    furnishing: 'furnished',
    amenities: [],
    seekerKind: 'tenant',
    about:
        'IT professional looking for a comfortable and peaceful home. I am clean, respectful and value a friendly environment. Prefer like-minded roommates or a well-managed shared flat.',
    profession: 'working',
    age: 24,
    occupation: 'Software Engineer (IT)',
    verified: true,
    photoAsset: 'assets/avatars/avatar_02.webp',
    education: 'B.Tech (Computer Science)',
    hometown: 'Vadodara, Gujarat',
    languages: ['English', 'Hindi', 'Gujarati'],
    lookingWith: 'Solo (open to compatible roommate)',
    stayLabel: '6 – 12 months (extendable)',
    propertyLabel: '2 BHK / 3 BHK (Shared with 1-2 roommates)',
    moveInLabel: 'Within 15 days',
    lifestyle: [
      'Non-Smoker',
      'Clean & Organized',
      'Occasional Drinker',
      'Work from Home',
      'Veg',
      'Pet Friendly',
    ],
    houseRules: [
      'Guests Allowed (Occasional)',
      'Cooking Allowed',
      'Flexible Timings',
      'No Loud Parties',
    ],
    lifestyleKnown: true,
    perPerson: true,
  ),
  'aditi-mehta': SeekerPublicProfile(
    id: 'aditi-mehta',
    name: 'Aditi Mehta',
    city: 'Ahmedabad',
    localities: ['Vastrapur', 'Thaltej'],
    budgetMinInr: 15000,
    budgetMaxInr: 26000,
    roomType: '2bhk',
    furnishing: 'furnished',
    amenities: [],
    seekerKind: 'tenant',
    about:
        'Product designer at a studio in Thaltej. I keep a quiet flat and cook most evenings.',
    profession: 'working',
    age: 26,
    occupation: 'Product Designer',
    verified: true,
    photoAsset: 'assets/avatars/avatar_01.webp',
    education: 'B.Des',
    hometown: 'Ahmedabad, Gujarat',
    languages: ['English', 'Gujarati', 'Hindi'],
    lookingWith: 'Solo',
    stayLabel: '11 months',
    propertyLabel: '2 BHK',
    moveInLabel: 'Within 30 days',
    lifestyle: ['Non-Smoker', 'Clean & Organized', 'Veg'],
    houseRules: ['Cooking Allowed', 'No Loud Parties'],
    lifestyleKnown: true,
    perPerson: true,
  ),
  'karan-shah': SeekerPublicProfile(
    id: 'karan-shah',
    name: 'Karan Shah',
    city: 'Ahmedabad',
    localities: ['Navrangpura'],
    budgetMinInr: 18000,
    budgetMaxInr: 20000,
    roomType: '2bhk',
    furnishing: 'unfurnished',
    amenities: [],
    seekerKind: 'tenant',
    about:
        'Data analyst. I am in the office most days and want a simple 2 BHK near Navrangpura.',
    profession: 'working',
    age: 27,
    occupation: 'Data Analyst',
    verified: true,
    photoAsset: 'assets/avatars/avatar_04.webp',
    education: 'M.Sc. Statistics',
    hometown: 'Rajkot, Gujarat',
    languages: ['Gujarati', 'Hindi', 'English'],
    lookingWith: 'With a friend',
    stayLabel: '12 months',
    propertyLabel: '2 BHK',
    moveInLabel: 'Next month',
    lifestyle: ['Non-Smoker', 'Work from Home'],
    houseRules: ['Flexible Timings', 'Cooking Allowed'],
    lifestyleKnown: true,
  ),
  'priya-desai': SeekerPublicProfile(
    id: 'priya-desai',
    name: 'Priya Desai',
    city: 'Ahmedabad',
    localities: ['Vastrapur', 'Satellite'],
    budgetMinInr: 18000,
    budgetMaxInr: 28000,
    roomType: '2bhk',
    furnishing: 'unfurnished',
    amenities: [],
    seekerKind: 'tenant',
    about:
        'Marketing professional. I want a bright home and a kitchen I can use on weeknights.',
    profession: 'working',
    age: 24,
    occupation: 'Marketing Professional',
    verified: true,
    photoAsset: 'assets/avatars/avatar_03.webp',
    education: 'BBA',
    hometown: 'Surat, Gujarat',
    languages: ['Gujarati', 'English', 'Hindi'],
    lookingWith: 'Solo',
    stayLabel: '11 months',
    propertyLabel: '2 BHK',
    moveInLabel: 'Within 30 days',
    lifestyle: ['Non-Smoker', 'Clean & Organized', 'Veg'],
    houseRules: ['No Loud Parties', 'Cooking Allowed'],
    lifestyleKnown: true,
  ),
  'neel-joshi': SeekerPublicProfile(
    id: 'neel-joshi',
    name: 'Neel Joshi',
    city: 'Ahmedabad',
    localities: ['Bodakdev'],
    budgetMinInr: 8000,
    budgetMaxInr: 12000,
    roomType: '2bhk',
    furnishing: 'furnished',
    amenities: [],
    seekerKind: 'tenant',
    about:
        'Engineer on a project in Bodakdev. I am out on weekends and keep common areas clear.',
    profession: 'working',
    age: 25,
    occupation: 'Engineer',
    verified: true,
    photoAsset: 'assets/avatars/avatar_04.webp',
    education: 'B.E. Mechanical',
    hometown: 'Anand, Gujarat',
    languages: ['Gujarati', 'Hindi'],
    lookingWith: 'Solo (open to compatible roommate)',
    stayLabel: '6 months',
    propertyLabel: '2 BHK',
    moveInLabel: 'Within 15 days',
    lifestyle: ['Non-Smoker', 'Occasional Drinker'],
    houseRules: ['Guests Allowed (Occasional)', 'Flexible Timings'],
    lifestyleKnown: true,
    perPerson: true,
  ),
  'dev': SeekerPublicProfile(
    id: 'dev',
    name: 'Dev Patel',
    city: 'Ahmedabad',
    localities: ['Satellite', 'Vastrapur'],
    budgetMinInr: 8000,
    budgetMaxInr: 14000,
    roomType: '1rk',
    furnishing: 'furnished',
    amenities: ['wifi'],
    seekerKind: 'tenant',
    about: 'First year of a master’s course near Vastrapur.',
    profession: 'student',
    age: 22,
    occupation: 'Master’s student',
    photoAsset: 'assets/avatars/avatar_04.webp',
    education: 'M.Sc. (first year)',
    hometown: 'Ahmedabad, Gujarat',
    languages: ['Gujarati', 'English'],
    lookingWith: 'Solo',
    stayLabel: '11 months',
    propertyLabel: '1 RK',
    moveInLabel: 'This month',
    lifestyle: ['Non-Smoker', 'Veg'],
    houseRules: ['No Loud Parties'],
    lifestyleKnown: true,
  ),
};
