import 'package:homizi/features/search_properties/search_draft.dart';

/// The five tabs of Search Properties, in order.
const searchStepTitles = <String>[
  'Property Requirements',
  'Location & Connectivity',
  'Lifestyle Preferences',
  'Amenities & Rules',
  'Confirm & Search',
];

/// The last tab. It has no questions and holds "Find My Best Matches".
const searchConfirmStep = 4;

/// Questions a person must answer on purpose. The draft starts on safe
/// defaults ("Anything suitable…"), so each one counts only once picked,
/// or once a saved search is restored.
abstract final class SearchQuestion {
  static const occupancy = 'occupancy';
  static const propertyKind = 'propertyKind';
  static const possession = 'possession';
  static const gender = 'gender';
  static const furnishing = 'furnishing';
  static const bathroom = 'bathroom';
  static const suitableFor = 'suitableFor';

  static const all = <String>{
    occupancy,
    propertyKind,
    possession,
    gender,
    furnishing,
    bathroom,
    suitableFor,
  };
}

/// What is still missing on [step], in the order the cards appear.
/// Empty means the step is complete.
List<String> searchStepMissing(
  int step, {
  required PropertySearch draft,
  required Set<String> answered,
  required bool hasSavedOffice,
}) {
  final missing = <String>[];
  void need(String key, String label) {
    if (!answered.contains(key)) {
      missing.add(label);
    }
  }

  switch (step) {
    case 0:
      need(SearchQuestion.occupancy, 'Choose the occupancy you need.');
      need(SearchQuestion.propertyKind, 'Choose a property type.');
      if (draft.budgetMaxInr <= draft.budgetMinInr) {
        missing.add('Set a budget range with a higher maximum.');
      }
    case 1:
      final typed = draft.placeQuery.trim().length >= 2;
      final office = draft.useOffice && hasSavedOffice;
      if (!typed && !office) {
        missing.add('Enter your office, company or preferred area.');
      }
      need(SearchQuestion.possession, 'Choose when you need the home.');
      if (draft.possession == PossessionChoice.specificDate &&
          draft.possessionDate == null) {
        missing.add('Choose the possession date.');
      }
    case 2:
      need(SearchQuestion.gender, 'Choose a flatmate gender preference.');
    case 3:
      need(SearchQuestion.furnishing, 'Choose a furnishing preference.');
      need(SearchQuestion.bathroom, 'Choose a bathroom preference.');
      need(SearchQuestion.suitableFor, 'Choose who the home is for.');
  }
  return missing;
}

/// The furthest tab a person may open: every tab before it is complete.
int searchUnlockedStep({
  required PropertySearch draft,
  required Set<String> answered,
  required bool hasSavedOffice,
}) {
  for (var step = 0; step < searchConfirmStep; step++) {
    final missing = searchStepMissing(
      step,
      draft: draft,
      answered: answered,
      hasSavedOffice: hasSavedOffice,
    );
    if (missing.isNotEmpty) {
      return step;
    }
  }
  return searchConfirmStep;
}
