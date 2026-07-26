import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:versed/features/upload/models/upload_state.dart';
import 'package:versed/features/upload/services/image_crop_service.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PickedFit.centeredCrop', () {
    test('takes the full width of a photo taller than 4:5', () {
      final crop = _photo(width: 400, height: 800).centeredCrop;

      expect(crop, const Rect.fromLTWH(0, 150, 400, 500));
    });

    test('takes the full height of a photo wider than 4:5', () {
      final crop = _photo(width: 1000, height: 500).centeredCrop;

      expect(crop, const Rect.fromLTWH(300, 0, 400, 500));
    });

    test('leaves a photo already at 4:5 whole', () {
      final crop = _photo(width: 400, height: 500).centeredCrop;

      expect(crop, const Rect.fromLTWH(0, 0, 400, 500));
    });
  });

  group('ImageCropService', () {
    const service = ImageCropService();

    test('cuts the photo down to the framed region', () async {
      final source = _photo(width: 600, height: 900);

      final cropped = await service.crop(
        source: source,
        crop: const Rect.fromLTWH(100, 200, 400, 500),
      );

      expect(cropped.width, 400);
      expect(cropped.height, 500);
      expect(cropped.fileExtension, 'jpg');
      expect(img.decodeJpg(cropped.bytes)?.width, 400);
    });

    test('pulls a frame hanging off the edge back inside the photo', () async {
      final source = _photo(width: 400, height: 500);

      final cropped = await service.crop(
        source: source,
        // A 4:5 frame nudged past the bottom-right corner.
        crop: const Rect.fromLTWH(80, 100, 400, 500),
      );

      expect(cropped.width, 400);
      expect(cropped.height, 500);
    });

    test(
      'leaves the bytes alone when the crop covers the whole photo',
      () async {
        final source = _photo(width: 400, height: 500);

        final cropped = await service.crop(
          source: source,
          crop: const Rect.fromLTWH(0, 0, 400, 500),
        );

        expect(identical(cropped.bytes, source.bytes), isTrue);
      },
    );
  });
}
