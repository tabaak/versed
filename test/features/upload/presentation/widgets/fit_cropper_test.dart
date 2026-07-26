import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:versed/features/upload/models/upload_state.dart';
import 'package:versed/features/upload/presentation/widgets/fit_cropper.dart';

PickedFit _photo({required int width, required int height}) {
  final source = img.Image(width: width, height: height);
  img.fill(source, color: img.ColorRgb8(120, 120, 120));
  return PickedFit(
    bytes: img.encodeJpg(source),
    fileExtension: 'jpg',
    width: width,
    height: height,
  );
}

/// Crops are reported in source pixels, so they survive the exact on-screen
/// size of the frame — but not floating point, hence the tolerance.
void expectCrop(Rect actual, Rect expected) {
  expect(actual.left, moreOrLessEquals(expected.left));
  expect(actual.top, moreOrLessEquals(expected.top));
  expect(actual.width, moreOrLessEquals(expected.width));
  expect(actual.height, moreOrLessEquals(expected.height));
}

void main() {
  Future<List<Rect>> pumpCropper(WidgetTester tester, PickedFit picked) async {
    final crops = <Rect>[];

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 400,
            height: 500,
            child: FitCropper(picked: picked, onCropChanged: crops.add),
          ),
        ),
      ),
    );
    await tester.pump();

    return crops;
  }

  testWidgets('reports the centered crop before anything is dragged', (
    tester,
  ) async {
    final crops = await pumpCropper(tester, _photo(width: 400, height: 800));

    expectCrop(crops.last, const Rect.fromLTWH(0, 150, 400, 500));
  });

  testWidgets('moves the crop with a drag', (tester) async {
    final crops = await pumpCropper(tester, _photo(width: 400, height: 800));

    // Dragging the photo down reveals what was above the frame.
    await tester.drag(find.byType(FitCropper), const Offset(0, 40));
    await tester.pump();

    expect(crops.last.top, lessThan(150));
    expect(crops.last.top, greaterThan(0));
    expect(crops.last.width, moreOrLessEquals(crops.first.width));
    expect(crops.last.height, moreOrLessEquals(crops.first.height));
  });

  testWidgets('stops the crop at the edge of the photo', (tester) async {
    final crops = await pumpCropper(tester, _photo(width: 400, height: 800));

    await tester.drag(find.byType(FitCropper), const Offset(0, 400));
    await tester.pump();

    expectCrop(crops.last, const Rect.fromLTWH(0, 0, 400, 500));
  });

  testWidgets('re-centers on a new photo', (tester) async {
    final crops = await pumpCropper(tester, _photo(width: 400, height: 800));

    await tester.drag(find.byType(FitCropper), const Offset(0, 40));
    await tester.pump();
    expect(crops.last.top, lessThan(150));

    final afterSwap = await pumpCropper(
      tester,
      _photo(width: 400, height: 900),
    );

    expectCrop(afterSwap.last, const Rect.fromLTWH(0, 200, 400, 500));
  });
}
