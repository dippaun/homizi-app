import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';
import 'package:homizi/features/discovery/listing_detail_screen.dart';
import 'package:homizi/features/listings/domain/photo_caption.dart';

void main() {
  testWidgets('a listing photo decodes near its layout width', (tester) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 180,
            height: 120,
            child: ListingPhoto(asset: 'assets/photos/living_01.jpg'),
          ),
        ),
      ),
    );
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    final provider = image.image;
    expect(provider, isA<ResizeImage>());
    expect((provider as ResizeImage).width, 360);
  });

  testWidgets('a caption is the image semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: ListingGallery(
              heroTag: 'caption-hero',
              assets: ['assets/photos/living_01.webp'],
              labels: ['Morning light in the living room'],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Morning light in the living room'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(ListingPhoto)).label,
      'Morning light in the living room',
    );
    expect(find.textContaining('9876543210'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });

  testWidgets('an empty caption falls back to the room type', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(handle.dispose);
    const label = 'Living room photo';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            child: ListingGallery(
              heroTag: 'room-hero',
              assets: const ['assets/photos/living_01.webp'],
              labels: [
                photoSemanticsLabel(caption: '', roomLabel: 'Living room'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(label), findsOneWidget);
    expect(tester.getSemantics(find.byType(ListingPhoto)).label, label);
  });

  testWidgets('listing detail speaks the room when no caption is stored', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ListingDetailScreen(listingId: 'lst_koramangala'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Living room photo'), findsWidgets);
    expect(find.textContaining('+91'), findsNothing);
    expect(find.textContaining('@'), findsNothing);
  });
}
