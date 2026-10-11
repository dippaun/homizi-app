import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:homizi/core/widgets/state_views.dart';
import 'package:homizi/features/discovery/domain/listing_filters.dart';

final viewPreviewProvider =
    NotifierProvider.family<ViewPreviewController, ViewStatus, String>(
      ViewPreviewController.new,
    );

class ViewPreviewController extends Notifier<ViewStatus> {
  ViewPreviewController(this.scope);

  final String scope;

  @override
  ViewStatus build() {
    if (scope.isEmpty) {
      throw ArgumentError.value(scope, 'scope', 'Preview scope is required.');
    }
    return ViewStatus.ready;
  }

  void setStatus(ViewStatus status) => state = status;
}

final listingFilterProvider =
    NotifierProvider<ListingFilterController, ListingFilters>(
      ListingFilterController.new,
    );

class ListingFilterController extends Notifier<ListingFilters> {
  @override
  ListingFilters build() => const ListingFilters();

  void replace(ListingFilters filters) => state = filters;

  void reset() => state = const ListingFilters();
}
