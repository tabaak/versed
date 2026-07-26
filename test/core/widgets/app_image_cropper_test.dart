import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:versed/core/widgets/app_image_cropper.dart';

final _photoBytes = () {
  final source = img.Image(width: 200, height: 400);
  img.fill(source, color: img.ColorRgb8(120, 120, 120));
  return img.encodeJpg(source);
}();

void main() {
  testWidgets('frames the photo instead of scrolling the page it sits in', (
    tester,
  ) async {
    final crops = <Rect>[];
    final scrollController = ScrollController();
    addTearDown(scrollController.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: ListView(
          controller: scrollController,
          children: [
            SizedBox(
              width: 240,
              height: 240,
              child: AppImageCropper(
                bytes: _photoBytes,
                imageWidth: 200,
                imageHeight: 400,
                aspectRatio: 1,
                circular: true,
                onCropChanged: crops.add,
              ),
            ),
            // Enough below the frame to leave the list scrollable.
            const SizedBox(height: 1200),
          ],
        ),
      ),
    );
    await tester.pump();

    final centered = crops.last.top;
    await tester.drag(find.byType(AppImageCropper), const Offset(0, 40));
    await tester.pump();

    // The drag belongs to the frame: the photo moves and the page stays put.
    expect(crops.last.top, lessThan(centered));
    expect(scrollController.offset, 0);
  });
}
