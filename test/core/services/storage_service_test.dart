import 'package:flutter_test/flutter_test.dart';
import 'package:versed/core/services/storage_service.dart';

void main() {
  group('StorageService.avatarPathFromUrl', () {
    test('reads the object path out of one of our public URLs', () {
      expect(
        StorageService.avatarPathFromUrl(
          'https://abc.supabase.co/storage/v1/object/public/avatars/'
          'user-1/1720000000-42.jpg',
        ),
        'user-1/1720000000-42.jpg',
      );
    });

    test('drops a cache-busting query', () {
      expect(
        StorageService.avatarPathFromUrl(
          'https://abc.supabase.co/storage/v1/object/public/avatars/'
          'user-1/photo.jpg?t=123',
        ),
        'user-1/photo.jpg',
      );
    });

    test('ignores an avatar we did not store', () {
      expect(
        StorageService.avatarPathFromUrl(
          'https://lh3.googleusercontent.com/a/photo=s96-c',
        ),
        isNull,
      );
      expect(StorageService.avatarPathFromUrl(null), isNull);
    });

    test('ignores a URL from another bucket', () {
      expect(
        StorageService.avatarPathFromUrl(
          'https://abc.supabase.co/storage/v1/object/public/fits/'
          'user-1/fit.jpg',
        ),
        isNull,
      );
    });
  });
}
