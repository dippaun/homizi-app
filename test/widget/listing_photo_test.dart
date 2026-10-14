import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:homizi/core/widgets/listing_widgets.dart';

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
}
