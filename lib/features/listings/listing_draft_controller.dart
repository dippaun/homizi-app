import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/features/listings/domain/listing_draft.dart';

final listingDraftProvider =
    NotifierProvider<ListingDraftController, ListingDraft>(
      ListingDraftController.new,
    );

class ListingDraftController extends Notifier<ListingDraft> {
  @override
  ListingDraft build() => const ListingDraft();

  void update(ListingDraft draft) => state = draft;

  void setPhotos(List<PhotoSlot> photos) {
    state = state.copyWith(photos: photos);
  }
}
