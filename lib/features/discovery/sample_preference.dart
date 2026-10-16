import 'package:homizi/features/discovery/domain/compatibility.dart';

/// Sample preference used only to explain a score on screen.
/// It is not a saved requirement and it does not read the signed-in profile.
const sampleCompatibilityPreference = CompatibilityPreference(
  budgetMinInr: 15000,
  budgetMaxInr: 25000,
  city: 'Bengaluru',
  locality: 'Koramangala',
  furnishing: 'furnished',
  propertyType: 'apartment',
);
