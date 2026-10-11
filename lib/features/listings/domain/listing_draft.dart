class PhotoSlot {
  const PhotoSlot({required this.label, required this.isPrimary});

  final String label;
  final bool isPrimary;

  PhotoSlot copyWith({String? label, bool? isPrimary}) {
    return PhotoSlot(
      label: label ?? this.label,
      isPrimary: isPrimary ?? this.isPrimary,
    );
  }
}

class ListingDraft {
  const ListingDraft({
    this.id,
    this.title = '',
    this.city = '',
    this.locality = '',
    this.rentText = '',
    this.depositText = '',
    this.furnishing = 'semi_furnished',
    this.propertyType = 'apartment',
    this.photos = const [],
  });

  /// Client-generated id so a later save updates the same row.
  final String? id;
  final String title;
  final String city;
  final String locality;
  final String rentText;
  final String depositText;
  final String furnishing;
  final String propertyType;
  final List<PhotoSlot> photos;

  int? get rentInr => int.tryParse(rentText.trim());

  /// Fields the database will accept on a draft row. Rent may be zero here.
  List<String> persistBlockers() {
    final blockers = <String>[];
    final trimmedTitle = title.trim();
    if (trimmedTitle.length < 3) {
      blockers.add('Add a title of at least 3 characters.');
    }
    if (trimmedTitle.length > 120) {
      blockers.add('Keep the title to 120 characters or fewer.');
    }
    if (city.trim().isEmpty) {
      blockers.add('Choose a city.');
    }
    if (locality.trim().isEmpty) {
      blockers.add('Add a locality.');
    }
    final rent = rentInr;
    if (rent == null || rent < 0) {
      blockers.add('Enter a monthly rent in rupees.');
    }
    final depositText = this.depositText.trim();
    if (depositText.isNotEmpty) {
      final deposit = int.tryParse(depositText);
      if (deposit == null || deposit < 0) {
        blockers.add('Enter a deposit in rupees, or leave it blank.');
      }
    }
    return blockers;
  }

  List<String> publishBlockers() {
    final blockers = [...persistBlockers()];
    final rent = rentInr;
    if ((rent == null || rent <= 0) &&
        !blockers.contains('Enter a monthly rent in rupees.')) {
      blockers.add('Enter a monthly rent in rupees.');
    }
    if (photos.length < 3) {
      blockers.add('Add at least 3 photos.');
    }
    if (photos.isNotEmpty && !photos.any((photo) => photo.isPrimary)) {
      blockers.add('Mark a primary photo.');
    }
    return blockers;
  }

  ListingDraft copyWith({
    String? id,
    String? title,
    String? city,
    String? locality,
    String? rentText,
    String? depositText,
    String? furnishing,
    String? propertyType,
    List<PhotoSlot>? photos,
  }) {
    return ListingDraft(
      id: id ?? this.id,
      title: title ?? this.title,
      city: city ?? this.city,
      locality: locality ?? this.locality,
      rentText: rentText ?? this.rentText,
      depositText: depositText ?? this.depositText,
      furnishing: furnishing ?? this.furnishing,
      propertyType: propertyType ?? this.propertyType,
      photos: photos ?? this.photos,
    );
  }
}
